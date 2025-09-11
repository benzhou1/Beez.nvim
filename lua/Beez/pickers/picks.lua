local dbfp_pickers = require("Beez.pickers.deck.dbfp")
local deck_pickers = require("Beez.pickers.deck")
local flotes_pickers = require("Beez.pickers.deck.flotes")
local fzf_pickers = require("Beez.pickers.fzf.pickers")
local snack_pickers = require("Beez.pickers.snacks")

---@class Beez.pick
---@field run fun(opts: table)
---@field def_opts? fun(opts: table): table

---@class Beez.picker
---@field snacks? Beez.pick
---@field fzf? Beez.pick
---@field deck? Beez.pick

local M = {}

local snacks_def_opts = function(opts)
  opts = opts or {}
  local def_opts = {
    layout = {
      layout = {
        height = opts.disable_preview == true and 0.25 or 0.50,
      },
    },
  }
  return def_opts
end

function M.smart()
  return {
    snacks = {
      resume = false,
      def_opts = snacks_def_opts,
      run = function(opts)
        opts = vim.tbl_deep_extend("keep", opts, snack_pickers.options.smart)
        require("snacks.picker").pick(opts)
      end,
    },
    deck = {
      resume = false,
      run = function(opts)
        require("deck").start(deck_pickers.sources.files_smart(opts))
      end,
    },
  }
end

function M.smart_recent()
  return {
    deck = {
      run = function(opts)
        require("deck").start(deck_pickers.sources.files_recent_smart(opts))
      end,
    },
  }
end

function M.resume()
  return {
    snacks = {
      run = function(opts)
        require("snacks.picker").resume(opts)
      end,
    },
    deck = {
      run = function(opts)
        local deck = require("deck")
        local context = deck.get_history()[vim.v.count == 0 and 1 or vim.v.count]
        if context then
          context.show()
        end
      end,
    },
  }
end

function M.find_config()
  return {
    deck = {
      run = function(opts)
        opts.root_dir = vim.fn.stdpath("config")
        opts.cwd = vim.fn.stdpath("config")
        require("deck").start(deck_pickers.sources.files(opts))
      end,
    },
  }
end

function M.grep()
  return {
    snacks = {
      run = function(opts)
        require("snacks.picker").grep(opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.grep").live_grep(opts)
      end,
    },
    deck = {
      run = function(opts)
        require("Beez.pickers.deck").grep(opts)
      end,
    },
  }
end

function M.grep_buffer()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = {
            preset = "bottom",
            layout = {
              height = 0.25,
            },
          },
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("lines", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.grep").grep_curbuf(opts)
      end,
    },
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.grep_buffer(opts)
        require("deck").start(source, specifier)
      end,
    },
  }
end

function M.find_buffers()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("buffers", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.buffers").buffers(opts)
      end,
    },
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.buffers(opts)
        require("deck").start(source, specifier)
      end,
    },
  }
end

function M.grep_buffers()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("grep_buffers", opts)
      end,
    },
  }
end

function M.grep_word()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("grep_word", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.grep").grep_cword(opts)
      end,
    },
    deck = {
      run = function(opts)
        deck_pickers.grep_word(opts)
      end,
    },
  }
end

function M.find_files()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("files", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.files").files(opts)
      end,
    },
    deck = {
      run = function(opts)
        require("deck").start(deck_pickers.sources.files(opts))
      end,
    },
  }
end

function M.search_cmd_history()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = {
            preset = "bottom",
          },
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("command_history", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.nvim").command_history(opts)
      end,
    },
  }
end

function M.search_cmds()
  return {
    snacks = {
      run = function(opts)
        require("snacks.picker").pick("commands", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.nvim").commands(opts)
      end,
    },
  }
end

function M.search_hl()
  return {
    snacks = {
      def_opts = function(opts)
        return vim.tbl_deep_extend("keep", {
          confirm = function(picker)
            picker:close()
            local item = picker:current()
            if not item then
              return
            end
            vim.fn.setreg("+", item.hl_group)
          end,
        }, snacks_def_opts(opts))
      end,
      run = function(opts)
        require("snacks.picker").pick("highlights", opts)
      end,
    },
  }
end

function M.search_keymaps()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("keymaps", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.nvim").keymaps(opts)
      end,
    },
  }
end

function M.find_dirs()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("dirs", opts)
      end,
    },
    deck = {
      run = function(opts)
        require("deck").start(deck_pickers.sources.dirs_smart(opts))
      end,
    },
  }
end

function M.find_recents()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("recent_files", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.oldfiles").oldfiles(opts)
      end,
    },
    deck = {
      run = function(opts)
        require("deck").start(deck_pickers.sources.files_recent(opts))
      end,
    },
  }
end

function M.git_log()
  return {
    deck = {
      run = function(opts)
        deck_pickers.git.log(opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("u.pickers.fzf.pickers").git_commit_diff(opts)
      end,
    },
  }
end

function M.git_compare_file_with_branch()
  return {
    deck = {
      run = function(opts)
        deck_pickers.git_compare_path_with_branch(opts.path, opts)
      end,
    },
    fzf = {
      run = function(opts)
        fzf_pickers.git_compare_path_with_branch(opts.path, opts)
      end,
    },
  }
end

function M.git_compare_project_with_branch()
  return {
    deck = {
      run = function(opts)
        deck_pickers.git_compare_project_with_branch(opts)
      end,
    },
    fzf = {
      run = function(opts)
        fzf_pickers.git_compare_project_with_branch(opts)
      end,
    },
  }
end

function M.goto_def()
  return {
    snacks = {
      def_opts = function(opts)
        return vim.tbl_deep_extend("keep", {
          unique_lines = true,
          formatters = {
            file = {
              filename_only = true,
            },
          },
        }, snacks_def_opts(opts))
      end,
      run = function(opts)
        opts.formatters = {
          file = {
            filename_only = true,
          },
        }
        require("snacks.picker").pick("lsp_definitions", opts)
      end,
    },
    fzf = {
      def_opts = function(opts)
        return {
          unique_line_items = true,
          jump_to_single_result = true,
          ignore_current_line = true,
        }
      end,
      run = function(opts)
        require("fzf-lua.providers.lsp").definitions(opts)
      end,
    },
    deck = {
      run = function(opts)
        require("Beez.pickers.deck.lsp").go_to_definitions(opts)
      end
    }
  }
end

function M.goto_ref()
  return {
    snacks = {
      def_opts = function(opts)
        return vim.tbl_deep_extend("keep", {
          unique_lines = true,
          formatters = {
            file = {
              filename_only = true,
            },
          },
        }, snacks_def_opts(opts))
      end,
      run = function(opts)
        opts.formatters = {
          file = {
            filename_only = true,
          },
        }
        require("snacks.picker").pick("lsp_references", opts)
      end,
    },
    fzf = {
      def_opts = function(opts)
        return {
          jump_to_single_result = true,
          ignore_current_line = true,
        }
      end,
      run = function(opts)
        require("fzf-lua.providers.lsp").references(opts)
      end,
    },
    deck = {
      run = function(opts)
        require("Beez.pickers.deck.lsp").find_references(opts)
      end
    }
  }
end

---@param buf? number
---@return string[]?
local function get_kind_filter(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local ft = vim.bo[buf].filetype
  if M.kind_filter == false then
    return
  end
  if M.kind_filter[ft] == false then
    return
  end
  if type(M.kind_filter[ft]) == "table" then
    return M.kind_filter[ft]
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return type(M.kind_filter) == "table"
      and type(M.kind_filter.default) == "table"
      and M.kind_filter.default
    or nil
end

local function symbols_filter(entry, ctx)
  if ctx.symbols_filter == nil then
    ctx.symbols_filter = get_kind_filter(ctx.bufnr) or false
  end
  if ctx.symbols_filter == false then
    return true
  end
  return vim.tbl_contains(ctx.symbols_filter, entry.kind)
end

local kind_filter = {
  default = {
    "Class",
    "Constructor",
    "Enum",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    "Package",
    "Property",
    "Struct",
    "Trait",
  },
  markdown = false,
  help = false,
  -- you can specify a different filter for each filetype
  lua = {
    "Class",
    "Constructor",
    "Enum",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    -- "Package", -- remove package since luals uses it for control flow structures
    "Property",
    "Struct",
    "Trait",
  },
}

function M.doc_symbols()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = { preview = "main", layout = { height = 0.25 } },
        }
      end,
      run = function(opts)
        ---@diagnostic disable-next-line: missing-fields
        require("snacks.picker").pick(
          "lsp_symbols",
          vim.tbl_deep_extend("keep", opts, {
            filter = kind_filter,
          })
        )
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua").lsp_document_symbols(vim.tbl_deep_extend("keep", opts, {
          regex_filter = symbols_filter,
        }))
      end,
    },
  }
end

function M.ws_symbols()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        ---@diagnostic disable-next-line: missing-fields
        require("snacks.picker").pick(
          "lsp_workspace_symbols",
          vim.tbl_deep_extend("keep", opts, {
            filter = kind_filter,
          })
        )
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua").lsp_workspace_symbols(vim.tbl_deep_extend("keep", opts, {
          regex_filter = symbols_filter,
        }))
      end,
    },
  }
end

function M.git_hunks()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = snack_pickers.layouts.vertical,
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("git_diff", opts)
      end,
    },
  }
end

function M.undo()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = snack_pickers.layouts.max,
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("undo", opts)
      end,
    },
  }
end

function M.regs()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = snack_pickers.layouts.vertical,
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("registers", opts)
      end,
    },
  }
end

function M.git_status()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          layout = snack_pickers.layouts.max,
        }
      end,
      run = function(opts)
        require("snacks.picker").pick("git_status", opts)
      end,
    },
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.git_status(opts)
        require("deck").start(source, specifier)
      end,
    },
  }
end

function M.show_tasks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.flotes.tasks(opts)
      end,
    },
  }
end

function M.find_tasks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.flotes.find_tasks(opts)
      end,
    },
  }
end

function M.find_btags()
  return {
    fzf = {
      run = function(opts)
        require("fzf-lua").btags(opts)
      end,
    },
  }
end

function M.find_ctags()
  return {
    fzf = {
      run = function(opts)
        if opts.workspace then
          require("fzf-lua").tags(opts)
        else
          require("fzf-lua").btags(opts)
        end
      end,
    },
    deck = {
      run = function(opts)
        if opts.workspace then
          deck_pickers.tags_workspace(opts)
        else
          require("deck").start(deck_pickers.sources.tags_document(opts))
        end
      end,
    },
  }
end

function M.find_breakpoints()
  return {
    snacks = {
      run = function(opts)
        snack_pickers.breakpoints.finder(opts)
      end,
    },
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.breakpoints(opts)
        require("deck").start(source, specifier)
      end,
    },
  }
end

function M.grep_help()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        require("snacks.picker").pick("help", opts)
      end,
    },
    fzf = {
      run = function(opts)
        require("fzf-lua.providers.helptags").helptags(opts)
      end,
    },
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.help_grep(opts)
        local ctx = require("deck").start(source, specifier)
        ctx.set_preview_mode(true)
      end,
    },
  }
end

function M.spelling()
  return {
    snacks = {
      def_opts = snacks_def_opts,
      run = function(opts)
        opts = vim.tbl_deep_extend("keep", opts, {
          layout = {
            preset = "bottom",
          },
        })
        require("snacks.picker").pick("spelling", opts)
      end,
    },
  }
end

function M.codestacks_global_marks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.codestacks.global_marks(opts)
      end,
    },
  }
end
M["codestacks.global_marks"] = M.codestacks_global_marks

function M.codemarks_global_marks_update_line()
  return {
    deck = {
      run = function(opts)
        deck_pickers.codemarks.update_global_marks_line(opts)
      end,
    },
  }
end
M["codemarks.global_marks_update_line"] = M.codemarks_global_marks_update_line

function M.codemarks_marks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.codemarks.marks(opts)
      end,
    },
  }
end
M["codemarks.marks"] = M.codemarks_marks

function M.scratches()
  return {
    snacks = {
      def_opts = function(opts)
        return {
          exclude = { "*.pyc", "*__pycache__*", "*__init__.py" },
        }
      end,
      run = function(opts)
        snack_pickers.scratches.find(opts)
      end,
    },
    deck = {
      run = function(opts)
        deck_pickers.scratches.find(opts)
      end,
    },
  }
end

M["notes.find"] = function()
  return {
    snacks = {
      run = function(opts)
        snack_pickers.flotes.notes(opts)
      end,
    },
    deck = {
      run = flotes_pickers.find,
    },
  }
end

M["notes.grep"] = function()
  return {
    deck = {
      run = flotes_pickers.grep,
    },
  }
end

M["notes.find_templates"] = function()
  return {
    snacks = {
      run = function(opts)
        snack_pickers.flotes.templates(opts)
      end,
    },
    deck = {
      run = flotes_pickers.find_templates,
    },
  }
end

M["notes.backlinks"] = function()
  return {
    deck = {
      run = flotes_pickers.backlinks,
    },
  }
end

M["dbfp.connections"] = function()
  return {
    deck = {
      run = dbfp_pickers.connections,
    },
  }
end

M["dbfp.queries"] = function()
  return {
    deck = {
      run = dbfp_pickers.queries,
    },
  }
end

M["dbfp.queryfiles"] = function()
  return {
    deck = {
      run = dbfp_pickers.queryfiles,
    },
  }
end

M["jump_list"] = function()
  return {
    deck = {
      run = deck_pickers.jump_list,
    },
  }
end

function M.bufswitcher_stacks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.bufswitcher.stacks(opts)
      end,
    },
  }
end
M["bufswitcher.stacks"] = M.bufswitcher_stacks

function M.fff()
  return {
    deck = {
      run = function(opts)
        local source, specifier = deck_pickers.sources.fff(opts)
        require("deck").start(source, specifier)
      end,
    },
  }
end

function M.codestacks_stacks()
  return {
    deck = {
      run = function(opts)
        deck_pickers.codestacks.stacks(opts)
      end,
    },
  }
end
M["codestacks.stacks"] = M.codestacks_stacks

return M
