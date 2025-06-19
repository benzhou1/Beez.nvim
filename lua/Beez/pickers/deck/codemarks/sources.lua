local actions = require("Beez.pickers.deck.codemarks.actions")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for codemarks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.find(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks",
    execute = function(ctx)
      local marks = require("Beez.codemarks").gmarks
      local filter_marks = {}
      local toggles = actions.toggles
      if not toggles.global_codemarks then
        local root = u.root.get_name({ buf = vim.api.nvim_get_current_buf() })
        for _, m in pairs(marks:list({ root = root })) do
          if m.root == root then
            table.insert(filter_marks, m)
          end
        end
        if #filter_marks == 0 then
          vim.notify("No marks found, showing all marks...", vim.log.levels.WARN)
          toggles.global_codemarks = true
        end
      end

      if toggles.global_codemarks then
        for _, m in pairs(marks.marks) do
          table.insert(filter_marks, m)
        end
      end

      for _, m in ipairs(filter_marks) do
        local item = {
          display_text = {
            { m.desc, "Normal" },
            { " " },
            { m.root, "Comment" },
          },
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            data = m.data,
          },
        }
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
function M.find_marks(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "codemarks",
    execute = function(ctx)
      local marks = require("Beez.codemarks").marks
      local filter_marks = {}
      local toggles = actions.toggles
      if not toggles.global_marks then
        local filename = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
        filter_marks = marks:list({ file = filename })
        if #filter_marks == 0 then
          vim.notify("No marks found, showing all marks...", vim.log.levels.WARN)
          toggles.global_marks = true
        end
      end

      if toggles.global_marks then
        filter_marks = marks:list()
      end

      for _, m in ipairs(filter_marks) do
        local line = u.os.read_line_at(m.file, m.lineno)
        local display_text = {
          { tostring(m.lineno), "Search" },
          { " " },
          { line, "Normal" },
        }
        if toggles.global_marks then
          local basename = u.paths.basename(m.file)
          local dirname = u.paths.dirname(m.file)
          display_text = {
            { basename, "Normal" },
            { ":" .. tostring(m.lineno), "Comment" },
            { " " },
            { dirname, "Comment" },
            { " " },
            { line, "Normal" },
          }
        end
        local item = {
          display_text = display_text,
          data = {
            filename = m.file,
            lnum = tonumber(m.lineno),
            data = m.data,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", opts.default_action or "open_codemarks"),
      require("deck").alias_action("toggle1", "toggle_global"),
      require("deck").alias_action("delete", "delete_mark"),
      actions.open_zed({ quit = opts.open_zed.quit }),
      actions.toggle_global({ mark = true }),
      actions.delete({ mark = true }),
      actions.open({ mark = true }),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
