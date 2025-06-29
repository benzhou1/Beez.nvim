local u = require("Beez.u")
local uv = vim.uv
local Mark = require("Beez.codemarks.mark")

--- Unique key for the mark
---@param data Beez.codemarks.markdata
---@return string
local function get_key(data)
  return data.file .. ":" .. data.lineno
end

---@class Beez.codemarks.marks
---@field opts table
---@field marks table<string, Beez.codemarks.mark>
Marks = {}
Marks.__index = Marks

---@class codemarks.marks.opts
---@field marks_file string

--- Creates a new instance of Marks
---@param opts codemarks.marks.opts
---@return Beez.codemarks.marks
function Marks:new(opts)
  local c = {}
  setmetatable(c, Marks)
  c.opts = opts

  -- load marks file
  c.marks = {}
  local file = io.open(opts.marks_file, "r")
  if file then
    for line in file:lines() do
      local mark = Mark.from_line(line)
      c.marks[get_key(mark.data)] = mark
    end
    file:close()
  else
    error("Could not open file: " .. opts.marks_file)
  end
  return c
end

--- Returns a mark based on data
---@param data Beez.codemarks.markdata
---@return Beez.codemarks.mark?
function Marks:get(data)
  local key = get_key(data)
  return self.marks[key]
end

--- Filter marks based on options
---@param opts? {file: string?}
---@return table<Beez.codemarks.mark>
function Marks:list(opts)
  opts = opts or {}
  local marks = {}
  for _, mark in pairs(self.marks) do
    if opts.file then
      if mark.file == opts.file then
        table.insert(marks, mark)
      end
    else
      table.insert(marks, mark)
    end
  end
  return marks
end

--- Toggle mark on current line
function Marks:toggle()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  ---@type Beez.codemarks.markdata
  local data = {
    file = file_path,
    lineno = pos[1],
  }
  local key = get_key(data)
  if self.marks[key] then
    self:del(data)
  else
    self:add()
  end
end

--- Add a mark
function Marks:add()
  local file_path = vim.api.nvim_buf_get_name(0)
  local pos = vim.api.nvim_win_get_cursor(0)
  ---@type Beez.codemarks.markdata
  local data = {
    file = file_path,
    lineno = pos[1],
  }
  local mark = Mark:new(data)
  local key = get_key(data)
  if self.marks[key] then
    return
  end

  self.marks[key] = mark
  self:save({
    mode = "a",
    lines = mark:serialize() .. "\n",
    cb = function()
      vim.notify("Mark created...", vim.log.levels.INFO)
    end,
  })
end

--- Delete a mark
---@param data Beez.codemarks.markdata
function Marks:del(data)
  local key = get_key(data)
  if self.marks[key] then
    self.marks[key] = nil
    self:save({
      cb = function()
        vim.notify("Mark deleted...", vim.log.levels.INFO)
      end,
    })
  end
end

--- Save marks to file
---@param opts {cb: function?}?
function Marks:save(opts)
  opts = opts or {}
  local lines = ""
  for _, mark in pairs(self.marks) do
    lines = lines .. mark:serialize() .. "\n"
  end

  uv.fs_open(self.opts.marks_file, "w", 438, function(err, fd)
    if err then
      error("Could not open file: " .. self.opts.marks_file)
      return
    end

    uv.fs_write(fd, lines, -1, function(ws_err)
      if ws_err then
        error("Could not write to file: " .. self.opts.marks_file)
      end
      uv.fs_close(fd, function(close_err)
        if close_err then
          error("Could not close file: " .. self.opts.marks_file)
        end
        if opts.cb ~= nil then
          opts.cb()
        end
      end)
    end)
  end)
end

return Marks
