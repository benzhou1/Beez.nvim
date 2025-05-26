local Marks = require("Beez.codemarks.marks")
local u = require("Beez.u")
local c = require("Beez.codemarks.config")
local M = {}

--- Setup the plugin
---@param opts Beez.codemarks.config
function M.setup(opts)
  c.init(opts)
  local marks_file = u.paths.Path:new(opts.marks_file)
  local parent = marks_file:parent()

  -- Marks sure the parent exists
  if not parent:exists() then
    parent:mkdir()
  end
  -- Marks sure the marks file exists
  if not marks_file:exists() then
    marks_file:write("", "w")
  end

  -- Load the marks file
  M.marks = Marks:new({ marks_file = c.config.marks_file })
end

--- Add a new code mark
function M.add()
  vim.ui.input({ prompt = "Describe the mark" }, function(res)
    if res == nil then
      return
    end
    M.marks:add(res)
  end)
end

--- Picker for codemarks
---@param opts Beez.pick.opts?
function M.find(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = "deck" })
  local pickers = require("Beez.pickers")
  pickers.pick("codemarks", opts)
end

return M
