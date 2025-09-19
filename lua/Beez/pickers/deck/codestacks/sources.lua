local actions = require("Beez.pickers.deck.codestacks.actions")
local decorators = require("Beez.pickers.deck.codestacks.decorators")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for codestacks stacks
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.stacks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "codestacks.stacks",
    execute = function(ctx)
      local cs = require("Beez.codestacks")
      local stacks = cs.stacks.list()
      -- Sort so that active stack is first
      table.sort(stacks, function(a, b)
        if cs.stacks.is_active(a.name) then
          return true
        end
        if cs.stacks.is_active(b.name) then
          return false
        end
        return a.name < b.name
      end)

      for _, s in ipairs(stacks) do
        local hl = "String"
        if cs.stacks.is_active(s.name) then
          hl = "Search"
        end
        local item = {
          display_text = { { s.name, hl } },
          data = { stack = s },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      actions.set_active_stack(),
      actions.add_stack(),
      actions.rename_stack(),
      actions.remove_stack()
    ),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for global marks
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.global_marks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codestacks.global_marks",
    execute = function(ctx)
      local cs = require("Beez.codestacks")
      local gmarks = {}
      local toggles = actions.toggles
      if not toggles.global_codemarks then
        gmarks = cs.global_marks.list()
      end

      if toggles.global_codemarks then
        gmarks = cs.global_marks.list({ all = true })
      end

      for i, m in ipairs(gmarks) do
        local item = {
          display_text = {
            { m.desc, "String" },
            { " ", "String" },
            { m.path, "Comment" },
            { tostring(m.lineno), "Comment" },
          },
          filter_text = m.desc .. " " .. m.path .. " #" .. m.stack,
          data = {
            filename = m.path,
            lnum = tonumber(m.lineno),
            mark = m,
            i = i,
            stack = m.stack,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = u.tables.extend(
      opts.actions or {},
      {
        require("deck").alias_action("default", "open_codestacks"),
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
    decorators = {
      decorators.stack_name(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
