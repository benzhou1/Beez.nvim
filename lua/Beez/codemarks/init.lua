local Stacks = require("Beez.codemarks.stacks")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")

---@class Beez.codemarks
---@field stacks Beez.codemarks.stacks
---@field config Beez.codemarks.config
---@field stacks_file Path
---@field curr_buf? number
local M = {}

--- Setup the plugin
---@param opts Beez.codemarks.config
function M.setup(opts)
  c.init(opts)
  local marks_dir = u.paths.Path:new(opts.marks_dir)
  -- Marks sure the parent exists
  if not marks_dir:exists() then
    marks_dir:mkdir()
  end

  -- Marks sure the stacks file exists
  M.stacks_file = marks_dir:joinpath("stacks.json")
  if not M.stacks_file:exists() then
    M.stacks_file:write("{}", "w")
  end

  -- Load the stacks file
  M.stacks = Stacks:new({ stacks_file = M.stacks_file.filename })
end

--- Edits the stacks file
function M.edit_stacks()
  vim.cmd("edit " .. M.stacks_file.filename)
end

--- Creates a new stack with the given name
function M.create_stack()
  vim.ui.input({ prompt = "Give your new stack a name: " }, function(res)
    if res == nil then
      return
    end
    M.stacks:create_stack(res)
  end)
end

--- Add a new global code mark
function M.add_global_mark()
  M.stacks:add_global_mark()
end

--- Toggles a new mark
---@param opts? {clear?: boolean}
function M.add_mark(opts)
  opts = opts or {}
  if opts.clear then
    M.stacks:clear_marks()
  end
  M.stacks:add_mark()
end

--- Clear all marks in the current stack
function M.clear_marks()
  M.stacks:clear_marks()
end

--- Returns a list of global marks
---@param opts? {root?: string, all_stacks?: boolean}
---@return Beez.codemarks.gmark[]
function M.list_gmarks(opts)
  opts = opts or {}
  local gmarks = {}
  local stacks = { M.stacks:get() }
  if opts.all_stacks == true then
    local all_stacks = M.stacks:list(opts)
    for _, a in ipairs(all_stacks) do
      table.insert(stacks, a)
    end
  end

  local unique = {}
  for _, s in ipairs(stacks) do
    if not unique[s.name] then
      local marks = s.gmarks:list()
      for _, m in ipairs(marks) do
        table.insert(gmarks, m)
        m.stack = s.name
      end
    else
      unique[s.name] = true
    end
  end
  return gmarks
end

--- Returns a list of global marks
---@param opts? {}
---@return Beez.codemarks.mark[]
function M.list_marks(opts)
  opts = opts or {}
  local stack = M.stacks:get()
  if stack == nil then
    return {}
  end
  local marks = stack.marks:list()
  return marks
end

--- Navigates to the last mark location in the stack and remove the mark
function M.pop_stack()
  local stack = M.stacks:get()
  if stack == nil then
    vim.notify("No stack to pop", vim.log.levels.WARN)
    return
  end

  local mark = stack.marks:pop()
  if mark then
    vim.cmd("e " .. mark.file)
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    M.stacks:save()
  end
end

--- Undo the last pop operation in the stack
function M.undo_pop()
  local stack = M.stacks:get()
  if stack == nil then
    vim.notify("No stack to undo pop", vim.log.levels.WARN)
    return
  end

  local mark = stack.marks:undo()
  if mark then
    vim.cmd("e " .. mark.file)
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    M.stacks:save()
  end
end

--- Picker for global codemarks
---@param opts Beez.pick.opts?
function M.picker_global_marks(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.global_marks", opts)
end

--- Picker for codemarks
---@param opts Beez.pick.opts?
function M.picker_marks(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.marks", opts)
end

--- Picker for stacks
---@param opts Beez.pick.opts?
function M.picker_stacks(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.stacks", opts)
end

--- Checks current file for any outdated marks
---@param filename string
---@param lineno integer
function M.check_for_outdated_marks(filename, lineno)
  local stacks = M.stacks:list()
  -- Filter out reads from files that arent marked
  if stacks == {} then
    return
  end

  local save = false
  for _, s in ipairs(stacks) do
    local gmarks = s.gmarks:list({ file = filename })
    for _, m in ipairs(gmarks) do
      local line = u.os.read_line_at(m.file, m.lineno)
      -- If the line has changed, update the mark
      if line ~= m.line then
        -- Look for the new line number
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
            m:set_lineno(new_lineno)
            save = true
            vim.notify("Updated mark [" .. m.desc .. "] to lineno: " .. m.lineno, vim.log.levels.INFO)
          end
        end
      end
    end
  end

  -- Save if any marks were updated
  if save then
    M.stacks:save()
  end

  -- Restore the cursor position after updating marks
  pcall(vim.api.nvim_win_set_cursor, 0, { lineno, 0 })
end

return M
