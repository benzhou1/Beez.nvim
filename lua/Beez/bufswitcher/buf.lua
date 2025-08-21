local hl = require("Beez.bufswitcher.highlights")
local u = require("Beez.u")

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
---@field pinned boolean
---@field label table<string>
---@field name table<string>
Buf = {}
Buf.__index = Buf

--- Instantiates a new buffer object
---@param filename string
---@return Beez.bufswitcher.buf
function Buf:new(filename)
  local b = {}
  setmetatable(b, Buf)

  b.id = vim.fn.bufnr(filename)
  b.path = filename
  b.basename = u.paths.basename(b.path)
  b.dirname = u.paths.dirname(b.path)
  b.lastused = 0
  b.listed = 0
  b.buftype = ""
  b.ft = ""
  b.current = vim.api.nvim_get_current_buf() == b.id
  b.pinned = false
  b.label = { "", hl.hl.label }
  b.name = { b.basename, hl.hl.name }

  if vim.api.nvim_buf_is_valid(b.id) then
    local buf_info = vim.fn.getbufinfo(b.id)[1]
    b.lastused = buf_info.lastused
    b.listed = buf_info.listed
    b.buftype = vim.bo[b.id].buftype
    b.ft = vim.bo[b.id].filetype
  end
  return b
end

--- Make a copy
---@return Beez.bufswitcher.buf
function Buf:copy()
  local b = Buf:new(self.path)
  b:set_current(self.current)
  b:set_label(self.label[1], self.label[2])
  b:set_name(self.name[1], self.name[2])
  b.pinned = self.pinned
  return b
end

--- Checks if a buffer is valid
---@return boolean
function Buf:is_valid()
  local valid = self.path ~= ""
    and vim.api.nvim_buf_is_valid(self.id)
    and self.basename ~= nil
    and self.basename ~= ""
    and self.name ~= nil
    and self.name ~= ""
    and self.buftype ~= "nofile"
    and self.listed == 1

  return valid
end

--- Sets the buffer as pinned
function Buf:pin()
  if not self:is_valid() then
    return
  end
  self.pinned = true
end

--- Unset the pinned state of the buffer
function Buf:unpin()
  self.pinned = false
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

--- Assign a label to the buf
---@param label string
---@param label_hl? string
function Buf:set_label(label, label_hl)
  self.label = { label, label_hl or "Normal" }
end

--- Assign a display name to the buf
---@param name_highlights string[][]
function Buf:set_name(name_highlights)
  self.name = name_highlights
end

return Buf
