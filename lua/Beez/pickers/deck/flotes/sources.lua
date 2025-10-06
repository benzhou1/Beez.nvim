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
          tags[tag] = true
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

--- Sort tasks based on their state and tags and mtime
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
  ---@type Beez.flotes.Task
  local at = a.data.task
  ---@type Beez.flotes.Task
  local bt = b.data.task
  local ascore = state_scores[at.state]
  local bscore = state_scores[bt.state]
  for tag, _ in pairs(at.tags) do
    ascore = ascore + (tag_scores[tag] or 0)
  end
  for tag, _ in pairs(bt.tags) do
    bscore = bscore + (tag_scores[tag] or 0)
  end
  if a.data.mtime > b.data.mtime then
    ascore = ascore + 0.5
  elseif b.data.mtime > a.data.mtime then
    bscore = bscore + 0.5
  end
  return ascore > bscore
end

--- Display a task in deck
---@param ctx deck.Context
---@param item table
---@param keys table<string, boolean>
---@param indent? integer
local function display_task(ctx, item, keys, indent)
  indent = indent or 0
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
      { string.rep("  ", indent or 0), "Normal" },
      { "-", "Comment" },
      { " ", "String" },
      { marker, marker_hl },
      { " ", "String" },
      { item.data.task.text, task_hl },
    },
    filter_text = item.data.task.line,
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
      display_task(ctx, child, keys, indent + 1)
    end
  end
end

--- Get all tasks from using rg to grep
---@param ctx deck.ExecuteContext
local function get_tasks_from_text(ctx)
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

  local tasks = {}
  ctx.on_abort(System.spawn(cmd, {
    cwd = root_dir,
    env = {},
    buffering = System.LineBuffering.new({
      ignore_empty = true,
    }),
    on_stdout = function(line)
      local filename, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
      local t = f.tasks.parse_line(text)
      if filename == nil or t == nil or lnum == nil then
        return
      end

      local path = IO.join(root_dir, filename)
      local curr_task = {
        data = {
          tags = t.tags,
          query = query,
          filename = path,
          lnum = tonumber(lnum),
          col = tonumber(col),
          task = t,
          mtime = u.os.mtime(path),
        },
      }
      tasks[path] = tasks[path] or {}
      tasks[path][lnum] = curr_task
    end,
    on_exit = function()
      local task_list = {}
      for _, _tasks in pairs(tasks) do
        for lnum, t in pairs(_tasks) do
          table.insert(task_list, t)

          -- Found a child task
          if t.data.col > 1 then
            local i = lnum - 1
            local lines = u.os.read_lines(t.data.filename)
            -- Find the parent line
            while true and i > 0 do
              local line = lines[i]
              local leading_ws = line:match("^(%s*)")
              local ws_count = #leading_ws
              -- This must be the parent
              if ws_count < t.data.col - 1 then
                local parent = tasks[t.data.filename][i]
                -- Parent is a task, assign current task as a child
                if parent ~= nil then
                  parent.children = parent.children or {}
                  table.insert(parent.children, t)
                end
                break
              end
              i = i - 1
            end
          end
        end
      end

      local keys = {}
      table.sort(task_list, sort_tasks)
      for _, item in ipairs(task_list) do
        display_task(ctx, item, keys)
      end
      ctx.done()
    end,
  }))
end

--- Deck source for flotes tasks
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.tasks(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false, def_action_open = true })

  local source = utils.resolve_source(opts, {
    name = "find_tasks",
    execute = function(ctx)
      -- get_tasks_from_ts(ctx)
      get_tasks_from_text(ctx)
    end,
    actions = u.tables.extend(
      opts.actions or {},
      opts.def_action_open and actions.open_note() or actions.insert_task_tag(),
      actions.toggle_done_task(),

      u.deck.edit_actions({
        prefix = "edit_tasks.",
        edit_line = actions.edit_tasks,
        edit_line_end = {
          ---@diagnostic disable-next-line: missing-fields
          edit_opts = {
            get_pos = function(item, pos)
              -- 6 for beginning of task
              local offset = u.utf8.len(item.data.task.task_desc) + 6 + item.data.col - 1
              return { pos[1], offset }
            end,
            get_feedkey = function(feedkey)
              return "i"
            end,
          },
        },
        edit_line_start = {
          ---@diagnostic disable-next-line: missing-fields
          edit_opts = {
            get_pos = function(item, pos)
              -- 6 for beginning of task
              return { pos[1], 6 + item.data.col - 1 }
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
