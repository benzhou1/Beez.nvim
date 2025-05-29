local actions = require("Beez.pickers.deck.flotes.actions")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for finding notes files
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.files(opts)
  local u = require("Beez.u")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "find_notes",
    execute = function(ctx)
      local System = require("deck.kit.System")
      local notify = require("deck.notify")
      local f = require("Beez.flotes")
      local query = ctx.get_query()
      local cmd = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--max-columns=500",
        "--max-columns-preview",
        "--sortr",
        "modified",
        "-g",
        "!.git",
        "^#",
        "-m",
        "1",
      }
      if query ~= "" then
        table.insert(cmd, query)
      end

      ctx.on_abort(System.spawn(cmd, {
        cwd = f.config.notes_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local item = { data = { query = query } }
          ---@diagnostic disable-next-line: redefined-local
          local file, _, _, text = text:match("^(.+):(%d+):(%d+):(.*)$")
          if file then
            local file_path = f.config.notes_dir .. u.paths.sep .. file
            item.data.title = text
            item.data.filename = file_path
          end
          item.display_text = {
            { string.sub(item.data.title, 2), "Normal" },
          }
          ctx.item(item)
        end,
        on_stderr = function(text)
          notify.show({
            { { ("[rg: stderr] %s"):format(text), "ErrorMsg" } },
          })
        end,
        on_exit = function()
          ctx.done()
        end,
      }))
    end,
    actions = {
      require("deck").alias_action("default", "open_note"),
      require("deck").alias_action("alt_default", "new_note"),
      require("deck").alias_action("delete", "delete_note"),
      actions.open_note,
      actions.new_note,
      actions.delete_note,
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for flotes templates
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.templates(opts)
  opts = opts or {}
  local f = require("Beez.flotes")
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "note_templates",
    execute = function(ctx)
      for name, template in pairs(f.config.templates.templates) do
        ctx.item({
          display_text = name,
          data = {
            name = name,
            template = template.template,
          },
        })
      end
      ctx:done()
    end,
    actions = {
      require("deck").alias_action("default", "new_note_from_template"),
      actions.new_note_from_template,
    },
    previewers = {
      {
        name = "flotes.templates.preview",
        resolve = function(ctx)
          local item = ctx.get_cursor_item()
          if item then
            return item.data.template ~= nil
          end
        end,
        preview = function(_, item, env)
          local x = require("deck.x")
          local lines = vim.split(item.data.template, "\n")
          x.open_preview_buffer(env.win, { contents = lines, filename = item.data.name })
        end,
      },
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for grepping notes
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.grep(opts)
  local u = require("Beez.u")
  local flotes_dir = require("Beez.u.apps.Beez").flotes_dir
  opts = utils.resolve_opts(opts or {}, { is_grep = false, filename_first = false, cwd = flotes_dir })
  local source = utils.resolve_source(
    opts,
    require("deck.builtin.source.grep")(vim.tbl_deep_extend("keep", opts.source_opts, {
      cmd = function(query)
        local cmd = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--max-columns=500",
          "--max-columns-preview",
          "-g",
          "!.git",
        }
        table.insert(cmd, query)
        return cmd
      end,
      transform = function(item, text)
        local filename = text:match("^[^:]+")
        local file_path = opts.cwd .. u.paths.sep .. filename
        local title = u.os.read_first_line(file_path)
        local lnum = tonumber(text:match(":(%d+):"))
        local col = tonumber(text:match(":%d+:(%d+):"))
        local match = text:match(":%d+:%d+:(.*)$")
        item.display_text = {
          { title, "Comment" },
          { " " },
          { "(" .. lnum .. ":" .. col .. "): ", "Comment" },
          { " " },
        }
        local start_idx, end_idx = string.find(string.lower(match), string.lower(item.data.query))
        if start_idx ~= nil then
          local before_match = string.sub(match, 1, start_idx - 1)
          local query_match = string.sub(match, start_idx, end_idx)
          local after_match = string.sub(match, end_idx + 1)
          table.insert(item.display_text, { before_match, "Normal" })
          table.insert(item.display_text, { query_match, "Search" })
          table.insert(item.display_text, { after_match, "Normal" })
        else
          table.insert(item.display_text, { match, "Normal" })
        end
        item.data.filename = file_path
        item.data.lnum = lnum
        item.data.col = col
      end,
    }))
  )
  source.actions = {
    require("deck").alias_action("default", "open_note"),
    actions.open_note,
  }
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
