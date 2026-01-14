local actions = require("beez.pickers.deck.codemarks.actions")
local u = require("beez.u")
local utils = require("beez.pickers.deck.utils")
local M = {}

--- Deck source for global codemarks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.global_marks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks.global_marks",
    execute = function(ctx)
      local cm = require("beez.codemarks")
      local gmarks = {}
      local toggles = actions.toggles
      if not toggles.global_codemarks then
        local root = u.root.get_name({ buf = cm.curr_buf })
        gmarks = cm.gmarks.list({ root = root })
      end

      if toggles.global_codemarks then
        gmarks = cm.gmarks.list()
      end

      for i, m in ipairs(gmarks) do
        local item = {
          display_text = {
            { m.desc, "String" },
            { " ", "String" },
          },
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            mark = m,
            i = i,
          },
        }
        if toggles.global_codemarks then
          table.insert(item.display_text, { m.root, "Comment" })
        end
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      opts.actions or {},
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
        insert_above = { disable = true },
        insert_below = { disable = true },
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
      local cm = require("beez.codemarks")
      local marks = cm.marks.list()
      marks = u.tables.reverse(marks)

      for _, m in ipairs(marks) do
        local line = u.os.read_line_at(m.file, m.lineno)
        local display_text = {
          { u.paths.basename(m.file), "String" },
          { " ", "String" },
          { tostring(m.lineno), "Search" },
          { ":" .. m.col, "String" },
          { " ", "String" },
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

return M
