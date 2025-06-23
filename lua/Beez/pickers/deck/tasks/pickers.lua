local actions = require("Beez.pickers.deck.tasks.actions")
local u = require("Beez.u")
local resolve_opts = require("Beez.pickers.deck.utils").resolve_opts
local resolve_source = require("Beez.pickers.deck.utils").resolve_source
local resolve_specifier = require("Beez.pickers.deck.utils").resolve_specifier
local tasks = require("Beez.flotes.tasks")
local M = {}

--- Tasks deck
---@param opts? table
function M.show(opts)
  opts = resolve_opts(opts or {}, { filename_first = false })
  local set_cursor = nil

  local source = resolve_source(opts, {
    name = "tasks",

    execute = function(ctx)
      local tl = tasks.get_tasks()
      local task_id = opts.task_id or tl.root.id
      local t = tl:get(task_id)
      assert(t ~= nil, "Task not found:" .. task_id)

      local idx = 1
      ---@diagnostic disable-next-line: redefined-local
      for _, t in ipairs(t.children) do
        if tasks.should_show_task(t, { show_done = actions.toggles.show_done }) then
          local display_text = t:line({ show_fields = false, show_hyphen = false })
          display_text = display_text:trim()
          local item = {
            display_text = display_text,
            data = { id = t.id, task = t },
          }
          ctx.item(item)
          if opts.task_select == t.id then
            set_cursor = idx
          end
          idx = idx + 1
        end
      end
      ctx.done()
    end,

    events = {
      BufWinEnter = function(ctx, _)
        if set_cursor then
          ctx.set_cursor(set_cursor)
        end
      end,
    },

    actions = {
      require("deck").alias_action("default", "open_task"),
      require("deck").alias_action("prev_default", "parent_task"),
      require("deck").alias_action("toggle1", "toggle_show_done"),
      require("deck").alias_action("open_keep", "insert_task"),
      require("deck").alias_action("insert_above", "insert_task_above"),
      require("deck").alias_action("delete", "delete_task"),
      require("deck").alias_action("edit_line_start", "edit_task_start"),
      require("deck").alias_action("edit_line_end", "edit_task_end"),
      require("deck").alias_action("prompt", "edit_task"),
      require("deck").alias_action("delete_char", "delete_task_char"),
      require("deck").alias_action("write", "edit_tasks"),
      require("deck").alias_action("replace_char", "replace_task_char"),
      require("deck").alias_action("insert", "insert_task_char"),
      actions.open_task,
      actions.parent_task(opts),
      actions.toggle_show_done,
      actions.edit_tasks({ parent_id = opts.task_id, name = "insert_task_char", action = "insert" }),
      actions.edit_tasks({ parent_id = opts.task_id, name = "insert_task", action = "insert_line" }),
      actions.edit_tasks({
        parent_id = opts.task_id,
        name = "insert_task_above",
        action = "insert_above_line",
      }),
      actions.edit_tasks({ parent_id = opts.task_id, name = "delete_task", action = "delete" }),
      actions.edit_tasks({
        parent_id = opts.task_id,
        name = "delete_task_char",
        action = "delete_char",
      }),
      actions.edit_tasks({
        parent_id = opts.task_id,
        name = "replace_task_char",
        action = "replace_char",
      }),
      actions.edit_tasks({
        parent_id = opts.task_id,
        name = "edit_task_start",
        action = "insert_start",
      }),
      actions.edit_tasks({ parent_id = opts.task_id, name = "edit_task_end", action = "insert_end" }),
      actions.edit_tasks({ parent_id = opts.task_id, name = "edit_tasks" }),
    },
  })

  local specifier = resolve_specifier(opts, { start_prompt = false })
  require("deck").start(source, specifier)
end

--- Find tasks deck
---@param opts table
function M.find(opts)
  opts = resolve_opts(opts, { filename_first = false })

  local source = resolve_source(opts, {
    name = "find_task",

    execute = function(ctx)
      local tl = tasks.get_tasks()
      for _, t in tl:lines() do
        if tasks.should_show_task(t, { show_done = actions.toggles.show_done }) then
          local item = {
            display_text = t:line({ show_fields = false, show_hyphen = false }),
            data = { id = t.id },
          }
          ctx.item(item)
        end
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", "show_task"),
      require("deck").alias_action("alt_default", "open_task"),
      require("deck").alias_action("toggle1", "toggle_show_done"),
      actions.open_task,
      actions.show_task,
      actions.toggle_show_done,
    },
  })

  local specifier = resolve_specifier(opts)
  require("deck").start(source, specifier)
end

return M
