local QueryFile = require("Beez.dbfp.queryfile")
local c = require("Beez.dbfp.config")
local u = require("Beez.u")
local group = "Beez.dbfp.queryfiles"

---@class Beez.dbfp.queryfiles
---@field files table<string, Beez.dbfp.queryfile>
---@field con_to_files table<string, string[]>
---@field table_to_files table<string, string[]>
---@field path Path
QueryFiles = {}
QueryFiles.__index = QueryFiles

--- Instantiates a new QueryFiles object
---@return Beez.dbfp.queryfiles
function QueryFiles:new()
  local qf = {}
  setmetatable(qf, QueryFiles)

  qf.path = u.paths.Path:new(c.config.dbfp_path):joinpath("queryfiles")
  qf.files = {}
  qf.con_to_files = {}
  qf.table_to_files = {}

  qf:deserialize()
  return qf
end

--- Initializes the autocmds for query files
function QueryFiles:init_autocmds()
  vim.api.nvim_create_augroup(group, { clear = true })

  --- Autocmd to reparse the query files when they are written
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { self.path.filename .. "/*.sql" },
    callback = function(opts)
      local filepath = vim.api.nvim_buf_get_name(opts.buf)
      local qf = self:get(filepath)
      if not qf then
        return
      end

      local old_connection = qf.connection
      local old_table = qf.table
      qf:deserialize()

      -- Update files maps if connection changes
      if qf.connection ~= old_connection then
        if old_connection then
          for i, v in ipairs(self.con_to_files[old_connection]) do
            if v == qf.path.filename then
              table.remove(self.con_to_files[old_connection], i)
              break
            end
          end
        end
        self.con_to_files[qf.connection] = self.con_to_files[qf.connection] or {}
        table.insert(self.con_to_files[qf.connection], qf.path.filename)
      end
      -- Update files maps if table changes
      if qf.table ~= old_table then
        for i, v in ipairs(self.table_to_files[old_table]) do
          if v == qf.path.filename then
            table.remove(self.table_to_files[old_table], i)
            break
          end
        end
        self.table_to_files[qf.table] = self.table_to_files[qf.table] or {}
        table.insert(self.table_to_files[qf.table], qf.path.filename)
      end
    end,
  })
end

--- Cleans up the autocmds for query files
function QueryFiles:del_autocmds()
  vim.api.nvim_del_augroup_by_name(group)
end

--- Parses the query files for the connection
function QueryFiles:deserialize()
  local root = c.config.dbfp_path
  self.files = {}

  --- Walk through the directory and find all .sql files
  local stack = { root }
  while #stack > 0 do
    local dir = table.remove(stack)
    for _, item in ipairs(vim.fn.readdir(dir)) do
      local path = dir .. u.paths.sep .. item
      if vim.fn.isdirectory(path) == 1 then
        table.insert(stack, path)
      elseif item:match("%.sql$") then
        local qf = QueryFile:new(path)
        self.files[path] = qf

        if qf.connection then
          self.con_to_files[qf.connection] = self.con_to_files[qf.connection] or {}
          table.insert(self.con_to_files[qf.connection], path)
        end
        if qf.table then
          self.table_to_files[qf.table] = self.table_to_files[qf.table] or {}
          table.insert(self.table_to_files[qf.table], path)
        end
      end
    end
  end
end

--- Gets a query file by its path
---@param path string
---@return Beez.dbfp.queryfile?
function QueryFiles:get(path)
  local qf = self.files[path]
  return qf
end

--- Returns a list of query files
---@param opts? {connection?: string}
---@return Beez.dbfp.queryfile[]
function QueryFiles:list(opts)
  opts = opts or {}
  local queryfiles = {}
  local paths = u.tables.keys(self.files)
  if opts.connection then
    paths = self.con_to_files[opts.connection] or {}
  end

  for _, path in ipairs(paths) do
    local qf = self.files[path]
    table.insert(queryfiles, qf)
  end
  return queryfiles
end

--- Adds a new query file to the connection
---@param name string
---@param opts? {connection: string?, table: string?}
---@return Beez.dbfp.queryfile
function QueryFiles:add(name, opts)
  opts = opts or {}
  --- Ensure the queryfiles directory exists
  if not self.path:exists() then
    self.path:mkdir()
  end

  local path = self.path:joinpath(name .. ".sql")
  local qf = QueryFile:new(path.filename)

  if opts.connection then
    qf:set_connection(opts.connection)
  end
  if opts.table then
    qf:set_table(opts.table)
  end
  qf:save()

  self.files[path.filename] = qf
  if opts.connection then
    self.con_to_files[opts.connection] = self.con_to_files[opts.connection] or {}
    table.insert(self.con_to_files[opts.connection], path.filename)
  end
  if opts.table then
    self.table_to_files[opts.table] = self.table_to_files[opts.table] or {}
    table.insert(self.table_to_files[opts.table], path.filename)
  end
  return qf
end

--- Remove metadata from each query file for a connection
---@param connection string
function QueryFiles:remove_connection(connection)
  local paths = self.con_to_files[connection]
  if not paths then
    return
  end

  for _, path in ipairs(paths) do
    local qf = self.files[path]
    if qf then
      qf:set_connection(nil)
      qf:set_table(nil)
      qf:save()
    end
  end
  self.con_to_files[connection] = nil
end

--- Renames the connection metadata for each query file for a connection
---@param connection string
---@param new_connection string
function QueryFiles:rename_connection(connection, new_connection)
  local paths = self.con_to_files[connection]
  if not paths then
    return
  end

  for _, path in ipairs(paths) do
    local qf = self.files[path]
    if qf then
      qf:set_connection(new_connection)
      qf:save()
    end
  end
  self.con_to_files[new_connection] = self.con_to_files[connection]
  self.con_to_files[connection] = nil
end

--- Removes a query file from the list
---@param path string
function QueryFiles:delete_queryfile(path)
  local qf = self.files[path]
  if not qf then
    return
  end

  qf:delete()
  if qf.connection then
    u.tables.remove(self.con_to_files[qf.connection], path)
  end
  if qf.table then
    u.tables.remove(self.table_to_files[qf.table], path)
  end

  self.files[path] = nil
end

--- Sets the connection for a query file
---@param path string
---@param connection string
function QueryFiles:set_queryfile_connection(path, connection)
  local qf = self.files[path]
  if not qf then
    return
  end

  local old_connection = qf.connection
  if old_connection == connection then
    return
  end

  qf:set_connection(connection)
  qf:save()

  self.con_to_files[connection] = self.con_to_files[connection] or {}
  table.insert(self.con_to_files[connection], path)
  if old_connection then
    u.tables.remove(self.con_to_files[old_connection], path)
  end
end

return QueryFiles
