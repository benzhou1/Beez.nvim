local actions = require("Beez.pickers.deck.codemarks.actions")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for global codemarks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.global_marks(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.global_marks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local gmarks = {}
      local toggles = actions.toggles
      if not toggles.global_codemarks then
        gmarks = cm.list_gmarks()
      end

      if toggles.global_codemarks then
        local buf = cm.curr_buf or vim.api.nvim_get_current_buf()
        local root = u.root.get_name({ buf = buf })
        gmarks = cm.list_gmarks({ root = root, all_stacks = true })
      end

      for _, m in ipairs(gmarks) do
        local item = {
          display_text = {
            { m.desc, "Normal" },
            { " " },
          },
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            data = m:serialize(),
          },
        }
        if toggles.global_codemarks then
          table.insert(item.display_text, { m.stack, "Comment" })
        end
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", opts.default_action or "open_codemarks"),
      require("deck").alias_action("toggle1", "toggle_global"),
      require("deck").alias_action("delete", "delete_mark"),
      actions.open_zed({ quit = opts.open_zed.quit }),
      actions.toggle_global(),
      actions.delete(),
      actions.open(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for marks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.marks(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.marks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local marks = cm.list_marks()
      marks = u.tables.reverse(marks)

      for _, m in ipairs(marks) do
        local line = u.os.read_line_at(m.file, m.lineno)
        local display_text = {
          { u.paths.basename(m.file), "Normal" },
          { " " },
          { tostring(m.lineno), "Search" },
          { ":" .. m.col, "Normal" },
          { " " },
          { line, "Comment" },
        }
        local item = {
          display_text = display_text,
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            data = m,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", opts.default_action or "open_codemarks"),
      require("deck").alias_action("delete", "delete_mark"),
      actions.open_zed({ quit = opts.open_zed.quit }),
      actions.delete({ mark = true }),
      actions.open({ mark = true }),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for codemark stacks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.stacks(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.stacks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local toggles = actions.toggles

      local stacks
      if not toggles.global_stacks then
        local buf = cm.curr_buf or vim.api.nvim_get_current_buf()
        local root = u.root.get_name({ buf = buf })
        stacks = cm.stacks:list({ root = root })
      else
        stacks = cm.stacks:list()
      end

      for _, s in ipairs(stacks) do
        local hl = "Normal"
        if cm.stacks.curr_stack == s.name then
          hl = "Search"
        end

        local display_text = {
          { tostring(s.name), hl },
          { " " },
          { s.root, "Comment" },
        }
        local item = {
          display_text = display_text,
          data = {
            stack = s,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", "select_stack"),
      require("deck").alias_action("toggle1", "toggle_global"),
      actions.toggle_global({ stacks = true }),
      actions.select_stack(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
