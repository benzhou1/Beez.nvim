local utils = require("Beez.flotes.utils")
local M = {}

--- Checks whether a path a file under the journal directory
---@param path string
---@return boolean
function M.is_journal(path)
  if path == nil then
    return false
  end
  return string.find(path, M.config.journal_dir) ~= nil
end

--- Gets the timestamp used for a journal file
---@param opts {days: number}?
---@return integer
function M.get_journal_timestamp(opts)
  opts = opts or {}
  -- Create timestamp out of date only, ignore time
  local ts_opts = { hour = 0, min = 0, sec = 0 }
  if opts.days ~= nil then
    ts_opts.day = function(d)
      return d.day + opts.days
    end
  end
  local timestamp = utils.timestamp(ts_opts)
  return timestamp
end

--- Finds a journal file
---@param opts Beez.flotes.journalfindopts?
---@return integer
function M.find_journal(opts)
  opts = opts or {}
  local today = M.get_journal_timestamp()
  -- Find by human readable description
  if opts.desc then
    if opts.desc == "today" then
      return today
    elseif opts.desc == "yesterday" then
      return M.get_journal_timestamp({ days = -1 })
    elseif opts.desc == "tomorrow" then
      return M.get_journal_timestamp({ days = 1 })
    end
    return today
  end

  -- Find relative to currently opened note
  if opts.direction ~= nil then
    local entries = vim.split(vim.fn.glob(M.config.journal_dir .. "/*"), "\n", { trimempty = true })

    local journal_entries = {}
    for _, entry in ipairs(entries) do
      local filename = utils.path.basename(entry)
      local timestamp = tonumber(string.match(filename, "^(%d+)"))
      table.insert(journal_entries, timestamp)
    end
    -- Sort by recent descending
    table.sort(journal_entries, function(a, b)
      return a > b
    end)

    local curr_idx = nil
    local current_note = vim.api.nvim_buf_get_name(0)
    if current_note == nil or not M.is_journal(current_note) then
      return today
    end

    -- Extract file name without extension
    local curr_base = utils.path.basename(current_note)
    local curr_ts = tonumber(string.match(curr_base, "^(%d+)"))
    -- Find the current ts
    for i, entry in ipairs(journal_entries) do
      if curr_ts == entry then
        curr_idx = i
        break
      end
    end

    if opts.direction == "next" then
      return journal_entries[curr_idx - 1]
    else
      return journal_entries[curr_idx + 1]
    end
  end
  return today
end

return M
