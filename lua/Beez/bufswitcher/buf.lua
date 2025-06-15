local u = require("Beez.u")

---@class Beez.bufswitcher.buf
---@field id integer
---@field basename string
---@field dirname string
---@field lastused integer
---@field flag string
---@field path string
---@field name string
---@field listed boolean
---@field buftype string
---@field ft string
---@field idx integer
---@field pin_idx integer
---@field current boolean
---@field pinned boolean
Buf = {}
Buf.__index = Buf

--- Instantiates a new buffer object
---@param buf_info table
---@return Beez.bufswitcher.buf
function Buf:new(buf_info)
  local b = {}
  setmetatable(b, Buf)

  b.id = buf_info.bufnr
  b.basename = u.paths.basename(buf_info.name)
  b.name = u.paths.name(buf_info.name)
  b.dirname = u.paths.dirname(buf_info.name)
  b.lastused = buf_info.lastused or buf_info.info.lastused
  b.flag = buf_info.flag
  b.path = buf_info.name
  b.listed = buf_info.listed
  b.buftype = vim.bo[b.id].buftype
  b.ft = vim.bo[b.id].filetype
  b.current = false
  b.pinned = false
  b.idx = 0
  b.pin_idx = 0

  return b
end

--- Checks if a buffer is valid
---@return boolean
function Buf:is_valid_buf()
  local is_valid_buftype = self.buftype ~= "nofile"
  local is_valid_name = self.path ~= ""
    and self.basename ~= nil
    and self.basename ~= ""
    and self.name ~= nil
    and self.name ~= ""
  local is_listed = self.listed == 1

  local valid = is_valid_name and is_valid_buftype and is_listed
  return valid
end

--- Sets the buffer as pinned
---@param pin_idx integer
function Buf:set_pinned(pin_idx)
  self.pin_idx = pin_idx
  self.pinned = true
end

--- Unset the pinned state of the buffer
function Buf:unset_pinned()
  self.pin_idx = 1
  self.pinned = false
end

--- Sets the buffer as current
function Buf:set_current()
  self.current = true
end

--- Sets the index of the buffer
---@param idx integer
function Buf:set_idx(idx)
  self.idx = idx
end

return Buf
