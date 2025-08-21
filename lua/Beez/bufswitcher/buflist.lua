local Buf = require("Beez.bufswitcher.buf")
local c = require("Beez.bufswitcher.config")
local u = require("Beez.u")

---@class Beez.bufswitcher.data
---@field pinned {filename: string}[]
---@field recents string[]

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
  b.recents = {}
  return b
end

--- Load from persisted data file
---@param path Path
function Buflist:load(path)
  if not path:exists() then
    return
  end
  local file = io.open(path.filename, "r")
  local data
  if file then
    local lines = file:read("*a")
    ---@type Beez.bufswitcher.data
    data = vim.fn.json_decode(lines)
    file:close()
  else
    error("Could not open file: " .. path.filename)
  end

  if data ~= nil then
    for _, d in ipairs(data.pinned) do
      -- Load pinned buffers
      local bufnr = vim.fn.bufnr(d.filename, true)
      vim.fn.bufload(bufnr)
      vim.bo[bufnr].buflisted = true

      local buf = Buf:new(d.filename)
      if buf:is_valid() then
        buf:pin()
        table.insert(self.bufs, buf)
      end
    end
    self.recents = data.recents or {}
  end
end

--- Persist data to a file
---@param path Path
function Buflist:save(path)
  ---@type Beez.bufswitcher.data
  local data = { pinned = {}, recents = self.recents }
  for _, b in ipairs(self.bufs) do
    if b.pinned then
      table.insert(data.pinned, { filename = b.path })
    end
  end

  local json_string = vim.fn.json_encode(data)
  local file = io.open(path.filename, "w")
  assert(file, "Could not open file for writing: " .. path.filename)
  file:write(json_string)
  file:close()
end

--- Adds a file path to recent list
---@param path string
function Buflist:add_recent(path)
  self:remove_recent(path)
  table.insert(self.recents, 1, path)
end

--- Remove path from recent list
---@param path string
function Buflist:remove_recent(path)
  u.tables.remove(self.recents, path)
end

--- Add a buffer to the list
---@param bufnr integer
function Buflist:add(bufnr)
  -- Remove the buffer if it already exists
  local _, buf = self:remove(bufnr)
  -- Buffer doesnt exists, create a new one
  if buf == nil then
    local filename = vim.api.nvim_buf_get_name(bufnr)
    buf = Buf:new(filename)
  end

  if not buf:is_valid() then
    return
  end

  -- Add a new buffer to the front
  table.insert(self.bufs, 1, buf)
  -- Set new buffer as current
  for _, b in ipairs(self.bufs) do
    b:set_current(false)
  end
  buf:set_current()

  -- Add to recent list
  self:add_recent(buf.path)
end

--- Remove a buffer from the list
---@return integer, Beez.bufswitcher.buf?
function Buflist:remove(bufnr)
  local i, buf = self:get(bufnr)
  if buf == nil then
    return 0, nil
  end
  table.remove(self.bufs, i)
  return i, buf
end

--- Gets the current buffer in the list
function Buflist:current()
  for _, b in ipairs(self.bufs) do
    if b.current then
      return b
    end
  end
end

--- Find a buffer with specified options
---@return integer, Beez.bufswitcher.buf?
function Buflist:get(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local i, buf = u.tables.find(self.bufs, function(b)
    return b.path == filename
  end)
  return i, buf
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

--- Sort buffer list by recency
---@param bufs Beez.bufswitcher.buf[]
---@param recent_paths string[]
---@return Beez.bufswitcher.buf[]
local function sort_by_recency(bufs, recent_paths)
  local recent_files = {}
  for i, path in ipairs(recent_paths) do
    recent_files[path] = #recent_paths - i
  end

  table.sort(bufs, function(a, b)
    local a_recent_idx = recent_files[a.path] or 0
    local b_recent_idx = recent_files[b.path] or 0
    return a_recent_idx > b_recent_idx
  end)
  return bufs
end

--- List buffers
---@param opts? {pinned?: boolean, sort?: "recency"}
---@return Beez.bufswitcher.buf[]
function Buflist:list(opts)
  opts = opts or {}
  -- No filters
  if opts == {} then
    return self.bufs
  end
  local bufs = {}

  for _, b in ipairs(self.bufs) do
    local valid = true
    if opts.pinned ~= nil then
      if (opts.pinned and not b.pinned) or (not opts.pinned and b.pinned) then
        valid = false
      end
    end
    if valid then
      table.insert(bufs, b)
    end
  end

  if opts.sort == nil or opts.sort == "recency" then
    bufs = sort_by_recency(bufs, self.recents)
  end
  return bufs
end

return Buflist
