local M = {
  outputs = {},
  split = nil,
  last_output = "",
}

--- Setup the output module
function M.setup()
  local Split = require("nui.split")
  M.split = Split({
    relative = "win",
    position = "bottom",
    size = "33%",
  })
end

--- Gets the output file path of command by name
---@param name string
---@return string
function M.path(name)
  local cc = require("Beez.cmdcenter")
  local output_file = vim.fs.joinpath(cc.output_dir, name)
  return output_file
end

--- Creates a new output file for command by name
---@param output string
---@param name string
---@return string
function M.create(output, name)
  M.outputs[name] = M.outputs[name] or {}
  local path = M.path(name)
  vim.fn.writefile(output, path)
  return path
end

--- Gets the current winid for output window
---@return integer
function M.winid()
  return M.split.winid
end

--- Gets or cache the bufnr for output of command by name
---@param name? string
---@param bufnr? integer
function M.bufnr(name, bufnr)
  name = name or M.last_output
  if bufnr ~= nil then
    M.outputs[name] = M.outputs[name] or {}
    M.outputs[name].bufnr = bufnr
    return bufnr
  end
  if M.outputs[name] then
    return M.outputs[name].bufnr
  end
end

--- Gets or sets the header row for db output by name
---@param name? string
---@param header? string
---@return string
function M.header(name, header)
  name = name or M.last_output
  if header ~= nil then
    M.outputs[name] = M.outputs[name] or {}
    M.outputs[name].header = header
    return header
  end
  local data = M.outputs[name]
  return data.header
end

--- Gets or sets the headers for db output by name
---@param name? string
---@param headers? string[]
---@return string[]
function M.headers(name, headers)
  name = name or M.last_output
  if headers ~= nil then
    M.outputs[name] = M.outputs[name] or {}
    M.outputs[name].headers = headers
    return headers
  end
  local data = M.outputs[name]
  return data.headers
end

--- Gets or sets the header positions of db output by name
---@param name? string
---@param header_pos? integer[]
---@return integer[]
function M.header_pos(name, header_pos)
  name = name or M.last_output
  if header_pos ~= nil then
    M.outputs[name] = M.outputs[name] or {}
    M.outputs[name].header_pos = header_pos
    return header_pos
  end
  local data = M.outputs[name]
  return data.header_pos
end

--- Gets or sets the command for output by name
---@param name? string
---@param cmd? Beez.cmdcenter.cmd
---@return Beez.cmdcenter.cmd
function M.cmd(name, cmd)
  name = name or M.last_output
  if cmd ~= nil then
    M.outputs[name] = M.outputs[name] or {}
    M.outputs[name].cmd = cmd
    return cmd
  end

  local data = M.outputs[name]
  return data.cmd
end

--- Focus or opens the output window by command name
---@param name? string
---@param on_open? fun(winid: integer, bufnr: integer)
function M.focus_or_open(name, on_open)
  name = name or M.last_output
  if name == nil or name == "" then
    return
  end

  M.split:mount()
  vim.api.nvim_set_current_win(M.split.winid)

  vim.schedule(function()
    local curr_bufnr = vim.api.nvim_get_current_buf()
    local bufnr = M.bufnr(name)
    if curr_bufnr ~= bufnr then
      vim.cmd.edit(M.path(name))
    end
    M.last_output = name
    vim.schedule(function()
      if bufnr == nil then
        bufnr = vim.api.nvim_get_current_buf()
        M.bufnr(name, bufnr)
      end

      vim.bo[bufnr].filetype = "cmdcenter"
      if on_open ~= nil then
        on_open(M.split.winid, bufnr)
      end
    end)
  end)
end

--- Close the output window
function M.close()
  local cs = require("Beez.codestacks")
  M.split:unmount()
  for name, data in pairs(M.outputs) do
    if data.bufnr ~= nil and vim.api.nvim_buf_is_valid(data.bufnr) then
      vim.api.nvim_buf_delete(data.bufnr, { force = true })
      cs.recentfiles.remove(M.path(name))
    end
    if M.outputs[name] then
      M.outputs[name].bufnr = nil
    end
  end
end

return M
