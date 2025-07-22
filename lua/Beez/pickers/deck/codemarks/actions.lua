local u = require("Beez.u")
local M = { toggles = { global_codemarks = false, global_stacks = false } }

M.open_zed = require("Beez.pickers.deck.actions").open_zed

---@return deck.Action
---@param opts? {stacks?: boolean}
function M.toggle_global(opts)
  opts = opts or {}
  return {
    name = "toggle_global",
    ---@param ctx deck.Context
    execute = function(ctx)
      if opts.stacks then
        M.toggles.global_stacks = not M.toggles.global_stacks
        if M.toggles.global_stacks then
          vim.notify("Showing all stacks", vim.log.levels.INFO)
        else
          vim.notify("Showing stacks under current root", vim.log.levels.INFO)
        end
      else
        M.toggles.global_codemarks = not M.toggles.global_codemarks
        if M.toggles.global_codemarks then
          vim.notify("Showing global marks for all stacks under current root", vim.log.levels.INFO)
        else
          vim.notify("Showing global marks for current stack", vim.log.levels.INFO)
        end
      end
      ctx.execute()
    end,
  }
end

---@return deck.Action
---@param opts? {mark?: boolean}
function M.open(opts)
  opts = opts or {}
  local open_action = require("deck.builtin.action").open
  return {
    name = "open_codemarks",
    resolve = open_action.resolve,
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local cm = require("Beez.codemarks")

      open_action.execute(ctx)
      if not opts.mark then
        vim.schedule(function()
          cm.check_for_outdated_marks(item.data.filename)
          -- Line number was updated
          if item.data.lnum ~= item.data.mark.lineno then
            vim.api.nvim_win_set_cursor(0, { item.data.mark.lineno, 0 })
          end
          vim.cmd("normal! zz")
        end)
      end
    end,
  }
end

--- Deck action to set the active stack
---@return deck.Action
function M.select_stack()
  return {
    name = "select_stack",
    ---@param ctx deck.Context
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local item = ctx.get_action_items()[1]
      ctx.hide()
      vim.schedule(function()
        cm.stacks.set_active(item.data.stack.name, { hook = false })
      end)
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
          local cm = require("Beez.codemarks")
          local save = false
          for _, l in ipairs(lines) do
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
                save = cm.gmarks.update(mark:serialize(), updates, { save = false }) or save
              end
            end
          end

          -- Remaining items means some marks have been deleted
          for _, i in pairs(items) do
            cm.gmarks.del(i.data.mark:serialize(), { save = false })
            save = true
          end
          if save then
            cm.save()
          end
        end,
      })
    end,
  }
end

--- Deck action to update a global mark line
---@param line string
---@param opts? table
---@return deck.Action
function M.update_gmark_line(line, opts)
  return {
    name = "update_gmark_line",
    ---@param ctx deck.Context
    execute = function(ctx)
      local item = ctx.get_action_items()[1]
      local mark = item.data.mark
      local cm = require("Beez.codemarks")
      cm.gmarks.update(mark:serialize(), { line = line })
      vim.notify("Updated line for global mark: " .. mark.desc, vim.log.levels.INFO)
      ctx.hide()
    end,
  }
end

return M
