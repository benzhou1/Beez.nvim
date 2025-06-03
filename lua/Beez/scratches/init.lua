local autocmd = require("nui.utils.autocmd")
local event = require("nui.utils.autocmd").event
local Split = require("nui.split")
local group = "scratches"
local c = require("Beez.scratches.config")
local u = require("Beez.u")

local M = {
  states = { split = nil, bufs = {} },
}

--- Gets the the parent folder of the scratch file
local function get_scratch_parent()
  local root = u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
  local scratch_parent = u.paths.Path:new(c.config.scratch_dir):joinpath(root).filename
  return scratch_parent
end

--- Setup the plugin
---@param opts Beez.scratches.config
function M.setup(opts)
  c.init(opts)
  M.config = c.config
end

--- Opens a scratch file by name, creates it if it does not exist
---@param opts {name: string?, path: string?}? Open options
function M.open(opts)
  opts = opts or {}
  local name = opts.name
  local path = opts.path
  -- Use default scratch file path
  if name == nil and path == nil then
    -- Trying to create a scratch file within a scratch file act as toggle
    local curr_file = vim.api.nvim_buf_get_name(0)
    ---@diagnostic disable-next-line: param-type-mismatch
    if curr_file:startswith(c.config.scratch_dir) then
      M.close()
      return
    end

    local _, ext = u.paths.splitext(vim.api.nvim_buf_get_name(0))
    name = "scratch" .. ext
  end

  -- Use name with calculated parent folder if name is specified
  if name ~= nil then
    local parent_path = get_scratch_parent()
    local parent = u.paths.Path:new(parent_path)
    -- Create the parent folder if it does not exist
    if not parent:exists() then
      parent:mkdir()
    end
    path = parent:joinpath(name)
  end

  -- Create scratch file if it does not exist
  local scratch = u.paths.Path:new(path)
  if not scratch:exists() then
    scratch:write("", "w")
  end

  -- Create split if it does not exist
  if M.states.split == nil then
    M.states.split = Split(M.config.split_opts)
  end

  local curr_win = vim.api.nvim_get_current_win()
  if curr_win ~= M.states.split.winid then
    M.states.prev_winid = vim.api.nvim_get_current_win()
    M.states.prev_bufnr = vim.api.nvim_get_current_buf()
  end

  M.states.split:mount()
  vim.cmd("e " .. scratch.filename)

  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    -- Dont want to map to the same buffer multiple times
    if M.states.bufs[bufnr] then
      return
    end

    if c.config.keymaps.buf_keymaps then
      c.config.keymaps.buf_keymaps(bufnr)
    end

    require("lua-console.utils").attach_toggle()
    M.states.bufs[bufnr] = true
  end)

  autocmd.create_group(group, {})
  autocmd.create(event.QuitPre, {
    group = group,
    callback = function(_)
      curr_win = vim.api.nvim_get_current_win()
      if curr_win ~= M.states.split.winid then
        return
      end
      M.close()
    end,
  })
end

--- Close scratch file
function M.close()
  vim.api.nvim_set_current_win(M.states.prev_winid)
  vim.api.nvim_set_current_buf(M.states.prev_bufnr)
  M.states.split:unmount()
  M.states.split = nil
  autocmd.delete_group(group)
end

--- Copies content of existing scracth file to a new file
---@param name string Name of new scratch file
function M.copy_scratch(name)
  local curr_file = vim.api.nvim_buf_get_name(0)
  ---@diagnostic disable-next-line: param-type-mismatch
  if not curr_file:startswith(c.config.scratch_dir) then
    return
  end
  local _, ext = u.paths.splitext(curr_file)

  local lines = u.os.read_lines(curr_file)
  local new_file = u.paths.Path:new(get_scratch_parent()):joinpath(name .. ext)
  for _, line in ipairs(lines) do
    new_file:write(line, "a")
  end
  vim.notify("Created new scratch file " .. new_file.filename, vim.log.levels.INFO)
end

--- Find scratch file by name picker
---@param opts table
function M.find_picker(opts)
  local def_type = "deck"
  local ok, _ = pcall(require, "deck")
  if not ok then
    def_type = "snacks"
  end

  opts = vim.tbl_deep_extend("keep", opts or {}, { type = def_type })
  require("Beez.pickers").pick("scratches", opts)
end

return M
