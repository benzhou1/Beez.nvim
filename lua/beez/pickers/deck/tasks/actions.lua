local M = { toggles = { show_done = false } }

---@class beez.pickers.deck.tasks.actions.opts

M.open_note_name = "tasks.open_note"
--- Open note in flotes window
---@param opts? table
---@return deck.Action[]
function M.open_note(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("default", M.open_note_name),
    {
      name = M.open_note_name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local zk = require("beez.zk")
        ctx:hide()
        zk.edit(item.data.filename, { item.data.lnum, item.data.col })
      end,
    },
  }
end

M.toggle_done_name = "tasks.toggle_done_task"
--- Deck action to toggle showing done tasks or not
---@param opts? beez.pickers.deck.tasks.actions.opts
---@return deck.Action[]
function M.toggle_done(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("toggle1", M.toggle_done_name),
    {
      name = M.toggle_done_name,
      execute = function(ctx)
        M.toggles.done_task = not M.toggles.done_task
        if M.toggles.done_task then
          vim.notify("Showing done tasks...", vim.log.levels.INFO)
        else
          vim.notify("Showing only open tasks...", vim.log.levels.INFO)
        end
        ctx.execute()
      end,
    },
  }
end

--- Deck action to edit tasks in a scratch buffer
---@param opts table
---@return deck.Action
local function edit_tasks(opts)
  local u = require("beez.u")
  return {
    name = opts.name,
    ---@param ctx deck.Context
    execute = function(ctx)
      u.deck.edit_list(ctx, {
        action = opts.action,
        filetype = "markdown",
        filename = "deck_scratch.md",
        get_pos = opts.get_pos,
        get_feedkey = opts.get_feedkey,
        col_pos_offset = function(pos, action)
          -- Because checkmate converts state into ascii which adds 2 to the column position
          return 2
        end,
        get_lines = function(items)
          local lines = {}
          for _, item in ipairs(items) do
            local line = item.data.task.line .. " [id::" .. item.data.i .. "]"
            table.insert(lines, line)
          end
          return lines
        end,
        save = function(items, lines)
          local bufs = {}
          local cmp = require("plugins.checkmate")
          local f = require("beez.flotes")
          local function load_buf(filename)
            local buf = bufs[filename]
            local loaded = true
            if buf == nil then
              -- Load the buffer by filename
              local bufnr = vim.fn.bufnr(filename)
              -- Has not been loaded yet
              if bufnr == -1 then
                loaded = false
                bufnr = vim.fn.bufadd(filename)
                pcall(vim.fn.bufload, bufnr)
              end
              bufs[filename] = {
                bufnr = bufnr,
                loaded = loaded,
              }
              buf = bufs[filename]
            end
            return buf.bufnr
          end
          local function cleanup_bufs()
            for _, buf in pairs(bufs) do
              -- Save the buffer before closing
              vim.api.nvim_buf_call(buf.bufnr, function()
                vim.cmd("write")
              end)
              -- Close the buffer
              if vim.api.nvim_buf_is_valid(buf.bufnr) then
                if not buf.loaded then
                  vim.api.nvim_buf_delete(buf.bufnr, { force = true })
                end
              end
            end
          end

          local new_tasks = {}
          for _, l in ipairs(lines) do
            local task, id = l:match("^(.-) %[id::(.-)%]$")
            if id == nil then
              if l ~= "" then
                table.insert(new_tasks, l)
              end
            else
              local state = l:match("%s*-%s%[(.*)%]%s")
              task = cmp.marker_to_md_task(state, task)
              id = tonumber(id)
              local item = items[id]
              if item ~= nil then
                -- Basically a pop
                items[id] = nil
                -- Task has been edited
                if task ~= item.data.task.text then
                  local bufnr = load_buf(item.data.filename)
                  -- Replace the line in the file
                  vim.api.nvim_buf_set_lines(bufnr, item.data.lnum - 1, item.data.lnum, false, { task })
                end
              end
            end
          end

          -- Remaining items means some marks have been deleted
          for _, item in pairs(items) do
            local bufnr = load_buf(item.data.filename)
            vim.api.nvim_buf_set_lines(bufnr, item.data.lnum - 1, item.data.lnum, false, {})
          end

          -- Add new tasks to today journal
          for _, new_task in ipairs(new_tasks) do
            local journal_path = f.journal({ desc = "today", create = true, show = false })
            local bufnr = load_buf(journal_path)
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            new_task = "- [ ] " .. new_task
            vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { new_task })
          end
          cleanup_bufs()
        end,
      })
    end,
  }
end

M.edit_name = "tasks.edit"
--- Deck actions to edit tasks
---@param opts? beez.pickers.deck.tasks.actions.Opts
---@return deck.Action[]
function M.edit(opts)
  opts = opts or {}
  local u = require("beez.u")

  local actions = u.deck.edit_actions({
    prefix = M.edit_name .. ".",
    edit_line = edit_tasks,
    edit_line_end = {
      ---@diagnostic disable-next-line: missing-fields
      edit_opts = {
        get_pos = function(item, pos)
          -- 6 for beginning of task
          local offset = u.utf8.len(item.data.task.task_desc) + 6 + item.data.col - 1
          return { pos[1], offset }
        end,
        get_feedkey = function(feedkey)
          return "i"
        end,
      },
    },
    edit_line_start = {
      ---@diagnostic disable-next-line: missing-fields
      edit_opts = {
        get_pos = function(item, pos)
          -- 6 for beginning of task
          return { pos[1], 6 + item.data.col - 1 }
        end,
        get_feedkey = function(feedkey)
          return "i"
        end,
      },
    },
  })
  return actions
end

return M
