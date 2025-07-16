local Stacks = require("Beez.codemarks.stacks")
local c = require("Beez.codemarks.config")
local u = require("Beez.u")

---@class Beez.codemarks
---@field config Beez.codemarks.config
---@field stacks_file Path
---@field curr_buf? number
---@field _stacks Beez.codemarks.stacks
local M = { stacks = {}, gmarks = {}, marks = {} }

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

  -- Marks sure the stacks file exists
  M.stacks_file = marks_dir:joinpath("stacks.json")
  if not M.stacks_file:exists() then
    M.stacks_file:write("{}", "w")
  end

  -- Load the stacks file
  M._stacks = Stacks:new({ stacks_file = M.stacks_file.filename })
  -- Setup autocmds
  init_autocmds()
end

--- Edits the stacks file
function M.stacks.edit_file()
  vim.cmd("edit " .. M.stacks_file.filename)
end

--- Prompts to create a new stack
function M.stacks.add()
  vim.ui.input({ prompt = "Give your new stack a name: " }, function(res)
    if res == nil then
      return
    end
    M.stacks.create_stack(res)
  end)
end

--- Creates a new stack with the given name
---@param name string
---@param opts? {save?: boolean, set_active?: boolean}
function M.stacks.create_stack(name, opts)
  M._stacks:create_stack(name, opts)
end

--- Sets the active stack
---@param stack_name string
---@param opts? { hook?: boolean }
function M.stacks.set_active(stack_name, opts)
  M._stacks:set_active_stack(stack_name, opts)
end

--- Returns specific stack or the current one
---@param opts? { name: string? }
---@return Beez.codemarks.stack?
function M.stacks.get(opts)
  opts = opts or {}
  return M._stacks:get(opts)
end

--- Returns a list of stacks
---@param opts? { root?: boolean }
---@return Beez.codemarks.stack[]
function M.stacks.list(opts)
  opts = opts or {}
  return M._stacks:list(opts)
end

--- Updates the stack with the given data
---@param data Beez.codemarks.stackdata
---@param updates {name?: string}
---@param opts? {save?: boolean}
---@return boolean
function M.stacks.update(data, updates, opts)
  local updated = M._stacks:update_stack(data, updates, opts)
  return updated
end

--- Deletes a stack
---@param data Beez.codemarks.stackdata
---@param opts? {save?: boolean}
function M.stacks.del(data, opts)
  opts = opts or {}
  local stack = M._stacks:get({ name = data.stack })
  if stack == nil then
    return
  end

  M._stacks:del_stack(data, opts)
end

--- Navigates to the last mark location in the stack and remove the mark
function M.stacks.pop()
  local stack = M._stacks:get()
  if stack == nil then
    vim.notify("No stack to pop", vim.log.levels.WARN)
    return
  end

  local mark = stack.marks:pop()
  if mark then
    vim.cmd("e " .. mark.file)
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    M._stacks:save()
  end
end

--- Undo the last pop operation in the stack
function M.stacks.undo()
  local stack = M._stacks:get()
  if stack == nil then
    vim.notify("No stack to undo pop", vim.log.levels.WARN)
    return
  end

  local mark = stack.marks:undo()
  if mark then
    vim.cmd("e " .. mark.file)
    vim.api.nvim_win_set_cursor(0, { mark.lineno, mark.col })
    M._stacks:save()
  end
end

--- Picker for stacks
---@param opts Beez.pick.opts?
function M.stacks.pick(opts)
  opts = opts or {}
  local def_type = opts.type or "deck"
  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  M.curr_buf = vim.api.nvim_get_current_buf()
  require("Beez.pickers").pick("codemarks.stacks", opts)
end

--- Add a new global code mark
function M.gmarks.add()
  M._stacks:add_global_mark()
end

--- Returns a list of global marks
---@param opts? {root?: boolean, all_stacks?: boolean}
---@return Beez.codemarks.gmark[]
function M.gmarks.list(opts)
  opts = opts or {}
  local gmarks = {}
  local stacks = { M.stacks:get() }
  if opts.all_stacks == true then
    local all_stacks = M._stacks:list(opts)
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

--- Update a global mark
---@param data Beez.codemarks.gmarkdataout
---@param updates {desc?: string, lineno?: integer}
---@param opts? {save?: boolean}
function M.gmarks.update(data, updates, opts)
  opts = opts or {}
  local stack = M._stacks:get({ name = data.stack })
  if stack == nil then
    return false
  end

  local updated = stack.gmarks:update(data, updates)
  if opts.save ~= false then
    M._stacks:save()
  end
  return updated
end

--- Delete a global mark
---@param data Beez.codemarks.gmarkdataout
---@param opts? {save?: boolean}
function M.gmarks.del(data, opts)
  opts = opts or {}
  local stack = M._stacks:get({ name = data.stack })
  if stack == nil then
    return
  end

  stack.gmarks:del(data)
  if opts.save ~= false then
    M._stacks:save()
  end
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

--- Toggles a new mark
---@param opts? {clear?: boolean}
function M.marks.add(opts)
  opts = opts or {}
  if opts.clear then
    M._stacks:clear_marks()
  end
  M._stacks:add_mark()
end

--- Clear all marks in the current stack
function M.marks.clear()
  M._stacks:clear_marks()
end

--- Returns a list of marks
---@param opts? {}
---@return Beez.codemarks.mark[]
function M.marks.list(opts)
  opts = opts or {}
  local stack = M._stacks:get()
  if stack == nil then
    return {}
  end
  local marks = stack.marks:list()
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

--- Checks current file for any outdated marks
---@param filename string
function M.check_for_outdated_marks(filename)
  local stacks = M.stacks:list()
  if stacks == {} then
    return
  end

  local save = false
  for _, s in ipairs(stacks) do
    -- Filter out reads from files that arent marked
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
            M.gmarks.update(m:serialize(), { lineno = new_lineno }, { save = false })
            save = true
            vim.notify("Updated mark [" .. m.desc .. "] to lineno: " .. new_lineno, vim.log.levels.INFO)
          end
        end
      end
    end
  end

  -- Save if any marks were updated
  if save then
    M._stacks:save()
  end
end

--- Save to stacks file
function M.save()
  M._stacks:save()
end

return M
