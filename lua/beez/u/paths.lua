local M = {
  git_root_cache = {},
  ctags_cache = {},
  sep = package.config:sub(1, 1),
}

--- Gets the basename of a path
---@param path string
---@return string
function M.basename(path)
  if path:startswith("oil://") then
    path = string.sub(path, 7, -2)
  end
  local name = path:match("([^" .. M.sep .. "]+)$")
  return name
end

--- Get the extension of a path
---@param path string
---@return string?
function M.ext(path)
  local ext = path:match("%.([^%.]+)$")
  return ext
end

--- Gets the name of the path without extension
---@param path string
---@return string
function M.name(path)
  local name = M.basename(path)
  if not name then
    return name
  end
  name = name:match("(.+)%..+$") or name
  return name
end

--- Gets the dirname of a path
---@param path string
---@return string
function M.dirname(path)
  local Path = require("plenary.path")
  local parent = Path:new(path):parent()
  return parent.filename
end

--- Splits a file name into its name and extension
---@param path string
---@return string, string
function M.splitext(path)
  local basename = M.basename(path)
  local name = string.gsub(basename, "(.*)(%..*)", "%1")
  local ext = string.gsub(basename, "(.*)(%..*)", "%2")
  return name, ext
end

--- Returns the ctags file path for current buffer and caches it
---@param workspace? boolean
---@return string?
function M.ctags_file(workspace)
  local gt_utils = require("gentags.utils")
  local filename = vim.api.nvim_buf_get_name(0)
  if workspace then
    local key = "worksapce_" .. filename
    if M.ctags_cache[key] then
      return M.ctags_cache[key]
    end

    ---@diagnostic disable-next-line: redefined-local
    local workspace = gt_utils.get_workspace(filename)
    local tag_handle = gt_utils.get_tags_handle(workspace)
    if tag_handle == nil then
      return
    end
    local tag_file = gt_utils.get_tags_file(tag_handle)
    if tag_file ~= nil then
      M.ctags_cache[key] = tag_file
    end
    return tag_file
  end

  local key = "file_" .. filename
  if M.ctags_cache[key] then
    return M.ctags_cache[key]
  end

  local tag_handle = gt_utils.get_tags_handle(filename)
  if tag_handle == nil then
    return
  end
  local tag_file = gt_utils.get_tags_file(tag_handle)
  if tag_file ~= nil then
    M.ctags_cache[key] = tag_file
  end
  return tag_file
end

---@return string
function M.norm(path)
  if path:sub(1, 1) == "~" then
    local home = vim.uv.os_homedir()
    assert(home ~= nil, "Home directory not found")
    if home:sub(-1) == "\\" or home:sub(-1) == "/" then
      home = home:sub(1, -2)
    end
    path = home .. path:sub(2)
  end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  return path:sub(-1) == "/" and path:sub(1, -2) or path
end

return M
