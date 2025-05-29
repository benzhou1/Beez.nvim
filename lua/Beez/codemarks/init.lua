local Marks = require("Beez.codemarks.marks")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")
local M = {}

--- Setup the plugin
---@param opts Beez.codemarks.config
function M.setup(opts)
  c.init(opts)
  local marks_file = u.paths.Path:new(opts.marks_file)
  local parent = marks_file:parent()

  -- Marks sure the parent exists
  if not parent:exists() then
    parent:mkdir()
  end
  -- Marks sure the marks file exists
  if not marks_file:exists() then
    marks_file:write("", "w")
  end

  -- Load the marks file
  M.marks = Marks:new({ marks_file = c.config.marks_file })
end

--- Edits the raw marks file
function M.edit_marks()
  vim.cmd("edit " .. c.config.marks_file)
end

--- Add a new code mark
function M.add()
  vim.ui.input({ prompt = "Describe the mark" }, function(res)
    if res == nil then
      return
    end
    M.marks:add(res)
  end)
end

--- Picker for codemarks
---@param opts Beez.pick.opts?
function M.find_picker(opts)
  local def_type = "deck"
  local ok, _ = pcall(require, "deck")
  if not ok then
    def_type = "snacks"
  end

  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  require("Beez.pickers").pick("codemarks", opts)
end

--- Checks current file for any outdated marks
---@param filename string
---@param lineno integer
function M.check_for_outdated_marks(filename, lineno)
  local marks = M.marks:list({ file = filename })
  -- Filter out reads from files that arent marked
  if marks == {} then
    return
  end

  local save = false
  for _, m in ipairs(marks) do
    local line = u.os.read_line_at(m.file, m.lineno)
    -- If the line has changed, update the mark
    if line ~= m.line then
      local new_lineno = vim.fn.search(m.line, "n")
      new_lineno = new_lineno or vim.fn.search(m.line, "nb")

      if new_lineno > 0 then
        local choice = 1
        if not c.config.auto_update_out_of_sync_marks then
          -- Focus the line that we are updating to
          vim.api.nvim_win_set_cursor(0, { new_lineno, 0 })
          vim.cmd("normal! zz")

          -- Prompt to confirm the update
          choice =
            vim.fn.confirm("Update mark [" .. m.desc .. "] to lineno: " .. new_lineno, "&Yes\n&No")
        end

        if choice == 1 then
          m:update_lineno(new_lineno)
          save = true
          vim.notify("Updated mark [" .. m.desc .. "] to lineno: " .. m.lineno, vim.log.levels.INFO)
        end
      end
    end
  end

  -- Save if any marks were updated
  if save then
    M.marks:save()
  end

  -- Restore the cursor position after updating marks
  vim.api.nvim_win_set_cursor(0, { lineno, 0 })
end

return M
