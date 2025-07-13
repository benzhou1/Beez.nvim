local actions = require("Beez.pickers.deck.codemarks.actions")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for global codemarks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.global_marks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.global_marks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local gmarks = {}
      local toggles = actions.toggles
      if not toggles.global_codemarks then
        gmarks = cm.gmarks.list()
      end

      if toggles.global_codemarks then
        gmarks = cm.gmarks.list({ root = true, all_stacks = true })
      end

      for i, m in ipairs(gmarks) do
        local item = {
          display_text = {
            { m.desc, "Normal" },
            { " " },
          },
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            mark = m,
            i = i,
          },
        }
        if toggles.global_codemarks then
          table.insert(item.display_text, { m.stack, "Comment" })
        end
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      {
        require("deck").alias_action("default", "open_codemarks"),
        require("deck").alias_action("toggle1", "toggle_global"),
        actions.toggle_global(),
        actions.open(),
      },
      u.deck.edit_actions({
        prefix = "edit_marks",
        edit_line = actions.edit_global_marks,
        edit_line_end = {
          ---@diagnostic disable-next-line: missing-fields
          edit_opts = {
            get_pos = function(item, pos)
              local offset = item.data.mark.desc:len()
              return { pos[1], offset }
            end,
            get_feedkey = function(feedkey)
              return "i"
            end,
          },
        },
      })
    ),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for marks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.marks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.marks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local marks = cm.marks.list()
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
            mark = m,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", "open_codemarks"),
      actions.open_zed({ quit = opts.open_zed.quit }),
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
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.stacks",
    execute = function(ctx)
      local cm = require("Beez.codemarks")
      local toggles = actions.toggles
      local curr_stack = cm.stacks.get()

      local stacks
      if not toggles.global_stacks then
        stacks = cm.stacks.list({ root = true })
      else
        stacks = cm.stacks.list()
      end

      for _, s in ipairs(stacks) do
        local hl = "Normal"
        if curr_stack ~= nil and curr_stack.name == s.name then
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
      require("deck").alias_action("alt_default", "select_stack_hook"),
      require("deck").alias_action("toggle1", "toggle_global"),
      actions.toggle_global({ stacks = true }),
      actions.select_stack(),
      actions.select_stack_hook(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
