local M = {
  outputs = {},
  split = nil,
  last_output = nil,
}

function M.setup()
  local Split = require("nui.split")
  M.split = Split({
    relative = "win",
    position = "bottom",
    size = "33%",
  })
end

function M.path(name)
  local cc = require("Beez.cmdcenter")
  local output_file = vim.fs.joinpath(cc.output_dir, name)
  return output_file
end

function M.create(output, name)
  M.outputs[name] = M.outputs[name] or {}
  local path = M.path(name)
  vim.fn.writefile(output, path)
  return path
end

function M.winid()
  return M.split.winid
end

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

function M.focus_or_open(name, on_open)
  name = name or M.last_output
  if name == nil then
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
