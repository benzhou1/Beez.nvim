local M = {}

---@class Beez.codemarks.config
---@field marks_file string? The path to the marks file
---@field pick_opts snacks.picker.Config? Options for snacks picker
---@type Beez.codemarks.config
M.def_config = {
  marks_file = vim.fn.stdpath("data") .. "/codemarks/codemarks.txt",
  pick_opts = {
    layout = {
      layout = {
        width = 0.6,
        height = 0.6,
        title = "{title}",
      },
    },
    win = {
      input = {
        keys = {
          ["<esc>"] = {
            "switch_to_list",
            mode = { "i" },
            desc = "Switch to the list view",
          },
          ["<c-g>"] = {
            "toggle_global",
            mode = { "i", "n" },
            desc = "Toggle to show all marks",
          },
        },
      },
      list = {
        keys = {
          ["dd"] = {
            "delete",
            desc = "Delete current mark",
          },
          ["a"] = {
            "toggle_focus",
            desc = "Focus input",
          },
          ["i"] = {
            "toggle_focus",
            desc = "Focus input",
          },
          ["r"] = {
            "rename_mark",
            desc = "Updates the mark description",
          },
        },
      },
    },
  },
}

--- Initlaize config
---@param opts Beez.codemarks.config?
function M.init(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.def_config, opts)
end

return M
