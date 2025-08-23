local c = require("Beez.bufswitcher.config")
local u = require("Beez.u")

---@class Beez.bufswitcher.recentlist
---@field file_path string
---@field enabled boolean
---@field paths string[]
Recentlist = {}
Recentlist.__index = Recentlist

--- Instaniate a new RecentList
---@param dir_path string
---@return Beez.bufswitcher.recentlist
function Recentlist:new(dir_path)
  local r = {}
  setmetatable(r, Recentlist)

  r.file_path = vim.fs.joinpath(dir_path, "recent_paths.txt")
  r.paths = {}
  r.enabled = true
  return r
end

--- Disable recent files tracking
function Recentlist:disable()
  self.enabled = false
end

--- Enable recent files tracking
function Recentlist:enable()
  self.enabled = true
end

--- Loads recent paths from file
function Recentlist:load()
  if not self.enabled then
    return
  end
  if vim.fn.filereadable(self.file_path) == 0 then
    vim.fn.writefile({}, self.file_path)
  end
  self.paths = vim.fn.readfile(self.file_path)
end

--- Saves recent paths to file up to a configured limit
function Recentlist:save()
  if not self.enabled then
    return
  end
  -- Clean up old paths since they are no longer recent
  local paths = u.tables.slice(self.paths, 1, c.config.recent_list_limit)
  vim.fn.writefile(paths, self.file_path)
end

--- Adds a file to recent list
---@param path string
function Recentlist:add(path)
  if not self.enabled then
    return
  end
  if path == "" then
    return
  end
  path = vim.fs.normalize(path)
  local exists = vim.fn.filereadable(path) == 1
  if not exists then
    return
  end

  self:remove(path)
  table.insert(self.paths, 1, path)
end

--- Remove a file from recent list
---@param path string
function Recentlist:remove(path)
  if not self.enabled then
    return
  end
  u.tables.remove(self.paths, function(p)
    return p == path
  end)
end

--- Returns the recent files list
---@param opts? {}
---@return string[]
function Recentlist:list(opts)
  opts = opts or {}
  local paths = self.paths
  return paths
end

return Recentlist
