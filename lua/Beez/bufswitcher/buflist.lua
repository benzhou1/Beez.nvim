local Buf = require("Beez.bufswitcher.buf")
local c = require("Beez.bufswitcher.config")

---@class Beez.bufswitcher.buflist
---@field bufs Beez.bufswitcher.buf[]
Buflist = {}
Buflist.__index = Buflist

--- Instantiate a new Buflist
---@return Beez.bufswitcher.buflist
function Buflist:new()
  local b = {}
  setmetatable(b, Buflist)

  b.bufs = {}
  return b
end

--- Find a buffer with specified options
---@param opts {idx?: integer}
---@return Beez.bufswitcher.buf?
function Buflist:get(opts)
  if opts.idx then
    return self.bufs[opts.idx]
  end
end

--- Remove a buffer from the list
---@param opts {idx?: integer}
function Buflist:remove(opts)
  if opts.idx then
    table.remove(self.bufs, opts.idx)
  end
end

--- Default sort function by id
---@param bufs Beez.bufswitcher.buf[]
---@return Beez.bufswitcher.buf[]
function Buflist.def_sort(bufs)
  table.sort(bufs, function(a, b)
    return a.id > b.id
  end)
  return bufs
end

--- Refresh the buffer list
---@param opts? { pins?: table<string, integer>, curr_buf?: integer }
function Buflist:refresh(opts)
  opts = opts or {}
  self.bufs = {}
  local bufs = {}

  local bufnrs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufnrs) do
    local info = vim.fn.getbufinfo(buf)[1]
    local b = Buf:new(info)
    if b:is_valid_buf() then
      table.insert(bufs, b)
    end
  end

  -- Sort the buffer
  if c.config.hooks.sort then
    bufs = c.config.hooks.sort(bufs)
  else
    bufs = Buflist.def_sort(bufs)
  end

  -- Mark buffers as pinned or current
  for i, b in ipairs(bufs) do
    b:set_idx(i)
    if opts.pins and opts.pins[b.path] then
      b:set_pinned(opts.pins[b.path])
    end
    if opts.curr_buf and b.id == opts.curr_buf then
      b:set_current()
    end
    table.insert(self.bufs, b)
  end
end

--- List buffers
---@param opts? {first_char?: string, pinned?: boolean}
---@return Beez.bufswitcher.buf[]
function Buflist:list(opts)
  opts = opts or {}
  -- No filters
  if opts == {} then
    return self.bufs
  end
  local bufs = {}

  for i, b in ipairs(self.bufs) do
    local valid = true
    -- Return buffers with the specified first character
    if opts.first_char ~= nil then
      if not b.basename:startswith(opts.first_char) then
        valid = false
      end
    end
    if opts.pinned ~= nil then
      if (opts.pinned and not b.pinned) or (not opts.pinned and b.pinned) then
        valid = false
      end
    end
    if valid then
      b.idx = i
      table.insert(bufs, b)
    end
  end
  return bufs
end

return Buflist
