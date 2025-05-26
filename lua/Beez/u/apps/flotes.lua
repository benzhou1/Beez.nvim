local M = {
  notes_dir = vim.fn.expand("~/SynologyDrive/flotes"),
  spec = {
    dir = "~/Projects/nvim_forks/flotes.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
  },
}

function M.spec.opts()
  return {
    notes_dir = M.notes_dir,
    keymaps = {
      prev_journal = false,
      next_journal = false,
      add_note_link = "[[",
      add_note_link_visual = "[[",
      journal_keys = function(bufnr)
        local bettern = require("better-n")
        local next_journal_repeat = bettern.create({
          next = function()
            require("flotes").journal({ direction = "next" })
          end,
          prev = function()
            require("flotes").journal({ direction = "prev" })
          end,
        })
        local prev_journal_repeat = bettern.create({
          next = function()
            require("flotes").journal({ direction = "prev" })
          end,
          prev = function()
            require("flotes").journal({ direction = "next" })
          end,
        })

        vim.keymap.set("n", "mnh", function()
          prev_journal_repeat.next()
        end, { noremap = true, buffer = bufnr, desc = "Previous journal" })
        vim.keymap.set("n", "mnl", function()
          next_journal_repeat.next()
        end, { noremap = true, buffer = bufnr, desc = "Next journal" })
      end,
    },
    templates = {
      templates = {
        ["jira"] = {
          template = [[
# Jira: ${1:ticket} - ${2:title}

[link](https://jira.com/browse/${1})
]],
        },
        ["person"] = {
          template = [[
# Person: ${1:name}

email: ${2:email}
]],
        },
      },
    },
  }
end

function M.spec.config(_, opts, config_opts)
  require("flotes").setup(opts)
end

function M.spec.keys()
  return {
    {
      "<leader>oh",
      function()
        require("flotes").journal({ create = true })
      end,
      desc = "Open today journal",
    },
    {
      "<leader>of",
      function()
        require("deck").start(require("u.pickers.deck.pickers").notes.files.source())
      end,
      desc = "Find notes",
    },
    {
      "<leader>og",
      function()
        require("u.pickers.deck.pickers").notes.grep.deck()
      end,
      desc = "Grep notes",
    },
    {
      "<leader>oq",
      function()
        require("deck").start(require("u.pickers.deck.pickers").notes.templates.source())
      end,
      desc = "Find note templates",
    },
  }
end

return M
