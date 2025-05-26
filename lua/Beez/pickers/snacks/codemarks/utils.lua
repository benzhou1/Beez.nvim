local M = { toggles = { global = false } }

--- Sets the global toggle
---@param value boolean
function M.set_global_toggle(value)
  M.toggles.global = value
end

--- Gets the global toggle
---@return boolean
function M.get_global_toggle()
  return M.toggles.global
end

--- Sets the picker title based on flags
---@param overrides table?
---@return string
function M.get_title(overrides)
  local toggles = vim.tbl_deep_extend("keep", overrides or {}, M.toggles)
  if toggles.global then
    return "Search all marks"
  end
  return "Search marks"
end

return M
