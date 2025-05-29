local utils = require("Beez.flotes.utils")
local M = {}

--- Replaces the selected text with link
---@param line string
---@param s number
---@param e number
---@param item_path string
function M.replace_with_link(line, s, e, item_path)
  local left = string.sub(line, 1, s - 1)
  local right = string.sub(line, e + 1)
  local middle = string.sub(line, s, e)
  local new_middle = "[" .. middle .. "](" .. utils.path.basename(item_path) .. ")"
  vim.api.nvim_set_current_line(left .. new_middle .. right)
end

--- Inserts a liink at the cursor position
---@param item_path string
function M.add_link_at_cursor(item_path)
  local filename = utils.path.basename(item_path)
  vim.api.nvim_put({ "[](" .. filename .. ")" }, "c", false, true)
  local pos = vim.api.nvim_win_get_cursor(0)
  local offset = string.len(filename) + 2
  vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] - offset })
  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

--- Follows the markdown link under the cursor
function M.follow_link()
  local f = require("Beez.flotes")
  if vim.bo.filetype ~= "markdown" then
    return false
  end

  local under_md_link, _, url = utils.get_md_link_under_cursor()
  if not under_md_link or url == nil then
    return false
  end

  local is_http, _, _ = utils.patterns.contains_http_link(url)
  if is_http then
    vim.fn.jobstart("open " .. url)
  else
    f.show({ note_name = url })
  end
  return true
end

return M
