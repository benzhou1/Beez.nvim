local Cmd = require("beez.cmdcenter.command")
local c = require("beez.cmdcenter.config")
local db = require("beez.cmdcenter.db")
local op = require("beez.cmdcenter.outputs")
local u = require("beez.u")
local M = {
  output_split = nil,
  last_output_name = nil,
  db = db,
  op = op,
}

--- Setup the plugin
---@param opts? Beez.cmdcenter.config
function M.setup(opts)
  c.setup(opts)
  M.config = c.config

  local session = u.paths.basename(u.root.git())
  local session_dir = vim.fs.joinpath(c.config.target_dir, session)
  -- Make sure session dir exists
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, "p")
  end

  -- Make sure output dir exists
  M.output_dir = vim.fs.joinpath(session_dir, "output")
  if vim.fn.isdirectory(M.output_dir) == 0 then
    vim.fn.mkdir(M.output_dir, "p")
  end

  M.cmds_file = vim.fs.joinpath(session_dir, c.config.filename)
  -- Make sure cmds file exists
  if vim.fn.filereadable(M.cmds_file) == 0 then
    vim.fn.writefile({}, M.cmds_file)
  end

  op.setup()
  M.setup_autocmds()

  _G.Cmdcenter = M
end

--- Executes a command an makes the output available through the callback
---@param cmd Beez.cmdcenter.cmd
---@param cb fun(code: integer, output: string[])
local function execute(cmd, cb)
  -- local makeprg = vim.o.makeprg
  -- local errorformat = vim.o.errorformat
  -- local cmd = vim.split(makeprg, " ", { plain = true })

  local output = {}
  local job_opts = {
    on_stdout = function(job_id, data, event)
      for i, line in ipairs(data) do
        if i == 0 and output[#output] ~= nil then
          output[#output] = output[#output] .. line
        else
          table.insert(output, line)
        end
      end
    end,
    on_stderr = function(job_id, data, event)
      for _, line in ipairs(data) do
        table.insert(output, line)
      end
    end,
    on_exit = function(job_id, code, event)
      if code == 0 then
        vim.notify("Command successful!", vim.log.levels.INFO)
      else
        vim.notify("Command failed with exit code: " .. code, vim.log.levels.WARN)
      end

      cb(code, output)
      -- Populate the quickfix list from the output
      -- vim.fn.setqflist({}, " ", {
      --   lines = output,
      --   efm = errorformat
      -- })
      -- vim.cmd("copen")
    end,
  }

  vim.fn.jobstart(table.concat(cmd.cmd, " "), job_opts)
end

--- Run a command and then display it
---@param cmd Beez.cmdcenter.cmd
function M.run(cmd)
  vim.notify("Running command: " .. cmd.name, vim.log.levels.INFO)
  execute(cmd, function(code, output)
    op.cmd(cmd.name, cmd)
    M.display(output, cmd)
  end)
end

--- Status column to display the id for the current row
---@return string
function M.statuscolumn()
  local line = vim.fn.getline(vim.v.lnum)
  local match = line:match("^| *(%d+)") or ""
  if vim.v.lnum == 1 then
    match = "#"
  end
  local status = "%=%#Search#" .. match .. " %*"
  return status
end

--- Hook that is ran whenever the output window is displayed
---@param cmd Beez.cmdcenter.cmd
---@param winid integer
---@param bufnr integer
function M.on_output_open_hook(cmd, winid, bufnr)
  if cmd.tags ~= nil then
    for t, _ in pairs(cmd.tags) do
      local tag_hooks = c.config.hooks.tags[t]
      if tag_hooks ~= nil then
        local on_output_open_hook = tag_hooks.on_output_open
        if on_output_open_hook ~= nil then
          return on_output_open_hook(cmd, winid, bufnr)
        end
      end
    end
  end
  db.def_on_output_open_hook(cmd, winid, bufnr)
end

--- Default display function, display output in a bottom split
---@param output string[]
---@param cmd Beez.cmdcenter.cmd
function M.display(output, cmd)
  op.create(output, cmd.name)
  op.focus_or_open(cmd.name, function(winid, bufnr)
    vim.cmd.edit(op.path(cmd.name))
    M.on_output_open_hook(cmd, winid, bufnr)
  end)
end

--- Opens or focuses the the last output
function M.focus_or_open_last_output()
  op.focus_or_open(nil, function(winid, bufnr)
    M.on_output_open_hook(op.cmd(), winid, bufnr)
  end)
end

--- Get list of commands in command file
---@return Beez.cmdcenter.cmd[]
function M.list()
  local lines = vim.fn.readfile(M.cmds_file)
  local cmds = {}
  local curr_lines = {}
  for i, l in ipairs(lines) do
    table.insert(curr_lines, l)
    if l == "" or i == #lines then
      local text = table.concat(curr_lines, "\n")
      local cmd = Cmd:new(text)
      -- Requires at least a name
      if cmd.name ~= nil then
        table.insert(cmds, cmd)
      end
      curr_lines = {}
    end
  end
  return cmds
end

--- Runs the command under the current cursor
function M.run_cmd_under_cursor()
  -- Visually select the current paragraph
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("vip", true, false, true), "n", true)

  vim.schedule(function()
    local text = u.nvim.get_visual_selection()
    -- Exit visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "n", true)

    local cmd = Cmd:new(text)
    M.run(cmd)
  end)
end

--- Setup autocmds for plugin
function M.setup_autocmds()
  -- Setup keybinds on cmds file
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = M.cmds_file,
    callback = function(e)
      u.keymaps.set({
        {
          "<cr>",
          function()
            M.run_cmd_under_cursor()
          end,
          desc = "Run command under cursor",
          buffer = e.buf,
        },
      })
    end,
  })
end

--- Opens the command file
function M.edit()
  vim.cmd.edit(M.cmds_file)
end

--- Edits the current command in a floating window and reruns it
function M.edit_cmd()
  local cmd = op.cmd()
  local autocmd_group = vim.api.nvim_create_augroup("CmdcenterEditCmd", { clear = true })

  -- Create a new temporary buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, cmd.cmd)
  vim.api.nvim_buf_set_name(buf, "tempcmd")
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })

  -- Create a new floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = vim.o.columns,
    height = math.floor(vim.o.lines * 0.33),
    row = math.floor(vim.o.lines * 0.33),
    col = 0,
    style = "minimal",
  })

  --- Properly close the floating window
  local function close()
    vim.api.nvim_del_augroup_by_id(autocmd_group)
    vim.api.nvim_win_close(win, true)
  end
  local function run_cmd()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    cmd.cmd = lines
    M.run(cmd)
    vim.schedule(function()
      close()
    end)
  end

  -- Setup custom keymaps for edit command buffer
  u.keymaps.set({
    {
      "<cr>",
      run_cmd,
      buffer = buf,
    },
    {
      "q",
      function()
        op.focus_or_open()
        close()
      end,
      buffer = buf,
    },
  })

  -- Setup autocmds to handle closing the buffer
  local events = require("nui.utils.autocmd").event
  vim.api.nvim_create_autocmd({ events.BufWriteCmd }, {
    group = autocmd_group,
    pattern = ("<buffer=%s>"):format(buf),
    callback = function(event)
      run_cmd()
    end,
  })

  vim.api.nvim_create_autocmd({ events.QuitPre }, {
    group = autocmd_group,
    pattern = ("<buffer=%s>"):format(buf),
    callback = function(event)
      close()
      op.focus_or_open()
    end,
  })

  vim.api.nvim_create_autocmd({ events.WinClosed }, {
    group = autocmd_group,
    callback = function(event)
      if event.match == win then
        op.focus_or_open(M.last_output_name)
      end
    end,
  })
end

return M
