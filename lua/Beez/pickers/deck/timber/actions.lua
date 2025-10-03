local u = require("Beez.u")
local M = {}

--- Deck action for clearing debug log statements
---@param opts? table
---@return deck.Action
function M.clear_log_statement(opts)
  opts = opts or {}
  local name = "timber.clear_log_statement"
  return {
    require("deck").alias_action("delete", name),
    {
      name = name,
      ---@param ctx deck.Context
      execute = function(ctx)
        local items = ctx.get_action_items()
        -- Need to reverse the sort order to avoid messing up line numbers when deleting
        items = u.tables.reverse(items)

        local bufnrs = {}
        for _, item in ipairs(items) do
          local bufnr = vim.fn.bufnr(item.data.filename, true)
          if bufnr ~= nil then
            vim.api.nvim_buf_set_lines(bufnr, item.data.lnum - 1, item.data.lnum, false, {})
            bufnrs[bufnr] = true
          end
        end
        for bufnr, _ in pairs(bufnrs) do
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("silent! write")
          end)
        end
        ctx.execute()
      end,
    },
  }
end

--- Deck action for toggling comment status on a debug log statement
---@param opts? table
---@return deck.Action
function M.toggle_comment_log_statement(opts)
  opts = opts or {}
  local timberp = require("plugins.timber")
  local name = "timber.toggle_comment_log_statement"
  return {
    require("deck").alias_action("toggle_comment", name),
    {
      name = name,
      ---@param ctx deck.Context
      execute = function(ctx)
        local items = ctx.get_action_items()
        local bufnrs = {}
        for _, item in ipairs(items) do
          local bufnr = vim.fn.bufnr(item.data.filename, true)
          if bufnr ~= nil then
            local line = item.data.log.text
            if item.data.log.commented_out then
              line = timberp.uncomment_out(item.data.log.text, opts.ft)
            else
              line = timberp.comment_out(item.data.log.text, opts.ft)
            end
            vim.api.nvim_buf_set_lines(bufnr, item.data.lnum - 1, item.data.lnum, false, { line })
            bufnrs[bufnr] = true
          end
        end
        for bufnr, _ in pairs(bufnrs) do
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("silent! write")
          end)
        end
        ctx.execute()
      end,
    },
  }
end

return M
