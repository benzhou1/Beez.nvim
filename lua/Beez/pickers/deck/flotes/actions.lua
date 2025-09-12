local u = require("Beez.u")
local M = {
  toggles = { done_task = false },
}

--- Open note in flotes window
---@param opts? table
---@return deck.Action[]
function M.open_note(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("default", "open_note"),
    {
      name = "open_note",
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local f = require("Beez.flotes")
        ctx:hide()
        vim.schedule(function()
          f.show({ note_path = item.data.filename })
          vim.schedule(function()
            if item.data.lnum then
              vim.fn.cursor(item.data.lnum, item.data.col)
            end
          end)
        end)
      end,
    },
  }
end

--- Create a new note with title
M.new_note = {
  name = "new_note",
  execute = function(ctx)
    local f = require("Beez.flotes")
    local title = ctx.get_query()
    ctx:hide()
    f.new_note(title, {})
  end,
}

--- Delete note
M.delete_note = {
  name = "delete_note",
  execute = function(ctx)
    local Path = require("plenary.path")
    for _, item in ipairs(ctx.get_action_items()) do
      local path = Path:new(item.data.filename)
      local choice = vim.fn.confirm("Are you sure you want to delete this note?", "&Yes\n&No")
      if choice == 1 then
        path:rm()
        vim.notify("Deleted note: " .. path.filename, "info")
        ctx:execute()
      end
    end
  end,
}

--- Create note from template
M.new_note_from_template = {
  name = "new_note_from_template",
  execute = function(ctx)
    local item = ctx.get_action_items()[1]
    ctx:hide()
    vim.schedule(function()
      require("Beez.flotes").new_note_from_template(item.data.name)
    end)
  end,
}

--- Deck action to toggle showing done tasks or not
---@param opts? table
---@return deck.Action[]
function M.toggle_done_task(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("toggle1", "toggle_done_task"),
    {
      name = "toggle_done_task",
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
function M.edit_tasks(opts)
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
          if pos[2] < 3 or action == "insert_end" then
            return 2
          end
          return 1
        end,
        get_lines = function(items)
          local lines = {}
          for _, item in ipairs(items) do
            local line = item.data.task.task_text .. " [id::" .. item.data.i .. "]"
            table.insert(lines, line)
          end
          return lines
        end,
        save = function(items, lines)
          local bufs = {}
          local cmp = require("plugins.checkmate")
          local f = require("Beez.flotes")
          local function load_buf(filename)
            local bufnr = bufs[filename]
            local loaded = true
            if bufnr == nil then
              -- Load the buffer by filename
              bufnr = vim.fn.bufnr(filename)
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
            end
            return bufnr
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
                if task ~= item.data.task.task_text then
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

return M
