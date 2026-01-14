local M = {}
local cmds = require("beez.cmds")

M.run_cmd_external = {}
--- Deck action to run a command in a neovide terminal window
---@param opts? table
---@return deck.Action[]
function M.run_cmd_external.action(opts)
  opts = opts or {}
  return {
    require("deck").alias_action("default", M.run_cmd_external.name),
    {
      name = M.run_cmd_external.name,
      execute = function(ctx)
        local item = ctx.get_action_items()[1]
        cmds.neovide.run_cmd(item.data.cmd)
        ctx:hide()
        if opts.quit then
          vim.schedule(function()
            vim.cmd("q")
          end)
        end
      end,
    },
  }
end
M.run_cmd_external.name = "scripts.run_cmd_external"

M.open_neohub = {}
--- Deck action to open project with neohub
---@param opts? table
---@return deck.Action[]
function M.open_neohub.action(opts)
  opts = opts or {}
  local get_path = opts.get_path
    or function(ctx)
      local item = ctx.get_action_items()[1]
      return item.data.root
    end
  local get_name = opts.get_name
    or function(ctx)
      local item = ctx.get_action_items()[1]
      return item.data.name
    end

  return {
    require("deck").alias_action("default", M.open_neohub_action_name),
    {
      name = M.open_neohub.name,
      execute = function(ctx)
        local path = get_path(ctx)
        local name = get_name(ctx)
        cmds.neovide.open_neohub(name, path)
        if ctx ~= nil then
          ctx:hide()
        end
        if opts.quit_on_action then
          vim.schedule(function()
            vim.cmd("q")
          end)
        end
      end,
    },
  }
end
M.open_neohub.name = "projects.open_neohub"

M.open_lazygit = {}
--- Deck action to open project in a lazygit window
---@param opts? table
---@return deck.Action[]
function M.open_lazygit.action(opts)
  opts = opts or {}
  local get_path = opts.get_path
    or function(ctx)
      local item = ctx.get_action_items()[1]
      return item.data.root
    end

  return {
    require("deck").alias_action("default", M.open_lazygit_action_name),
    {
      name = M.open_lazygit.name,
      execute = function(ctx)
        local path = get_path(ctx)
        cmds.neovide.open_lazygit(path)
        if ctx ~= nil then
          ctx:hide()
        end
        if opts.quit then
          vim.schedule(function()
            vim.cmd("q")
          end)
        end
      end,
    },
  }
end
M.open_lazygit.name = "projects.open_lazygit"

return M
