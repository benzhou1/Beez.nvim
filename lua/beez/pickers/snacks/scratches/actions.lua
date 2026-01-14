local u = require("beez.u")
local M = {}

--- Confirm the selected scratch and open it in the split window
function M.confirm(picker)
  picker:close()
  local item = picker:current()
  if not item then
    return
  end

  local scratches = require("scratches")
  local path = u.paths.Path:new(scratches.config.scratch_dir):joinpath(item.file)
  require("scratches").open({ path = path.filename })
end

--- Deletes the selected scratch file
function M.delete(picker)
  local item = picker:current()
  if not item then
    return
  end

  local scratches = require("scratches")
  local path = u.paths.Path:new(scratches.config.scratch_dir):joinpath(item.file)
  local choice = vim.fn.confirm("Are you sure you want to delete this scratch file?", "&Yes\n&No")
  if choice == 1 then
    if vim.fn.delete(path.filename) == -1 then
      return vim.notify("Failed to delete " .. path.filename, vim.log.levels.ERROR)
    end

    picker:close()
    vim.schedule(function()
      require("snacks.picker").resume()
    end)
  end
end

return M
