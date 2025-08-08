local actions = require("Beez.pickers.deck.flotes.actions")
local decorators = require("Beez.pickers.deck.flotes.decorators")
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
          "--sortr",
          "path",
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
        local tags = {}
        for tag in match:gmatch("#(%w+)") do
          table.insert(tags, tag)
          match = match:gsub(" #" .. tag, "")
        end

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
        item.data.tags = tags
      end,
    }))
  )
  source.actions = u.tables.extend({}, actions.open_note())
  source.decorators = u.tables.extend(source.decorators or {}, { decorators.hash_tags() })
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

---@class Beez.pickers.deck.flotes.task
---@field state string
---@field task_text string
---@field task_desc string
---@field tags string[]

--- Sort tasks based on their state and tags
---@param a table
---@param b table
---@return boolean
local function sort_tasks(a, b)
  local state_scores = {
    ["/"] = 10,
    [" "] = 1,
    ["x"] = -10,
  }
  local tag_scores = {
    ["bug"] = 3,
    ["p1"] = 3,
    ["p2"] = 2,
    ["p3"] = 1,
  }
  ---@type Beez.pickers.deck.flotes.task
  local at = a.data.task
  ---@type Beez.pickers.deck.flotes.task
  local bt = b.data.task
  local ascore = state_scores[at.state]
  local bscore = state_scores[bt.state]
  for _, tag in ipairs(at.tags) do
    ascore = ascore + (tag_scores[tag] or 0)
  end
  for _, tag in ipairs(bt.tags) do
    bscore = bscore + (tag_scores[tag] or 0)
  end
  return ascore > bscore
end

--- Parse line into a task object
---@param line string
---@return Beez.pickers.deck.flotes.task?
local function parse_task_line(line)
  local task_text = line:match(":%d+:%d+:(.*)$")
  if task_text == nil then
    return nil
  end

  local task_state, task_desc = task_text:match("^%s*-%s%[(%s?x?/?)%]%s(.*)$")
  if task_state == nil or task_desc == nil then
    return nil
  end

  local tags = {}
  for tag in task_desc:gmatch("#(%w+)") do
    table.insert(tags, tag)
    task_desc = task_desc:gsub(" #" .. tag, "")
  end

  local task = {
    state = task_state,
    task_text = task_text,
    task_desc = task_desc,
    tags = tags,
  }
  return task
end

--- Display a task in deck
---@param item table
local function display_task(ctx, item, keys)
  local cmp = require("plugins.checkmate")
  local task_state = item.data.task.state
  local marker = cmp.md_to_marker(task_state)

  local task_hl = "String"
  local marker_hl = "CheckmateUncheckedMarker"
  if task_state == "x" then
    marker_hl = "CheckmateCheckedMarker"
    task_hl = "CheckmateCheckedMainContent"
  elseif task_state == "/" then
    marker_hl = "CheckmateInprogressMarker"
  end

  local deck_item = {
    display_text = {
      { string.rep(" ", item.data.col), "String" },
      { "-", "Comment" },
      { " ", "String" },
      { marker, marker_hl },
      { " ", "String" },
      { item.data.task.task_desc, task_hl },
    },
    filter_text = item.data.task.task_text,
    data = item.data,
  }

  -- Avoid showing item multiple times
  local key = item.data.filename .. ":" .. item.data.lnum .. ":" .. item.data.col
  if keys[key] then
    return
  end

  ctx.item(deck_item)
  keys[key] = true

  -- Display children tasks if any
  if item.children ~= nil then
    table.sort(item.children, sort_tasks)
    for _, child in ipairs(item.children) do
      display_task(ctx, child, keys)
    end
  end
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
        task_states = task_states .. "x"
      end
      local cmd = {
        "rg",
        "--column",
        "--line-number",
        "--ignore-case",
        "-e",
        ("- \\[[%s]?\\]"):format(task_states),
      }

      local task_list = {}
      ctx.on_abort(System.spawn(cmd, {
        cwd = root_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local filename = text:match("^[^:]+")
          local lnum = tonumber(text:match(":(%d+):"))
          local col = tonumber(text:match(":%d+:(%d+):"))
          local t = parse_task_line(text)
          if filename == nil or t == nil or lnum == nil then
            return
          end

          local curr_task = {
            data = {
              tags = t.tags,
              query = query,
              filename = IO.join(root_dir, filename),
              lnum = lnum,
              col = col,
              task = t,
            },
          }
          table.insert(task_list, curr_task)

          -- Found a child task
          if col > 1 then
            local curr_lnum = lnum
            -- Assume parent task is the last task that has a column less than the current task
            local i = #task_list
            while true do
              if i == 0 then
                break
              end

              local parent = task_list[i]
              if parent.data.filename == curr_task.data.filename and parent.data.lnum < curr_lnum then
                if parent.data.col < col then
                  -- Found parent task based on column
                  parent.children = parent.children or {}
                  table.insert(parent.children, curr_task)
                  break
                end
              end
              i = i - 1
            end
          end
        end,
        on_exit = function()
          local keys = {}
          table.sort(task_list, sort_tasks)
          for _, item in ipairs(task_list) do
            display_task(ctx, item, keys)
          end
          ctx.done()
        end,
      }))
    end,
    actions = u.tables.extend(
      {},
      actions.open_note(),
      actions.toggle_done_task(),

      u.deck.edit_actions({
        prefix = "edit_tasks",
        edit_line = actions.edit_tasks,
        edit_line_end = {
          ---@diagnostic disable-next-line: missing-fields
          edit_opts = {
            get_pos = function(item, pos)
              -- 6 for beginning of task
              local offset = u.utf8.len(item.data.task.task_desc) + 6
              return { pos[1], offset }
            end,
            get_feedkey = function(feedkey)
              return "i"
            end,
          },
        },
      })
    ),
    decorators = {
      decorators.hash_tags(),
    },
  })

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
