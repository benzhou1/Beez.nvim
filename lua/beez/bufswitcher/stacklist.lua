local u = require("beez.u")

---@class Beez.bufswitcher.pinned_buf
---@field path string
---@field label string

---@class Beez.bufswitcher.stack
---@field name string
---@field pinned Beez.bufswitcher.pinned_buf[]

---@class Beez.bufswitcher.stacklist
---@field dir_path string
---@field stacks_path string
---@field stacks table<string, Beez.bufswitcher.stack>
---@field active string?
Stacklist = {}
Stacklist.__index = Stacklist

---@class Beez.bufswitcher.stacks.data
---@field stacks table<string, Beez.bufswitcher.stack>
---@field active string?

--- Creates a new stack list
---@param dir_path string
---@return Beez.bufswitcher.stacklist
function Stacklist:new(dir_path)
  local s = {}
  setmetatable(s, Stacklist)

  s.dir_path = dir_path
  s.stacks_path = vim.fs.joinpath(dir_path, "stacks.json")
  s.stacks = {}
  s.active = nil
  return s
end

--- Loads stack list from persistent storage
function Stacklist:load()
  if vim.fn.filereadable(self.stacks_path) == 0 then
    vim.fn.writefile({ '{"stacks": {}}' }, self.stacks_path)
    return
  end

  local file = io.open(self.stacks_path, "r")
  ---@type Beez.bufswitcher.stacks.data
  local data
  if file then
    local lines = file:read("*a")
    data = vim.fn.json_decode(lines)
    file:close()
  else
    error("Could not open file: " .. self.stacks_path)
  end

  if data ~= nil then
    for name, s in pairs(data.stacks) do
      self.stacks[name] = s
    end
    self.active = data.active
  end
end

--- Saves stack list to persistent storage
function Stacklist:save()
  ---@type Beez.bufswitcher.stacks.data
  local data = { stacks = self.stacks, active = self.active }
  local json_string = vim.fn.json_encode(data)
  local file = io.open(self.stacks_path, "w")
  assert(file, "Could not open file for writing: " .. self.stacks_path)
  file:write(json_string)
  file:close()
end

--- Adds a new stack to stack list
---@param name string
function Stacklist:add(name)
  local stack = self:get(name)
  if stack ~= nil then
    return
  end

  self.stacks[name] = { name = name, pinned = {} }
  self.active = name
  self:save()
end

--- Remove a stack from stack list
---@param name string
function Stacklist:remove(name)
  if self.active == name then
    local stack = next(self.stacks)
    if stack ~= nil then
      self.active = stack
    else
      self.active = nil
    end
  end
  self.stacks[name] = nil
  self:save()
end

--- Renames an existing stack
---@param name string
---@param new_name string
function Stacklist:rename(name, new_name)
  local stack = self:get(name)
  if stack == nil then
    return
  end

  stack.name = new_name
  self.stacks[new_name] = stack
  self.stacks[name] = nil
  if self.active == name then
    self.active = new_name
  end
  self:save()
end

--- Gets an existing stack by name
---@param name string
---@return Beez.bufswitcher.stack?
function Stacklist:get(name)
  return self.stacks[name]
end

--- Returns a pinned buffer by specified options
---@param opts {label?: string, path?: string}
---@return Beez.bufswitcher.pinned_buf?
function Stacklist:get_pinned(opts)
  local stack = self:get(self.active)
  if stack == nil then
    return
  end

  local found
  for _, s in ipairs(stack.pinned) do
    if opts.label ~= nil and s.label == opts.label then
      found = s
      break
    end
    if opts.path ~= nil and s.path == opts.path then
      found = s
      break
    end
  end
  return found
end

--- Returns a list of pinned buffers
---@return Beez.bufswitcher.pinned_buf[]
function Stacklist:list_pinned_buffers()
  local stack = self:get(self.active)
  if stack == nil then
    return {}
  end
  return stack.pinned
end

--- Pins current buffer to active stack
---@param label string
function Stacklist:pin(label)
  if self.active == nil then
    return vim.ui.input({ prompt = "Give your first stack a name: " }, function(name)
      if name == nil then
        return
      end
      self:add(name)
      self:pin(label)
    end)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local stack = self:get(self.active)
  if stack == nil then
    return
  end

  -- Override existing pin with same label or path
  stack.pinned = u.tables.filter(stack.pinned, function(b)
    return b.label ~= label and b.path ~= filepath
  end)
  table.insert(stack.pinned, { path = filepath, label = label })
  self:save()
end

--- Unpins current buffer from active stack
---@param path? string
function Stacklist:unpin(path)
  local filepath
  if path ~= nil then
    filepath = path
  else
    local bufnr = vim.api.nvim_get_current_buf()
    filepath = vim.api.nvim_buf_get_name(bufnr)
  end

  local stack = self:get(self.active)
  if stack == nil then
    return
  end
  u.tables.remove(stack.pinned, function(b)
    return b.path == filepath
  end)
  self:save()
end

--- Sets the active stack
---@param name string
function Stacklist:set_active(name)
  local stack = self:get(name)
  if stack == nil then
    return
  end
  self.active = name
  self:save()

  -- Load all pinned buffers in the stack
  local pinned = self:list_pinned_buffers()
  for _, p in ipairs(pinned) do
    local bufnr = vim.fn.bufadd(p.path)
    vim.fn.bufload(bufnr)
    vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
  end
end

--- Returns a list of all stacks
---@return Beez.bufswitcher.stack[]
function Stacklist:list()
  local stacks = {}
  for _, s in pairs(self.stacks) do
    table.insert(stacks, s)
  end
  return stacks
end

return Stacklist
