local M = {}

---@class Beez.ui.buffer
---@field bufnr number
---@field keys_mapped boolean
---@field events_mapped boolean
M.Buffer = {}
M.Buffer.__index = M.Buffer

--- Creates a Buffer
---@param bufnr number
---@param opts table?
---@return Beez.ui.buffer
function M.Buffer:new(bufnr, opts)
  local b = {}
  setmetatable(b, M.Buffer)

  b.bufnr = bufnr
  b.keys_mapped = false
  b.events_mapped = false
  return b
end

--- Deletes current buffer
function M.Buffer:clean()
  local status, errors = pcall(function(bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = false })
  end, self.bufnr)
end

return M
