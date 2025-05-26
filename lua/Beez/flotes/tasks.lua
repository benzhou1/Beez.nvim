local u = require("Beez.u")
local match_task_state = "^%s*- %[(.*)%] "
local match_fields = "%((%w+)::%s(%w+)%)"
local M = {
  todo_file = vim.fn.expand("~/SynologyDrive/Obsidian/Vault/TODO.md"),
  state = {},
}

---@class Beez.flotes.taskstatespec
---@field recurse_children boolean Should apply state to all children
---@field recurse_parents boolean Should apply state to all parents
---@field recurse_parents_if_done? boolean Should apply state to all parents that are marked done
---@field done boolean Is a done state?
---@field sort integer Value to sort tasks by
---@field desc string Description of state
---@field key string Keymap for menu when setting state
---@field default boolean? Is this the default state?

---@class Beez.flotes.priorityspec
---@field sort integer Sort value
---@field key string Keymap for menu when setting priority
---@field desc string Value that is displayed in the UI
---@field default boolean? Is this the default priority?

---@type table<string, Beez.flotes.taskstatespec>
M.task_states = {
  [" "] = {
    recurse_children = false,
    recurse_parents = false,
    recurse_parents_if_done = true,
    done = false,
    sort = 2,
    desc = "todo",
    key = "<space>",
    defualt = true,
  },
  ["/"] = {
    recurse_children = false,
    recurse_parents = true,
    done = false,
    sort = 3,
    desc = "in progress",
    key = "/",
  },
  ["x"] = {
    recurse_children = true,
    recurse_parents = false,
    done = true,
    sort = 1,
    desc = "done",
    key = "x",
  },
}

---@type table<string, Beez.flotes.priorityspec>
M.priorities = {
  ["L"] = { sort = 1, key = "l", desc = "low", default = true },
  ["M"] = { sort = 2, key = "m", desc = "medium" },
  ["H"] = { sort = 3, key = "h", desc = "high" },
}

--- Creates a tasks class and returns it
---@return Beez.flotes.tasks
function M.get_tasks()
  if M.state.tasks == nil then
    local Path = require("plenary.path")
    local p = Path:new(M.todo_file)
    assert(p:is_file())

    local lines = vim.fn.readfile(M.todo_file)
    local tasks = M.Tasks:new(lines)
    M.state.tasks = tasks
  end
  return M.state.tasks
end

--- Whether task should be shown
---@param task Beez.flotes.task|Beez.flotes.task.line
---@param opts {show_done: boolean}
---@return boolean
function M.should_show_task(task, opts)
  opts = opts or {}
  if task.type ~= "task" then
    return false
  end

  local show_done = opts.show_done
  if not show_done and task.done then
    return false
  end
  return true
end

--- Extract task state from line
---@param line string
---@return string?
local function get_task_state(line)
  local task_state = line:match(match_task_state)
  return task_state
end

--- Checks if a line is a task line
---@param line string
---@return boolean
local function is_line_task(line)
  local task_state = get_task_state(line)
  return task_state ~= nil
end

--- Calculates the number of leading spackes for a line
---@param line string
---@return number
local function calculate_indent(line)
  local indent = 0
  for i = 1, #line do
    local c = line:sub(i, i)
    if c ~= " " then
      break
    end
    indent = indent + 1
  end
  return indent
end

--- Generate a unique id for a task
---@return number
local function gen_id()
  math.randomseed(os.clock() * 100000000000)
  local id = math.random(1000000, 9999999)
  for _ = 1, 3 do
    id = math.random(1000000, 9999999)
  end
  return id
end

---@class Beez.flotes.task.taskopts
---@field task_states table<string, Beez.flotes.taskstatespec>
---@field priorities table<string, Beez.flotes.priorityspec>

--- Represents a line that is not a task
---@class Beez.flotes.task.line
---@field type string
---@field _line string
M.Line = {}
M.Line.__index = M.Line

--- Create a new Line class
---@param line string
---@param opts? table
---@return Beez.flotes.task.line
---@diagnostic disable-next-line: unused-local
function M.Line:new(line, opts)
  local l = {}
  setmetatable(l, M.Line)
  l.type = "line"
  l._line = line
  return l
end

--- Copy line
---@param opts table
---@return Beez.flotes.task.line
function M.Line:copy(opts)
  return M.Line:new(self:line(), opts)
end

--- Place holder
---@return function
function M.Line:iter_children()
  return function() end
end

--- Generates current line based on parameters
---@return string
function M.Line:line(_)
  return self._line
end

--- Place holder
---@param parent Beez.flotes.task | Beez.flotes.task.line
---@diagnostic disable-next-line: unused-local
function M.Line:set_parent(parent) end

--- Place holder
---@param state string
---@diagnostic disable-next-line: unused-local
function M.Line:set_state(state) end

--- Place holder
---@param priority string
---@diagnostic disable-next-line: unused-local
function M.Line:set_priority(priority) end

---@class Beez.flotes.task
---@field type string
---@field state string
---@field text string
---@field fields table
---@field parent Beez.flotes.task
---@field children (Beez.flotes.task|Beez.flotes.task.line)[]
---@field done boolean
---@field id number
---@field opts Beez.flotes.task.taskopts
M.Task = {}
M.Task.__index = M.Task

--- Creates a new Task class
---@param line string
---@param opts? Beez.flotes.task.taskopts
---@return Beez.flotes.task
function M.Task:new(line, opts)
  opts = opts or {
    task_states = M.task_states,
    priorities = M.priorities,
  }
  local t = {}
  setmetatable(t, M.Task)
  t.type = "task"
  t.state = get_task_state(line) or " "
  t.text = line:gsub(match_task_state, "")
  t.fields = {}
  t.parent = nil
  t.children = {}
  t.done = false
  t.opts = opts
  t:_set_done()

  for k, v in pairs(opts.priorities) do
    if v.default then
      t.fields.priority = k
      break
    end
  end
  for k, v in t.text:gmatch(match_fields) do
    if k == "id" then
      t.fields[k] = tonumber(v)
    else
      t.fields[k] = v
    end
  end
  t.text = u.strs.trimr(t.text:gsub(match_fields, ""))

  t.id = t.fields.id
  if t.id == nil then
    t.id = gen_id()
    t.fields.id = t.id
  end
  return t
end

function M.Task:_set_done()
  self.done = false
  local state = self.opts.task_states[self.state]
  if state ~= nil then
    self.done = state.done
  end
end

--- Copy task
---@param opts table
---@return Beez.flotes.task
function M.Task:copy(opts)
  local t = M.Task:new(self:line(), opts)
  for _, c in ipairs(self.children) do
    t:insert_child(c:copy(opts))
  end
  t.id = gen_id()
  t.fields.id = t.id
  return t
end

--- Calculate indent level of task
---@return integer
function M.Task:calculate_indent()
  -- Ignore root
  local level = -1
  local parent = self.parent
  local indent = 2
  while parent ~= nil do
    level = level + 1
    parent = parent.parent
  end
  return indent * level
end

--- Generate task line based on task fields
---@param opts {show_hyphen: boolean, show_fields: boolean}?
---@return string
function M.Task:line(opts)
  opts = opts or {}
  local indent = self:calculate_indent()
  local line = string.rep(" ", indent)
  if opts.show_hyphen ~= false then
    line = line .. "- "
  end

  line = line .. "[" .. self.state .. "] " .. self.text

  if opts.show_fields ~= false then
    for k, v in pairs(self.fields) do
      line = line .. " (" .. k .. ":: " .. v .. ")"
    end
  end
  return line
end

--- Return iterator for all children recursively
---@return function
function M.Task:iter_children()
  local children = {}
  local idx = 0
  for _, c in ipairs(self.children) do
    table.insert(children, c)
  end

  return function()
    local t = table.remove(children)
    if t == nil then
      return
    end
    for i = 1, #t.children do
      local c = t.children[#t.children + 1 - i]
      table.insert(children, c)
    end
    idx = idx + 1
    return idx, t
  end
end

--- Sets state of task and all children if specified
---@param state string
function M.Task:set_state(state)
  local state_spec = self.opts.task_states[state]
  if state_spec == nil then
    return
  end

  self.state = state
  -- Set all children to the new state reucrively
  if state_spec.recurse_children then
    for _, child in self:iter_children() do
      if child.type == "task" then
        child:set_state(state)
      end
    end
  end
  -- Set all parents to the new state recursively
  if state_spec.recurse_parents then
    local parent = self.parent
    while parent ~= nil do
      if state_spec.recurse_parents_if_done and not parent.done then
        break
      else
        parent:set_state(state)
        parent = parent.parent
      end
    end
  end
  self:_set_done()
end

--- Sets priority of task
---@param priority string
function M.Task:set_priority(priority)
  self.fields.priority = priority
end

--- Sets a new parent
---@param parent Beez.flotes.task
function M.Task:set_parent(parent)
  self.parent = parent
  for _, child in ipairs(self.children) do
    child:set_parent(self)
  end
end

--- Insets a child task under current task at the end
---@param child Beez.flotes.task|Beez.flotes.task.line
---@param pos? number
function M.Task:insert_child(child, pos)
  if pos ~= nil then
    table.insert(self.children, pos, child)
  else
    table.insert(self.children, child)
  end
  child:set_parent(self)
end

--- Removes a child task from current task
---@param child Beez.flotes.task|Beez.flotes.task.line
function M.Task:remove_child(child)
  for i, c in ipairs(self.children) do
    if c.id == child.id then
      table.remove(self.children, i)
      break
    end
  end
  child.parent = nil
end

--- Remove a child by text
---@param text string
---@return Beez.flotes.task|Beez.flotes.task.line?
function M.Task:remove_child_by_text(text)
  for i, c in ipairs(self.children) do
    if c.text == text then
      table.remove(self.children, i)
      c.parent = nil
      return c
    end
  end
end

--- Updates the current task with another one
---@param t Beez.flotes.task
---@return boolean
function M.Task:update(t)
  local changed = false
  if self.text ~= t.text then
    changed = true
    self.text = t.text
  end
  if self.state ~= t.state then
    changed = true
    self:set_state(t.state)
    self:_set_done()
  end
  if self.fields ~= t.fields then
    for k, v in pairs(t.fields) do
      if v ~= self.fields[k] then
        changed = true
        if k == "priority" then
          self:set_priority(v)
        elseif k ~= "id" then
          self.fields[k] = v
        end
      end
    end
  end
  return changed
end

---@class Beez.flotes.tasks
---@field opts table
---@field root Beez.flotes.task
---@field tasks_by_id table(number, task.Task)
M.Tasks = {}
M.Tasks.__index = M.Tasks

--- Creates a new Tasks
---@param lines string[]
---@param opts? Beez.flotes.task.taskopts
---@return Beez.flotes.tasks
function M.Tasks:new(lines, opts)
  local t = {}
  setmetatable(t, M.Tasks)
  t.opts = opts or {
    task_states = M.task_states,
    priorities = M.priorities,
  }
  t.root = M.Task:new("root", opts)
  t.tasks_by_id = {}
  t.tasks_by_id[t.root.id] = t.root

  local parents = { t.root }
  for i, line in ipairs(lines) do
    local is_task = is_line_task(line)
    local next_line = lines[i + 1]

    -- print("parents:")
    -- for i, p in ipairs(parents) do
    --   print(p:line())
    -- end

    local parent = parents[#parents]
    local indent = calculate_indent(line)
    local task = M.Line:new(line)
    if is_task then
      ---@diagnostic disable-next-line: cast-local-type
      task = M.Task:new(line, opts)
      t.tasks_by_id[task.id] = task
    end

    local next_line_indent = indent
    if next_line ~= nil then
      next_line_indent = calculate_indent(next_line)
    end

    if next_line_indent > indent then
      table.insert(parents, task)
    elseif next_line_indent < indent then
      for _ = 1, (indent - next_line_indent) / 2 do
        table.remove(parents, #parents)
      end
    end

    -- print("p:" .. parent:line())
    -- print("t:" .. line)
    -- if next_line ~= nil then
    --   print("n:" .. next_line)
    -- end
    -- print(tostring(indent), ", " .. tostring(next_line_indent))
    parent:insert_child(task)
  end
  return t
end

--- Move a task to a new parent
---@param task Beez.flotes.task|Beez.flotes.task.line
---@param new_parent Beez.flotes.task
function M.Tasks:move(task, new_parent)
  ---@diagnostic disable-next-line: param-type-mismatch
  task.parent:remove_child(task)
  new_parent:insert_child(task)
end

--- Inserts a task to tasks list
---@param task Beez.flotes.task|Beez.flotes.task.line
---@param parent Beez.flotes.task
function M.Tasks:insert(parent, task)
  parent:insert_child(task)
  self.tasks_by_id[task.id] = task
  for _, t in task:iter_children() do
    self.tasks_by_id[t.id] = t
  end
end

--- Removes task
---@param task Beez.flotes.task|Beez.flotes.task.line
function M.Tasks:remove(task)
  task.parent:remove_child(task)
  self.tasks_by_id[task.id] = nil
end

--- Removes a task to tasks list
---@param text string
---@param parent Beez.flotes.task
function M.Tasks:remove_by_text(parent, text)
  local t = parent:remove_child_by_text(text)
  if t ~= nil and self.tasks_by_id[t.id] ~= nil then
    self.tasks_by_id[t.id] = nil
  end
end

--- Get a task by id
---@param id number
---@return Beez.flotes.task?
function M.Tasks:get(id)
  return self.tasks_by_id[id]
end

--- Get task by text
---@param parent Beez.flotes.task
---@param text string
---@return (Beez.flotes.task|Beez.flotes.task.line)?
function M.Tasks:get_by_text(parent, text)
  for _, child in ipairs(parent.children) do
    if child.text == text then
      return child
    end
  end
end

--- Save tasks to specified path
---@param path? string
function M.Tasks:save(path)
  path = path or M.todo_file
  local file = io.open(path, "w")
  if file ~= nil then
    local _, _ = pcall(function()
      for _, l in self:lines() do
        local line = l:line()
        file:write(line .. "\n")
      end
    end)
    file:close()
  end
end

--- Returns iterator for all lines
---@return function
function M.Tasks:lines()
  local idx = 1
  local children = {}
  -- Insert root children first so that we dont incude root with results
  for i = 1, #self.root.children do
    local c = self.root.children[#self.root.children + 1 - i]
    table.insert(children, c)
  end

  return function()
    local t = table.remove(children)
    if t == nil then
      return
    end
    local _idx = idx
    if t.children ~= nil then
      for i = 1, #t.children do
        local c = t.children[#t.children + 1 - i]
        table.insert(children, c)
      end
    end
    idx = idx + 1
    return _idx, t
  end
end

function M.Tasks:print_lines()
  for _, line in self:lines() do
    if line:line() == "" then
      print("blank")
    end
    print(line:line())
  end
end

return M
