local M = {
  hl = {
    current_buf = "BufswitcherCurrentBuf",
    name = "BufswitcherName",
    dir = "BufswitcherDir",
    recent_label = "BufswitcherRecentLabel",
    pin_label = "BufswitcherPinLabel",
    separator = "BufswitcherSeparator",
    stack = "BufswitcherStack",
    stack_sep = "BufswitcherStackSep",
    buf_sep = "BufswitcherBufferSep",
    pin_sep = "BufswitcherPinSep",
  },
}

--- Initialize sensible defaults for highlight groups
function M.init()
  vim.api.nvim_set_hl(0, M.hl.current_buf, { fg = "#DE6E7C", bold = true, underline = true })
  vim.api.nvim_set_hl(0, M.hl.name, { link = "Normal" })
  vim.api.nvim_set_hl(0, M.hl.dir, { link = "Comment" })
  vim.api.nvim_set_hl(0, M.hl.recent_label, { link = "Search" })
  vim.api.nvim_set_hl(0, M.hl.pin_label, { link = "Search" })
  vim.api.nvim_set_hl(0, M.hl.separator, { link = "Comment", bold = true })
  vim.api.nvim_set_hl(0, M.hl.stack, { link = "Comment" })
  vim.api.nvim_set_hl(0, M.hl.stack_sep, { link = "Comment" })
  vim.api.nvim_set_hl(0, M.hl.buf_sep, { link = "String" })
  vim.api.nvim_set_hl(0, M.hl.pin_sep, { link = "String", bold = true })
end

return M
