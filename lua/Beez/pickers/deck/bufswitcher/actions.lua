local M = {}

--- Deck action for setting the active stack
---@param opts? table
---@return deck.Action[]
function M.set_active_stack(opts)
  opts = opts or {}
  local name = "bufswitcher.set_active_stack"
  return {
    require("deck").alias_action("default", name),
    {
      name = name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        local stack = item.data.stack
        local bs = require("Beez.bufswitcher")
        bs.sl:set_active(stack.name)
        bs.refresh_ui()
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
  local name = "bufswitcher.add_stack"
  return {
    require("deck").alias_action("open_keep", name),
    {
      name = name,
      execute = function(ctx)
        local bs = require("Beez.bufswitcher")
        vim.schedule(function()
          vim.ui.input({ prompt = "Create a stack with name: " }, function(res)
            if res == nil then
              return
            end

            bs.sl:add(res)
            ctx.hide()
            bs.refresh_ui()
          end)
        end)
      end,
    },
  }
end

--- Deck action for deleting a stack
---@param opts? table
---@return deck.Action[]
function M.remove_stack(opts)
  opts = opts or {}
  local name = "bufswitcher.remove_stack"
  return {
    require("deck").alias_action("delete", name),
    {
      name = name,
      execute = function(ctx)
        local bs = require("Beez.bufswitcher")
        local item = ctx.get_action_items()[1]
        local choice = vim.fn.confirm("Are you sure you want to do this?", "&Yes\n&No")
        if choice == 1 then
          bs.sl:remove(item.data.stack.name)
          ctx.execute()
        end
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
        local bs = require("Beez.bufswitcher")
        local item = ctx.get_action_items()[1]
        vim.schedule(function()
          vim.ui.input({ prompt = "Edit stack name: ", default = item.data.stack.name }, function(res)
            if res == nil or res == item.data.stack.name then
              return
            end

            bs.sl.rename(item.data.stack.name, res)
            bs.refresh_ui()
            ctx.execute()
          end)
        end)
      end,
    },
  }
end

return M
