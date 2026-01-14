local c = require("beez.flotes.config")
local u = require("beez.u")
local utils = require("beez.flotes.utils")
local M = {}

---@class Beez.flotes.notes.opts
---@field name string?
---@field title string?
---@field dir string?
---@field content fun(Path: Path)?

--- Create a new note
---@param opts? Beez.flotes.notes.opts
---@return string
function M.create(opts)
  opts = opts or {}
  local name = opts.name or utils.timestamp() .. ".md"
  local dir = opts.dir or c.config.notes_dir

  -- A note with the same name already exists
  local note_path = u.paths.Path:new(dir):joinpath(name)
  if note_path:exists() then
    return note_path.filename
  end

  -- Create a new note
  local new_notes_path = u.paths.Path:new(dir):joinpath(name)
  if opts.title ~= nil then
    new_notes_path:write("# " .. opts.title .. "\n", "w")
  end
  if opts.content ~= nil then
    opts.content(new_notes_path)
  end
  return new_notes_path.filename
end

---@class Beez.flotes.templates.opts
---@field name string?
---@field template string
---@field cb fun(path: string)?

--- Create a new note from a template
---@param opts Beez.flotes.templates.opts
function M.create_template(opts)
  local f = require("beez.flotes")
  local template = c.config.templates.templates[opts.template]
  if template == nil then
    error("Template not found: " .. opts.template)
  end

  local path = M.create({
    name = opts.name,
    content = function(path)
      path:write("", "w")
    end,
  })
  f.show({ note_path = path })
  vim.schedule(function()
    local win_id = vim.api.nvim_get_current_win()
    if c.config.open_in_float then
      win_id = f.states.float.win_id
    end
    if win_id ~= nil then
      vim.api.nvim_win_call(win_id, function()
        c.config.templates.expand(template.template)
      end)
    end
  end)
end

return M
