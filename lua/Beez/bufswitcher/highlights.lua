local M = {
  hl = {
    current_buf = "BufswitcherCurrentBuf",
    name = "BufswitcherName",
    dir = "BufswitcherDir",
    recent_label = "BufswitcherRecentLabel",
    pin_label = "BufswitcherPinLabel",
    separator = "BufswitcherSeparator",
  },
}

--- Initialize sensible defaults for highlight groups
function M.init()
  vim.api.nvim_set_hl(0, M.hl.current_buf, { link = "Search", bold = true })
  vim.api.nvim_set_hl(0, M.hl.name, { link = "Normal" })
  vim.api.nvim_set_hl(0, M.hl.dir, { link = "Comment" })
  vim.api.nvim_set_hl(0, M.hl.recent_label, { link = "CurSearch" })
  vim.api.nvim_set_hl(0, M.hl.pin_label, { link = "CurSearch" })
  vim.api.nvim_set_hl(0, M.hl.separator, { link = "Comment", bold = true })
end

return M
