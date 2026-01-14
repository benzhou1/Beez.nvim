local M = {}

---@class Beez.pickers.deck.tasks.Task
---@field state string
---@field text string
---@field line string
---@field tags table<string, boolean>

--- Parse line into a task object
---@param line string
---@return Beez.pickers.deck.tasks.Task?
local function parse_line(line)
  local task_state, task_desc = line:match("^%s*-%s%[(%s?x?/?)%]%s(.*)$")
  if task_state == nil or task_desc == nil then
    return nil
  end

  local tags = {}
  for tag in task_desc:gmatch("#([^%s]+)") do
    tags[tag] = true
    task_desc = task_desc:gsub(" #" .. tag, "")
  end

  local task = {
    state = task_state,
    line = line,
    text = task_desc,
    tags = tags,
  }
  return task
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
  ---@type Beez.pickers.deck.tasks.Task
  local at = a.data.task
  ---@type Beez.pickers.deck.tasks.Task
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
---@param ctx deck.ExecuteContext
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

--- Deck source for flotes tasks
---@param opts? table
---@return deck.Source
function M.list_tasks(opts)
  opts = opts or {}
  local u = require("beez.u")
  local actions = require("beez.pickers.deck.tasks.actions")

  local source = {
    name = "find_tasks",
  }

  source.execute = function(ctx)
    local zkp = require("plugins.zk")
    local System = require("deck.kit.System")
    local query = ctx.get_query()

    local root_dir = zkp.notebook_dir
    local task_states = " /"
    if actions.toggles.done_task then
      task_states = task_states .. "x"
    end

    local tasks = {}
    local cmd = {
      "rg",
      "--column",
      "--line-number",
      "--ignore-case",
      "-e",
      ("- \\[[%s]?\\]"):format(task_states),
    }

    ctx.on_abort(System.spawn(cmd, {
      cwd = root_dir,
      env = {},
      buffering = System.LineBuffering.new({
        ignore_empty = true,
      }),
      on_stdout = function(line)
        local filename, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
        local t = parse_line(text)
        if filename == nil or t == nil or lnum == nil then
          return
        end

        local path = vim.fs.joinpath(root_dir, filename)
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
        -- Handle parent-child relationships
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

  source.actions = actions.actions(
    actions.toggle_done_task.name,
    actions.edit.name,
  )

  source.actions = u.tables.extend(
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
  )

  source.decorators = {
    decorators.hash_tags(),
  }
  return source
end

return M
