local M = {}

--- Creates a command that will open specified picker in a neovide window
---@param nvim_cmd string
---@return string[]
local function mk_picker_cmd(nvim_cmd)
  local cmd = {
    "neovide",
    "--grid=160x30",
    "--fork",
    "--",
    "-c",
    nvim_cmd,
  }
  return cmd
end

--- Runs a command in a neovide terminal window
---@param cmd_to_run string[]
function M.run_cmd(cmd_to_run)
  local cmds = require("Beez.cmds")
  local cmd = {
    "neovide",
    "--grid=160x30",
    "--fork",
    "--",
    string.format('-c "term %s"', table.concat(cmd_to_run, " ")),
  }
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_term" } })
end

--- Open beez.jj
---@param path string
function M.open_beez_jj(path)
  local cmds = require("Beez.cmds")
  local cmd = {
    "neovide",
    path,
    "--maximized",
    "--fork",
    "--",
    '-c "BeezJJ"',
  }
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_diffeditor" } })
end

--- Open lazygit in separate neovide window
---@param path string
function M.open_lazygit(path)
  local cmds = require("Beez.cmds")
  local cmd = {
    "neovide",
    "--maximized",
    "--fork",
    "--",
    string.format('-c "term lazygit --path %s"', path),
  }
  cmds.run_job(cmd, { env = { AS_TERM = "true", NVIM_APPNAME = "nvim" } })
end

--- Opens a picker of projecsts which will open the selected project in lazygit
function M.open_lazygit_picker()
  local cmds = require("Beez.cmds")
  local cmd = mk_picker_cmd("PickLazyGit")
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_cmds" } })
end

--- Open a nvim term window using neohub
function M.open_term(path)
  local cmds = require("Beez.cmds")
  local cmd = {
    "neohub",
    "--name",
    "term",
    "--opts",
    "--grid 160x30",
    "--no-fork",
    "--",
    "-c",
    "term",
  }
  cmds.run_job(cmd, { cwd = path, env = { NVIM_APPNAME = "nvim_term" } })
end

--- Open project in separate neohub window
---@param name string
---@param path string
function M.open_neohub(name, path)
  local cmds = require("Beez.cmds")
  local cmd = {
    "direnv",
    "exec .",
    "neohub",
    "--name",
    name,
    "--opts",
    "--no-fork",
    --"--",
    --"--listen /tmp/nvimsocket-" .. name,
  }
  cmds.run_job(cmd, { cwd = path, env = { NVIM_APPNAME = "nvim" } })
end

--- Opens a picker of projects which will open the selected project with neohub
function M.open_neohub_picker()
  local cmds = require("Beez.cmds")
  local cmd = mk_picker_cmd("PickNeohub")
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_cmds" } })
end

--- Opens scripts picker
function M.open_scripts_picker()
  local cmds = require("Beez.cmds")
  local cmd = mk_picker_cmd("PickScripts")
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_cmds" } })
end

--- Opens recent dirs picker
function M.open_recent_dirs_picker()
  local cmds = require("Beez.cmds")
  local cmd = mk_picker_cmd("PickRecentDirs")
  cmds.run_job(cmd, { env = { NVIM_APPNAME = "nvim_cmds" } })
end

--- Opens zk note in in neovide window with nvim_zk app
function M.open_zk(path)
  local u = require("Beez.u")
  local socket = "/tmp/nvimsocket-zk"
  local cmd = {
    "neohub",
    "--name",
    "zk",
    "--opts",
    "--no-fork",
    "--grid",
    "160x30",
    "--",
    "--listen",
    socket,
  }
  u.cmds.run(cmd, nil, { cwd = u.paths.dirname(path), env = { NVIM_APPNAME = "nvim_zk" } })
end

--- Opens flotes in neovide window
function M.open_flotes(nvim_cmd)
  local u = require("Beez.u")
  local path = vim.fn.expand("~/SynologyDrive/flotes")
  local socket = "/tmp/nvimsocket-flotes"
  local cmd = {
    "neohub",
    "--name",
    "flotes",
    "--opts",
    "--no-fork",
    "--grid",
    "160x30",
    "--",
    "-c",
    nvim_cmd or "FlotesToday",
    "--listen",
    socket,
  }
  u.cmds.run(cmd, nil, { cwd = path, env = { NVIM_APPNAME = "nvim_flotes" } })
end

--- Opens minifiles in neovide window at specified path
---@param path string
function M.open_minifiles(path)
  local cmds = require("Beez.cmds")
  local cmd = {
    "neovide",
    "--fork",
    "--grid 160x30",
    "--",
    "-c",
    '\'lua vim.api.nvim_feedkeys(":e ", "n", false)\'',
  }
  cmds.run_job(cmd, { cwd = path, env = { NVIM_APPNAME = "nvim_minifiles" } })
end

return M
