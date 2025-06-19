local Gmarks = require("Beez.codemarks.gmarks")
local Marks = require("Beez.codemarks.marks")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")

---@class Beez.codemarks
---@field gm Beez.codemarks
---@field config Beez.codemarks.config
---@field marks_file Path
---@field gmarks_file Path
---@field gmarks Beez.codemarks.gmarks
local M = {}

--- Setup the plugin
---@param opts Beez.codemarks.config
function M.setup(opts)
  c.init(opts)
  local marks_dir = u.paths.Path:new(opts.marks_dir)
  M.gmarks_file = marks_dir:joinpath("codemarks.txt")
  M.marks_file = marks_dir:joinpath("marks.txt")
  -- Marks sure the parent exists
  if not marks_dir:exists() then
    marks_dir:mkdir()
  end

  -- Marks sure the marks file exists
  if not M.gmarks_file:exists() then
    M.gmarks_file:write("", "w")
  end
  if not M.marks_file:exists() then
    M.marks_file:write("", "w")
  end

  -- Load the marks file
  M.gmarks = Gmarks:new({ marks_file = M.gmarks_file.filename })
  M.marks = Marks:new({ marks_file = M.marks_file.filename })
end

--- Edits the raw marks file
function M.edit_marks()
  vim.cmd("edit " .. M.marks_file.filename)
end

--- Edits the raw global marks file
function M.edit_gmarks()
  vim.cmd("edit " .. M.gmarks_file.filename)
end

--- Add a new code mark
function M.add_global()
  vim.ui.input({ prompt = "Describe the mark" }, function(res)
    if res == nil then
      return
    end
    M.gmarks:add(res)
  end)
end

--- Add a new mark
function M.toggle()
  M.marks:toggle()
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

--- Picker for codemarks
---@param opts Beez.pick.opts?
function M.find_marks_picker(opts)
  local def_type = "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  require("Beez.pickers").pick("marks", opts)
end

--- Checks current file for any outdated marks
---@param filename string
---@param lineno integer
function M.check_for_outdated_marks(filename, lineno)
  local marks = M.gmarks:list({ file = filename })
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
    M.gmarks:save()
  end

  -- Restore the cursor position after updating marks
  vim.api.nvim_win_set_cursor(0, { lineno, 0 })
end

return M
