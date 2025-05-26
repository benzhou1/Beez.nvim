local M = {}
local map = vim.keymap.set
local unmap = function(...)
  pcall(vim.keymap.del, ...)
end

function M.general(opts)
  opts = opts or {}
  map({ "n" }, "q", function()
    vim.cmd("q")
  end)
end

function M.movements(opts)
  opts = opts or {}

  map({ "n", "x", "o" }, "j", "k", { remap = false })
  map({ "n", "x", "o" }, "k", "j", { remap = false })
  map(
    { "n", "x", "o" },
    "j",
    "v:count == 0 ? 'gk' : 'k'",
    { desc = "Up", expr = true, silent = true, remap = false }
  )
  map({ "n", "x", "o" }, "k", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })

  local page = "20"
  map({ "n", "x" }, "J", page .. "k", { remap = false, desc = "Previous page" })
  map({ "n", "x" }, "K", page .. "j", { remap = false, desc = "Next page" })

  map({ "n", "x" }, "H", "^", { desc = "Beginning of line" })
  map({ "n", "x" }, "L", "$", { desc = "End of line" })
end

return M
