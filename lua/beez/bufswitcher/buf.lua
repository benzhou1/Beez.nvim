local u = require("beez.u")

---@class Beez.bufswitcher.buf
---@field id integer
---@field basename string
---@field dirname string
---@field lastused integer
---@field path string
---@field listed integer
---@field buftype string
---@field ft string
---@field current boolean
Buf = {}
Buf.__index = Buf

--- Instantiates a new buffer object
---@param bufnr integer
---@return Beez.bufswitcher.buf
function Buf:new(bufnr)
  local b = {}
  setmetatable(b, Buf)

  b.id = bufnr
  b.path = vim.api.nvim_buf_get_name(bufnr)
  b.basename = u.paths.basename(b.path)
  b.dirname = u.paths.dirname(b.path)
  b.lastused = 0
  b.listed = 0
  b.buftype = ""
  b.ft = ""
  b.current = vim.api.nvim_get_current_buf() == b.id

  if vim.api.nvim_buf_is_valid(b.id) then
    local buf_info = vim.fn.getbufinfo(b.id)[1]
    b.lastused = buf_info.lastused
    b.listed = buf_info.listed
    b.buftype = vim.bo[b.id].buftype
    b.ft = vim.bo[b.id].filetype
  end
  return b
end

--- Checks if a buffer is valid
---@return boolean
function Buf:is_valid()
  local valid = self.path ~= ""
    and vim.api.nvim_buf_is_valid(self.id)
    and self.basename ~= nil
    and self.basename ~= ""
    and self.buftype ~= "nofile"
    and self.listed == 1

  return valid
end

--- Set buf as the current one
---@param current? boolean
function Buf:set_current(current)
  if current ~= nil then
    self.current = current
    return
  end
  self.current = true
end

return Buf
