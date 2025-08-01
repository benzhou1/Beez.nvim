local actions = require("Beez.pickers.deck.flotes.actions")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {}

--- Deck source for finding notes files
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.files(opts)
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
            { string.sub(item.data.title, 2), "String" },
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
    actions = u.tables.extend({
      require("deck").alias_action("alt_default", "new_note"),
      require("deck").alias_action("delete", "delete_note"),
      actions.new_note,
      actions.delete_note,
    }, actions.open_note()),
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
  local flotes_dir = require("Beez.flotes").config.notes_dir
  opts.cwd = flotes_dir
  opts = utils.resolve_opts(opts or {}, { is_grep = false, filename_first = false })

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
          table.insert(item.display_text, { before_match, "String" })
          table.insert(item.display_text, { query_match, "Search" })
          table.insert(item.display_text, { after_match, "String" })
        else
          table.insert(item.display_text, { match, "String" })
        end
        item.data.filename = file_path
        item.data.lnum = lnum
        item.data.col = col
      end,
    }))
  )
  source.actions = u.tables.extend({}, actions.open_note())
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for backlinks
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.backlinks(opts)
  local flotes_dir = require("Beez.flotes").config.notes_dir
  local filepath = vim.api.nvim_buf_get_name(0)
  local filename = u.paths.basename(filepath)

  opts.cwd = flotes_dir
  opts.pattern = "(" .. filename .. ")"
  opts = utils.resolve_opts(opts or {}, { is_grep = false, filename_first = false })

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
          table.insert(item.display_text, { before_match, "String" })
          table.insert(item.display_text, { query_match, "Search" })
          table.insert(item.display_text, { after_match, "String" })
        else
          table.insert(item.display_text, { match, "String" })
        end
        item.data.filename = file_path
        item.data.lnum = lnum
        item.data.col = col
      end,
    }))
  )
  source.actions = u.tables.extend({}, actions.open_note())
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Deck source for flotes tasks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.tasks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local source = utils.resolve_source(opts, {
    name = "find_tasks",
    execute = function(ctx)
      local f = require("Beez.flotes")
      local IO = require("deck.kit.IO")
      local System = require("deck.kit.System")
      local query = ctx.get_query()
      local root_dir = f.config.notes_dir
      assert(root_dir ~= nil, "Flotes root directory is not set")
      local task_states = " /"
      if actions.toggles.done_task then
        task_states = " /x"
      end

      local cmd = {
        "rg",
        "--column",
        "--line-number",
        "--ignore-case",
        "--sortr",
        "modified",
        "-e",
        ("- \\[[%s]?\\]"):format(task_states),
      }
      local items = {}
      local done_items = {}

      ctx.on_abort(System.spawn(cmd, {
        cwd = root_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local item = { data = { query = query } }
          local filename = text:match("^[^:]+")
          local lnum = tonumber(text:match(":(%d+):"))
          local col = tonumber(text:match(":%d+:(%d+):"))
          local task = text:match(":%d+:%d+:(.*)$")
          local task_state = task:match("^%s*-%s%[(%s?x?/?)%]")
          if filename and task then
            item = {
              display_text = {
                { task, "String" },
              },
              data = {
                filename = IO.join(root_dir, filename),
                lnum = lnum,
                col = col,
              },
            }
          end
          if item.display_text ~= nil then
            if task_state == "/" then
              ctx.item(item)
            elseif task_state == "x" then
              table.insert(done_items, item)
            else
              table.insert(items, item)
            end
          end
        end,
        on_exit = function()
          for _, item in ipairs(items) do
            ctx.item(item)
          end
          for _, item in ipairs(done_items) do
            ctx.item(item)
          end
          ctx.done()
        end,
      }))
    end,
    actions = u.tables.extend({}, actions.open_note(), actions.toggle_done_task()),
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
