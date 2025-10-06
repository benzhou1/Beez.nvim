local M = {}

---@class Beez.flotes.Task
---@field state string
---@field text string
---@field line string
---@field tags table<string, boolean>

--- Parse line into a task object
---@param line string
---@return Beez.flotes.Task?
function M.parse_line(line)
  local task_state, task_desc = line:match("^%s*-%s%[(%s?x?/?)%]%s(.*)$")
  if task_state == nil or task_desc == nil then
    return nil
  end

  local tags = {}
  for tag in task_desc:gmatch("#([^%s]+)") do
    tags[tag] = true
    task_desc = task_desc:gsub(" #" .. tag, "")
  end

  local task = {
    state = task_state,
    line = line,
    text = task_desc,
    tags = tags,
  }
  return task
end
return M
