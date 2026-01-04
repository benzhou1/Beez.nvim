local M = {
  diffeditor = nil,
}

function M.setup(opts)
  opts = opts or {}

  -- Use command that opens a diff editor for jj splits/squash etc...
  -- Use this in a dedicated tab
  -- vim.api.nvim_create_user_command("BeezDiffEditor", function(params)
  --   local args = params.fargs
  --   if #args < 2 then
  --     vim.notify(
  --       "Error: BeezDiffEditor expects three arguments (left, right[, output])",
  --       vim.log.levels.ERROR
  --     )
  --     return
  --   end
  --   require("Beez.jj").start_diffeditor(args[1], args[2], args[3])
  -- end, {
  --   nargs = "*",
  -- })

  vim.api.nvim_create_user_command("BeezJJ", function()
    M.start(false)
  end, {})

  vim.api.nvim_create_user_command("BeezJJTab", function()
    M.start()
  end, {})

  -- Setup automcd to resize diff editor
  -- vim.api.nvim_create_autocmd("VimResized", {
  --   callback = function()
  --     local diffeditor = require("Beez.jj").diffeditor
  --     if diffeditor ~= nil then
  --       diffeditor:resize()
  --     end
  --   end,
  -- })
end

--- Opens a 2-way editor for handle jj splits/squash etc...
--- Opens 2 trees one for original commit and one for new commit
--- Should be used in a dedicated tab
---@param left_dir string
---@param right_dir string
---@param output_dir string
function M.start_diffeditor(left_dir, right_dir, output_dir)
  local u = require("Beez.u")
  -- 420 decimal == 0o644 octal
  -- 0o644 = rw-r--r--
  local chmod_mode = 420

  -- Make a copy of the right since it is read only
  vim.fn.delete(right_dir, "rf")
  u.os.copy_dir(output_dir, right_dir, { chmod_mode = chmod_mode })

  -- Make output the same as left, by deleting it and then copying left to output and make sure its writable
  vim.fn.delete(output_dir, "rf")
  -- Read write
  u.os.copy_dir(left_dir, output_dir, { chmod_mode = chmod_mode })

  M.diffeditor = require("Beez.jj.ui.diffeditor"):new(left_dir, right_dir, output_dir)
  M.diffeditor:render()
end

function M.start(new_tab)
  local ui = require("Beez.jj.ui.view").new()
  ui:render(new_tab)
end

function M.start_neovide()
  local cmds = require("Beez.cmds")
  local git_root = vim.fs.find(".git", { upward = true })[1]
  local root = vim.fs.dirname(git_root)
  cmds.neovide.open_beez_jj(root)
end

return M
