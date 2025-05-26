local M = {}

function M.spec()
  return {
    {
      "craigmac/Navigator.nvim",
      lazy = true,
      event = "VeryLazy",
      config = function(_, opts)
        require("Navigator").setup()
      end,
      keys = {
        {
          "<C-h>",
          function()
            require("Navigator").left()
          end,
          desc = "Move left a Split",
          mode = { "n", "t", "x" },
        },
        {
          "<C-k>",
          function()
            require("Navigator").down()
          end,
          desc = "Move down a Split",
          mode = { "n", "t", "x" },
        },
        {
          "<C-j>",
          function()
            require("Navigator").up()
          end,
          desc = "Move up a Split",
          mode = { "n", "t", "x" },
        },
        {
          "<C-l>",
          function()
            require("Navigator").right()
          end,
          desc = "Move right a Split",
          mode = { "n", "t", "x" },
        },
        {
          "<C-S-h>",
          function()
            require("Navigator").left()
          end,
          desc = "Move left a Split",
          mode = { "n", "t", "x" },
        },
        {
          "<C-S-k>",
          function()
            vim.cmd("resize -2")
          end,
          desc = "Resize down",
          mode = { "n", "t", "x" },
        },
        {
          "<C-S-j>",
          function()
            vim.cmd("resize +2")
          end,
          desc = "Resize up",
          mode = { "n", "t", "x" },
        },
        {
          "<C-S-l>",
          function()
            vim.cmd("vertical resize -2")
            require("Navigator").right()
          end,
          desc = "Move right a Split",
          mode = { "n", "t", "x" },
        },
      },
    },
  }
end

return M
