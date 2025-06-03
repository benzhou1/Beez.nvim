local c = require("Beez.dbfp.config")

---@class Beez.dbfp.connections
---@field path Path
---@field cons table<string, string>
---@field active string?
Connections = {}
Connections.__index = Connections

--- Instantiates a new Connections object
---@param opts table?
---@return Beez.dbfp.connections
function Connections:new(opts)
  opts = opts or {}
  local u = require("Beez.u")
  local con = {}
  setmetatable(con, Connections)

  con.path = u.paths.Path:new(c.config.dbfp_path):joinpath("connections.json")
  con.cons = {}
  con.active = nil

  if not con.path:exists() then
    con:save()
  else
    con.cons = vim.fn.json_decode(con.path:read())
  end

  return con
end

--- Save a new connection string
---@param name string
---@param conn_str string
function Connections:add(name, conn_str)
  if self.cons[name] then
    return vim.notify("Connection with name '" .. name .. "' already exists.", vim.log.levels.WARN)
  end
  self.cons[name] = conn_str
  self:save()
end

--- Persists the connections to the JSON file
function Connections:save()
  self.path:write(vim.fn.json_encode(self.cons), "w")
end

--- Sets the active connection
---@param name string
function Connections:set_active(name)
  if not self.cons[name] then
    return vim.notify("Connection '" .. name .. "' does not exist.", vim.log.levels.ERROR)
  end
  self.active = name
end

--- Gets the active connection string
---@return string?
function Connections:get_active()
  if not self.active then
    return
  end
  return self.cons[self.active]
end

--- Gets a connection string by name
---@param name string
---@return string?
function Connections:get(name)
  return self.cons[name]
end

--- Renames a connection string
---@param con_str string
---@param new_name string
function Connections:rename(con_str, new_name)
  local old_name = nil
  for k, v in pairs(self.cons) do
    if v == con_str then
      old_name = k
      break
    end
  end

  if not old_name then
    return vim.notify("Connection string '" .. con_str .. "' does not exist.", vim.log.levels.ERROR)
  end

  if self.active == old_name then
    self.active = new_name
  end

  self.cons[new_name] = con_str
  self.cons[old_name] = nil
  self:save()
end

return Connections
