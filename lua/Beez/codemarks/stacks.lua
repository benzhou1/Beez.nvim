local Stack = require("Beez.codemarks.stack")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")

---@class Beez.codemarks.stacksdata
---@field stacks table<string, Beez.codemarks.stackdata>
---@field curr_stacks table<string, string>

---@class Beez.codemarks.stacks
---@field opts { stacks_file: string }
---@field stacks table<string, Beez.codemarks.stack>
---@field curr_stacks table<string, string>
---@field curr_stack? string
Stacks = {}
Stacks.__index = Stacks

--- Creats a new Stacks object
---@param opts { stacks_file: string}
---@return Beez.codemarks.stacks
function Stacks:new(opts)
  local s = {}
  setmetatable(s, Stacks)

  s.opts = opts or {}
  s.stacks = {}
  s.curr_stacks = {}
  s.curr_stack = nil

  -- load stacks file
  local file = io.open(opts.stacks_file, "r")
  if file then
    local lines = file:read("*a")
    local data = Stacks:deserialize(lines)
    for k, d in pairs(data.stacks) do
      local stack = Stack:new(d)
      s.stacks[k] = stack
    end
    s.curr_stacks = data.curr_stacks or {}
    file:close()
  else
    error("Could not open file: " .. opts.stacks_file)
  end

  return s
end

--- Prompts user to create a stack if none exists
function Stacks:prompt_if_no_stacks()
  local curr_stack = self:current()
  if next(self.stacks) == nil or curr_stack == nil then
    vim.ui.input({ prompt = "Create your first stack: " }, function(res)
      if res == nil then
        return
      end
      self:create_stack(res)
    end)
  end
end

--- Creates a new stack with the given name
---@param name string
function Stacks:create_stack(name)
  if self.stacks[name] then
    return
  end
  local root = u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
  local stack = Stack:new({
    stack = name,
    root = root,
    gmarks = {},
    marks = {},
  })
  self.stacks[name] = stack
  self.curr_stacks[root] = name
  vim.notify("Created stack: " .. name, vim.log.levels.INFO)
  self:save()
end

--- Adds a new global mark to the current stack
function Stacks:add_global_mark()
  self:prompt_if_no_stacks()

  local stack = self:current()
  assert(stack, "No active stack found")
  vim.ui.input({ prompt = "Describe the mark: " }, function(res)
    if res == nil then
      return
    end
    stack.gmarks:add(res)
    self:save()
  end)
end

--- Adds current line as a mark to the current stack
function Stacks:add_mark()
  self:prompt_if_no_stacks()

  local stack = self:current()
  assert(stack, "No active stack found")
  stack.marks:add()
  self:save()
end

--- Clears all marks for the current stack
function Stacks:clear_marks()
  local stack = self:current()
  if stack == nil then
    return
  end

  stack.marks:clear()
  self:save()
end

--- Gets the current stack
---@return Beez.codemarks.stack?
function Stacks:current()
  if self.curr_stack == nil then
    local root = u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
    local curr_stack = self.curr_stacks[root]
    if curr_stack == nil then
      return nil
    end
    self.curr_stack = self.stacks[curr_stack].name
  end
  return self.stacks[self.curr_stack]
end

--- Returns specific stack or the current one
---@param opts? { name: string? }
---@return Beez.codemarks.stack?
function Stacks:get(opts)
  opts = opts or {}
  if opts.name == nil then
    return self:current()
  end
  return self.stacks[opts.name]
end

--- Returns a list of stacks
---@param opts? { root?: string }
---@return Beez.codemarks.stack[]
function Stacks:list(opts)
  opts = opts or {}
  local stacks = {}
  for _, stack in pairs(self.stacks) do
    if opts.root ~= nil then
      if stack.root == opts.root then
        table.insert(stacks, stack)
      end
    else
      table.insert(stacks, stack)
    end
  end
  return stacks
end

--- Returns a data table of specified line
---@return Beez.codemarks.stacksdata
function Stacks:deserialize(lines)
  local data = vim.fn.json_decode(lines)
  data.stacks = data.stacks or {}
  data.curr_stacks = data.curr_stacks or {}
  return data
end

--- Serialize the stacks object to be saved
---@return Beez.codemarks.stacksdata
function Stacks:serialize()
  local data = {
    curr_stacks = self.curr_stacks,
    stacks = {},
  }
  for _, stack in pairs(self.stacks) do
    local stack_data = stack:serialize()
    data.stacks[stack.name] = stack_data
  end
  return data
end

--- Save the stacks to the file
function Stacks:save(opts)
  opts = opts or {}
  local data = self:serialize()
  local json_string = vim.fn.json_encode(data)
  local file = io.open(self.opts.stacks_file, "w")
  assert(file, "Could not open file for writing: " .. self.opts.stacks_file)
  file:write(json_string)
  file:close()
end

--- Sets the current active stack
---@param name string
---@param opts? { hook: boolean }
function Stacks:set_active_stack(name, opts)
  opts = opts or {}
  local stack = self:get({ name = name })
  if stack == nil then
    vim.notify("Stack '" .. name .. "' does not exist", vim.log.levels.WARN)
    return
  end
  local old_stack = self:current()
  local root = u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
  self.curr_stacks[root] = name
  self:save()
  vim.notify("Active stack: " .. name, vim.log.levels.INFO)

  if opts.hook ~= false and c.config.hooks.on_set_active_stack ~= nil then
    local old_stack_name = old_stack and old_stack.name or ""
    c.config.hooks.on_set_active_stack(old_stack_name, name)
  end
end

return Stacks
