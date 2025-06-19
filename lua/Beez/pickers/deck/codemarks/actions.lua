local M = { toggles = { global_codemarks = false, global_marks = false } }

M.open_zed = require("Beez.pickers.deck.actions").open_zed

---@return deck.Action
---@param opts? {mark?: boolean}
function M.toggle_global(opts)
  opts = opts or {}
  return {
    name = "toggle_global",
    ---@param ctx deck.Context
    execute = function(ctx)
      if opts.mark then
        M.toggles.global_marks = not M.toggles.global_marks
        if M.toggles.global_marks then
          vim.notify("Showing all marks globally", vim.log.levels.INFO)
        else
          vim.notify("Showing marks for current file only", vim.log.levels.INFO)
        end
      else
        M.toggles.global_codemarks = not M.toggles.global_codemarks
        if M.toggles.global_codemarks then
          vim.notify("Showing all codemarks globally", vim.log.levels.INFO)
        else
          vim.notify("Showing codemarks for current project only", vim.log.levels.INFO)
        end
      end
      ctx.execute()
    end,
  }
end

---@return deck.Action
---@param opts? {mark?: boolean}
function M.delete(opts)
  opts = opts or {}
  return {
    name = "delete_mark",
    execute = function(ctx)
      if opts.mark then
        local marks = require("Beez.codemarks").marks
        for _, item in ipairs(ctx.get_action_items()) do
          marks:del(item.data.data)
        end
      else
        local marks = require("Beez.codemarks").gmarks
        for _, item in ipairs(ctx.get_action_items()) do
          marks:del(item.data.data)
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
      open_action.execute(ctx)
      if not opts.mark then
        vim.schedule(function()
          require("Beez.codemarks").check_for_outdated_marks(item.data.filename, item.data.lnum)
        end)
      end
    end,
  }
end

return M
