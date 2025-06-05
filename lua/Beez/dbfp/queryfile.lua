local Query = require("Beez.dbfp.query")
local u = require("Beez.u")

local regex_metadata = "^--%s(.+)%s=%s(.+)$"

---@class Beez.dbfp.queryfile
---@field path Path
---@field basename string
---@field dirname string
---@field metadata table<string, string?>
---@field queries Beez.dbfp.query[]
---@field connection string?
---@field table string?
QueryFile = {}
QueryFile.__index = QueryFile

--- Instantiates a new QueryFile object
---@param path string
---@return Beez.dbfp.queryfile
function QueryFile:new(path)
  local qf = {}
  setmetatable(qf, QueryFile)

  qf.path = u.paths.Path:new(path)
  qf.basename = u.paths.basename(path)
  qf.dirname = u.paths.dirname(path)
  qf.metadata = {}
  qf.queries = {}
  qf.connection = nil
  qf.table = nil

  qf:deserialize()
  return qf
end

--- Parses the query file for metadata and queries
function QueryFile:deserialize()
  -- Ensure that the file exists
  if not self.path:exists() then
    self.path:write("", "w")
    return
  end

  local lines = u.os.read_lines(self.path.filename)
  self.metadata = {}
  self.queries = {}
  local paragraph = {}

  --- Looks for metadata in the top of the file
  local found_whitespace = false
  for i, line in ipairs(lines) do
    local k, v = nil, nil

    -- Dont continue parsing metadata after the first empty line
    if line == "" then
      found_whitespace = true
    elseif not found_whitespace then
      k, v = line:match(regex_metadata)
    end

    if k and v and k ~= "" and v ~= "" then
      self.metadata[k:lower():trimr()] = v
    elseif line ~= "" then
      table.insert(paragraph, line)
      if i == #lines then
        -- If this is the last line, we need to create a query from the paragraph
        if #paragraph > 0 then
          local query = Query:new(paragraph)
          table.insert(self.queries, query)
        end
      end
    elseif #paragraph > 0 then
      local query = Query:new(paragraph)
      table.insert(self.queries, query)
      paragraph = {}
    end
  end

  self.connection = self.metadata.connection
  self.table = self.metadata.table
end

--- Returns a table of lines representing the query file
---@return string[]
function QueryFile:serialize()
  local lines = {}
  for k, v in pairs(self.metadata) do
    table.insert(lines, string.format("-- %s = %s", k, v))
  end

  if next(lines) ~= nil then
    table.insert(lines, "")
  end

  for _, query in ipairs(self.queries) do
    u.tables.extend(lines, query:serialize())
    table.insert(lines, "")
  end
  return lines
end

--- Sets the metadata connection for the query file
---@param connection string?
function QueryFile:set_connection(connection)
  self.connection = connection
  self.metadata.connection = connection
end

--- Sets the table connection for the query file
---@param table string?
function QueryFile:set_table(table)
  self.table = table
  self.metadata.table = table
end

--- Overwrites the query file
function QueryFile:save()
  local lines = self:serialize()
  local txt = table.concat(lines, "\n")
  self.path:write(txt, "w")
end

--- Renames the query file
---@param new_name string
function QueryFile:rename(new_name)
  if new_name == nil or new_name == "" then
    return
  end

  local new_path = u.paths.Path:new(self.dirname, new_name .. ".sql")
  self.path:rename({ new_name = new_path.filename })
  self.basename = u.paths.basename(new_path.filename)
  self.path = new_path
end

--- Removes the query file from the filesystem
function QueryFile:delete()
  self.path:rm()
end

return QueryFile
