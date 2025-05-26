local M = {}

M.max = {
  preset = "vertical",
  layout = { width = 0.9, height = 0.9 },
}

M.vertical = {
  preset = "vertical",
  layout = { width = 0.8 },
}

M.bottom = {
  preset = "ivy",
  layout = {
    position = "bottom",
    height = 0.25,
    border = "none",
    box = "vertical",
    {
      win = "preview",
      title = "{preview}",
      height = 0.6,
      border = "single",
    },
    { win = "list", border = "none" },
    { win = "input", height = 1, border = "top" },
  },
}

return M
