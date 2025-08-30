local Gmarks = require("Beez.codemarks.gmarks")
local Marks = require("Beez.codemarks.marks")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")

---@class Beez.codemarks.data
---@field gmarks Beez.codemarks.gmarks[]
---@field marks Beez.codemarks.marks[]

---@class Beez.codemarks
---@field config Beez.codemarks.config
---@field file_path Path
---@field curr_buf? number
---@field _gmarks Beez.codemarks.gmarks
---@field _marks Beez.codemarks.marks
local M = { gmarks = {}, marks = {} }

--- Setup autocmds for the plugin
local function init_autocmds()
  -- Autocmd to check for outdated marks when a file is written
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*",
    callback = function(event)
      M.check_for_outdated_marks(event.file)
    end,
  })
end

--- Setup the plugin
---@param opts Beez.codemarks.config
function M.setup(opts)
  c.init(opts)
  local marks_dir = u.paths.Path:new(opts.marks_dir)
  -- Marks sure the parent exists
  if not marks_dir:exists() then
    marks_dir:mkdir()
  end

  -- Make sure the codemarks file exists
  M.file_path = marks_dir:joinpath("codemarks.json")
  if not M.file_path:exists() then
    M.file_path:write("{}", "w")
  end

  -- load codemarks file
  local file = io.open(M.file_path.filename, "r")
  if file then
    local lines = file:read("*a")
    ---@type Beez.codemarks.data
    local data = vim.fn.json_decode(lines)
    M._gmarks = Gmarks:new(data.gmarks or {})
    M._marks = Marks:new(data.marks or {})
    file:close()
  else
    error("Could not open file: " .. M.file_path.filename)
  end

  -- Setup autocmds
  init_autocmds()
end

--- Edits the codemarks file
function M.edit_file()
  vim.cmd("edit " .. M.file_path.filename)
end

--- Add a new global code mark
function M.gmarks.add()
  vim.ui.input({ prompt = "Describe the mark: " }, function(res)
    if res == nil then
      return
    end
    M._gmarks:add(res)
    M.save()
  end)
end

--- Returns a list of global marks
---@param opts? {root?: string}
---@return Beez.codemarks.gmark[]
function M.gmarks.list(opts)
  opts = opts or {}
  local gmarks = M._gmarks:list(opts)
  return gmarks
end

--- Update a global mark
---@param data Beez.codemarks.gmarkdata
---@param updates {desc?: string, lineno?: integer, line?: string}
---@param opts? {save?: boolean}
function M.gmarks.update(data, updates, opts)
  opts = opts or {}
  local updated = M._gmarks:update(data, updates)
  return updated
end

--- Delete a global mark
---@param data Beez.codemarks.gmarkdata
---@param opts? {save?: boolean}
function M.gmarks.del(data, opts)
  opts = opts or {}
  M._gmarks:del(data)
end

--- Picker for global codemarks
---@param opts Beez.pick.opts?
function M.gmarks.pick(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.global_marks", opts)
end

--- Picker for choosing a global mark to update to the current line
---@param opts Beez.pick.opts?
function M.gmarks.pick_update_line(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.global_marks_update_line", opts)
end

--- Toggles mark on current line
function M.marks.toggle()
  M._marks:toggle()
  M.save()
end

--- Navigate to the next mark
function M.marks.next()
  M._marks:next()
end

--- Undo the last popped mark
function M.marks.prev()
  M._marks:prev()
end

--- Clear all marks
function M.marks.clear()
  M._marks:clear()
  M.save()
end

--- Returns a list of marks
---@param opts? {}
---@return Beez.codemarks.mark[]
function M.marks.list(opts)
  opts = opts or {}
  local marks = M._marks:list()
  return marks
end

--- Picker for codemarks
---@param opts Beez.pick.opts?
function M.marks.pick(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.marks", opts)
end

--- Checks whether a mark needs
---@param path string
---@param lineno integer
---@param old_line string
---@param save fun(integer)
local function check_for_outdated_marks(path, lineno, old_line, save)
  local line = u.os.read_line_at(path, lineno)
  -- If the line has changed, update the mark
  if line ~= old_line then
    -- Look for the new line number
    local new_lineno = vim.fn.search(old_line, "n")
    new_lineno = new_lineno or vim.fn.search(old_line, "nb")
    if new_lineno > 0 then
      local choice = 1
      if not c.config.auto_update_out_of_sync_marks then
        -- Focus the line that we are updating to
        vim.api.nvim_win_set_cursor(0, { new_lineno, 0 })
        vim.cmd("normal! zz")

        -- Prompt to confirm the update
        choice = vim.fn.confirm("Update mark to lineno: " .. new_lineno, "&Yes\n&No")
      end

      if choice == 1 then
        save(new_lineno)
      end
    end
  end
end

--- Checks current file for any outdated marks
---@param filename string
function M.check_for_outdated_marks(filename)
  local save = false
  -- Filter out reads from files that arent marked
  local gmarks = M._gmarks:list({ file = filename })
  for _, m in ipairs(gmarks) do
    check_for_outdated_marks(m.file, m.lineno, m.line, function(new_lineno)
      M.gmarks.update(m:serialize(), { lineno = new_lineno }, { save = false })
      save = true
      vim.notify("Updated mark [" .. m.desc .. "] to lineno: " .. new_lineno, vim.log.levels.INFO)
    end)
  end

  local marks = M._marks:list({ file = filename })
  for _, m in ipairs(marks) do
    check_for_outdated_marks(m.file, m.lineno, m.line, function(new_lineno)
      m:update({ lineno = new_lineno })
      save = true
      vim.notify(
        "Updated mark at " .. m.file .. ":" .. m.lineno .. " to lineno: " .. new_lineno,
        vim.log.levels.INFO
      )
    end)
  end

  -- Save if any marks were updated
  if save then
    M.save()
  end
end

--- Persists all marks to a file
function M.save()
  ---@type Beez.codemarks.data
  local data = {
    gmarks = M._gmarks:serialize(),
    marks = M._marks:serialize(),
  }
  local json_string = vim.fn.json_encode(data)
  local file = io.open(M.file_path.filename, "w")
  assert(file, "Could not open file for writing: " .. M.file_path.filename)
  file:write(json_string)
  file:close()
end

return M
