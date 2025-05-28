local M = {
  flotes_dir = vim.fn.expand("~/SynologyDrive/flotes"),
}

function M.flotes_opts()
  return {
    notes_dir = M.flotes_dir,
    open_in_float = true,
    keymaps = {
      prev_journal = false,
      next_journal = false,
      add_note_link = "[[",
      add_note_link_visual = "[[",
      journal_keys = function(bufnr)
        print("here")
        local f = require("Beez.flotes")
        local u = require("Beez.u")
        local bettern = require("better-n")
        local next_journal_repeat = bettern.create({
          next = function()
            f.journal({ direction = "next" })
          end,
          prev = function()
            f.journal({ direction = "prev" })
          end,
        })
        local prev_journal_repeat = bettern.create({
          next = function()
            f.journal({ direction = "prev" })
          end,
          prev = function()
            f.journal({ direction = "next" })
          end,
        })

        u.keymaps.set({
          {
            "mnh",
            function()
              prev_journal_repeat.next()
            end,
            noremap = true,
            buffer = bufnr,
            desc = "Previous journal",
          },
          {
            "mnl",
            function()
              next_journal_repeat.next()
            end,
            noremap = true,
            buffer = bufnr,
            desc = "Next journal",
          },
        })
      end,
    },
    templates = {
      expand = function(...)
        require("blink.cmp.config").snippets.expand(...)
      end,
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

function M.flotes_keys()
  return {
    {
      "<leader>oh",
      function()
        require("Beez.flotes").journal({ create = true })
      end,
      desc = "Open journal for today",
    },
    {
      "<leader>of",
      function()
        require("deck").start(require("Beez.pickers.deck").sources.notes_files())
      end,
      desc = "Find notes",
    },
    {
      "<leader>og",
      function()
        require("Beez.pickers.deck").notes_grep()
      end,
      desc = "Grep notes",
    },
    {
      "<leader>oq",
      function()
        require("deck").start(require("Beez.pickers.deck").sources.notes_templates())
      end,
      desc = "Find note templates",
    },
    {
      "gd",
      function()
        require("Beez.flotes").follow_link()
      end,
      desc = "Follow link",
    },
  }
end

function M.codemarks_opts()
  return {
    marks_file = vim.fn.expand("~/SynologyDrive/codemarks.txt"),
  }
end

function M.codemarks_keys()
  return {
    {
      "<leader>ml",
      function()
        require("Beez.pickers").pick("codemarks", { type = "deck" })
      end,
      desc = "Find colde marks",
    },
    {
      "<leader>ma",
      function()
        require("Beez.codemarks").add()
      end,
      desc = "Add a code mark",
    },
  }
end

function M.scratches_opts()
  return {
    scratch_dir = "~/SynologyDrive/scratches",
  }
end

function M.scratches_keys()
  return {
    {
      "`",
      function()
        require("Beez.scratches").open()
      end,
      desc = "Open scratch split",
    },
    {
      "<leader>s`",
      function()
        require("Beez.pickers").pick("scratches", { type = "deck" })
      end,
      desc = "Find scratch files",
    },
  }
end

function M.bufswitcher_opts()
  if M.statuscolumn == nil then
    M.statuscolumn = vim.o.statuscolumn
  end

  ---@type Beez.bufswitcher.config
  return {
    mode = "timeout",
    highlights = {
      lnum = "Comment",
    },
    buffers = {
      sort = function(a, b)
        local a_idx = 1
        local b_idx = 1
        for i, path in ipairs(require("deck.builtin.source.recent_files").file.contents) do
          if path == a.name then
            a_idx = i
          end
          if path == b.name then
            b_idx = i
          end
        end
        return a_idx > b_idx
      end,
    },
    hooks = {
      after_show_preview = function(opts)
        vim.api.nvim_buf_call(opts.preview_bufnr, function()
          vim.o.statuscolumn = "%s%=%l%s│"
        end)
        require("Beez.bufswitcher").after_show_preview(opts, { center_preview = true })
      end,
      after_show_target = function(opts)
        vim.api.nvim_buf_call(opts.target_buf.bufnr, function()
          vim.o.statuscolumn = M.statuscolumn
        end)
        require("Beez.bufswitcher").after_show_target(opts)
      end,
    },
  }
end

function M.bufswitcher_keys()
  return {
    {
      "<C-Tab>",
      function()
        require("Beez.bufswitcher").next_buf()
      end,
      desc = "Cycle bufswitcher foward",
    },
    {
      "<C-S-Tab>",
      function()
        require("Beez.bufswitcher").prev_buf()
      end,
      desc = "Cycle bufswitcher backwards",
    },
  }
end

function M.spec()
  local keys = {}
  for _, v in pairs(M.flotes_keys()) do
    table.insert(keys, v)
  end
  for _, v in pairs(M.bufswitcher_keys()) do
    table.insert(keys, v)
  end
  for _, v in pairs(M.codemarks_keys()) do
    table.insert(keys, v)
  end
  for _, v in pairs(M.scratches_keys()) do
    table.insert(keys, v)
  end

  return {
    dir = "~/Projects/nvim_forks/Beez.nvim",
    lazy = true,
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      flotes = M.flotes_opts(),
      bufswitcher = M.bufswitcher_opts(),
      codemarks = M.codemarks_opts(),
      scratches = M.scratches_opts(),
    },
    keys = keys,
  }
end

return M
