local M = { toggles = { show_done = false } }

---@class Beez.pickers.deck.tasks.actions.Opts
---@field task_only? boolean If true, return a list with the task only without alias action

M.toggle_done_task = {}
M.toggle_done_task.name = "tasks.toggle_done_task"
--- Deck action to toggle showing done tasks or not
---@param opts? Beez.pickers.deck.tasks.actions.Opts
---@return deck.Action[]
function M.toggle_done_task.actions(opts)
  opts = opts or {}

  local actions = {}
  table.insert(actions, {
    name = "toggle_done_task",
    execute = function(ctx)
      M.toggles.done_task = not M.toggles.done_task
      if M.toggles.done_task then
        vim.notify("Showing done tasks...", vim.log.levels.INFO)
      else
        vim.notify("Showing only open tasks...", vim.log.levels.INFO)
      end
      ctx.execute()
    end,
  })

  if opts.task_only ~= true then
    table.insert(actions, require("deck").alias_action("toggle1", M.toggle_done_task.name))
  end
  return actions
end

function M.edit()
  local u = require("beez")
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
end

--- Returns a list of deck actions for specified action names
---@vararg string
---@return deck.Action[]
function M.actions(...)
  local u = require("beez.u")
  local action_names = { ... }
  local actions = {}
  for _, an in ipairs(action_names) do
    local curr_actions = M[an].actions()
    u.tables.extend(actions, curr_actions)
  end
  return actions
end

return M
