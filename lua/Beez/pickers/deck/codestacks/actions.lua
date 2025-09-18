local u = require("Beez.u")
local M = { toggles = {} }

--- Deck action for setting the active stack
---@param opts? table
---@return deck.Action[]
function M.set_active_stack(opts)
  opts = opts or {}
  local name = "codestacks.set_active_stack"
  return {
    require("deck").alias_action("default", name),
    {
      name = name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local stack = item.data.stack
        local cs = require("Beez.codestacks")
        cs.stacks.set_active(stack.name)
        ctx.hide()
      end,
    },
  }
end

--- Deck action for adding a new stack
---@param opts? table
---@return deck.Action[]
function M.add_stack(opts)
  opts = opts or {}
  local name = "codestacks.add_stack"
  return {
    require("deck").alias_action("open_keep", name),
    {
      name = name,
      execute = function(ctx)
        local cs = require("Beez.codestacks")
        cs.stacks.add()
        ctx.execute()
      end,
    },
  }
end

--- Deck action for deleting a stack
---@param opts? table
---@return deck.Action[]
function M.remove_stack(opts)
  opts = opts or {}
  local name = "codestacks.remove_stack"
  return {
    require("deck").alias_action("delete", name),
    {
      name = name,
      execute = function(ctx)
        local cs = require("Beez.codestacks")
        local item = ctx.get_action_items()[1]
        cs.stacks.remove(item.data.stack.name)
        ctx.execute()
      end,
    },
  }
end

--- Deck action for renaming a stack
---@param opts? table
---@return deck.Action[]
function M.rename_stack(opts)
  opts = opts or {}
  local name = "bufswitcher.rename_stack"
  return {
    require("deck").alias_action("edit_line_end", name),
    require("deck").alias_action("edit_line_start", name),
    {
      name = name,
      execute = function(ctx)
        local cs = require("Beez.codestacks")
        local item = ctx.get_action_items()[1]
        vim.schedule(function()
          cs.stacks.rename(item.data.stack.name)
          ctx.execute()
        end)
      end,
    },
  }
end

---@return deck.Action
---@param opts? {stacks?: boolean}
function M.toggle_global(opts)
  opts = opts or {}
  return {
    name = "toggle_global",
    ---@param ctx deck.Context
    execute = function(ctx)
      M.toggles.global_codemarks = not M.toggles.global_codemarks
      if M.toggles.global_codemarks then
        vim.notify("Showing global marks for all stacks", vim.log.levels.INFO)
      else
        vim.notify("Showing global marks for active stack", vim.log.levels.INFO)
      end
      ctx.execute()
    end,
  }
end

--- Deck action for opening the global mark in a overlook popup
---@return deck.Action
---@param opts? {mark?: boolean}
function M.open(opts)
  opts = opts or {}
  local open_action = require("deck.builtin.action").open
  return {
    name = "open_codestacks",
    resolve = open_action.resolve,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]

      ctx.hide()
      vim.schedule(function()
        local bufnr = vim.fn.bufnr(item.data.filename)
        -- Make sure buffer is loaded
        if bufnr == -1 then
          bufnr = vim.fn.bufadd(item.data.filename)
          vim.fn.bufload(bufnr)
          vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
        end

        require("overlook.ui").create_popup({
          target_bufnr = vim.fn.bufnr(item.data.filename),
          lnum = item.data.lnum,
          col = item.data.col or 0,
          title = item.data.filename,
        })
      end)

      -- open_action.execute(ctx)
      -- if not opts.mark then
      --   vim.schedule(function()
      --     -- Line number was updated
      --     if item.data.lnum ~= item.data.mark.lineno then
      --       vim.api.nvim_win_set_cursor(0, { item.data.mark.lineno, 0 })
      --     end
      --     vim.cmd("normal! zz")
      --   end)
      -- end
    end,
  }
end

--- Deck generic action to edit global marks
---@param opts table
---@return deck.Action
function M.edit_global_marks(opts)
  return {
    name = opts.name,
    ---@param ctx deck.Context
    execute = function(ctx)
      u.deck.edit_list(ctx, {
        action = opts.action,
        filetype = "md",
        get_pos = opts.get_pos,
        get_feedkey = opts.get_feedkey,
        get_lines = function(items)
          local lines = {}
          for _, item in pairs(items) do
            local mark = item.data.mark
            local line = mark.desc .. " [id::" .. item.data.i .. "]"
            table.insert(lines, line)
          end
          return lines
        end,
        save = function(items, lines)
          local cs = require("Beez.codestacks")
          for _, l in ipairs(lines) do
            -- This happens when all marks are removed
            if l ~= "" then
              local desc, id = l:match("^(.-) %[id::(.-)%]$")
              id = tonumber(id)
              assert(id ~= nil, "Invalid ID in line: " .. l)

              local item = items[id]
              if item ~= nil then
                -- Basically a pop
                items[id] = nil
                ---@type Beez.codemarks.gmark
                local mark = item.data.mark
                local updates = {}

                -- Check if description has changed
                if mark.desc ~= desc then
                  updates.desc = desc
                end

                -- Perform the update without saving
                if next(updates) ~= nil then
                  cs.marks.update(item.data.filename, item.data.lnum, updates)
                end
              end
            end
          end

          -- Remaining items means some marks have been deleted
          for _, i in pairs(items) do
            cs.marks.remove(i.data.filename, i.data.lnum)
          end
        end,
      })
    end,
  }
end
return M
