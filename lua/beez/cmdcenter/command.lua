local config = require("beez.cmdcenter.config")

Cmd = {}
Cmd.__index = Cmd

---@class Beez.cmdcenter.cmd
---@field lines string[]
---@field name string
---@field tags? table<string, boolean>
---@field cmd string[]
---@field comments string[]

--- Instantiate a new Cmd object
---@param text string
---@return Beez.cmdcenter.cmd
function Cmd:new(text)
  local c = {}
  setmetatable(c, Cmd)

  local lines = vim.split(text, "\n")
  local md = {}
  local cmd = {}
  local comment_lines = {}
  for _, l in ipairs(lines) do
    if l:match(config.config.comments_pattern) then
      table.insert(comment_lines, l)
      local key, value = l:gsub(config.config.comments_pattern, ""):match("%s+(%w+)=(.*)")
      -- Tag can be multiple values
      if key == "tags" then
        md[key] = md[key] or {}
        md[key][value] = true
      else
        md[key] = value
      end
    else
      table.insert(cmd, l)
    end
  end

  c.cmd = cmd
  c.comments = comment_lines
  c.name = md.name
  c.tags = md.tags
  return c
end

return Cmd
