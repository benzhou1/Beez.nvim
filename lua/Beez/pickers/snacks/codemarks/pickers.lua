local u = require("Beez.u")
local utils = require("Beez.pickers.snacks.codemarks.utils")
local M = {}
local actions = require("Beez.pickers.snacks.codemarks.actions")

--- Picker for searching marks
function M.marks(opts)
  local function marks_finder(_, ctx)
    local marks = require("Beez.codemarks").marks
    local filter_marks = {}
    if not utils.get_global_toggle() then
      local root = u.root.get({ buf = vim.api.nvim_get_current_buf() })
      for _, m in pairs(marks.marks) do
        if m.root == root then
          table.insert(filter_marks, m)
        end
      end
      if #filter_marks == 0 then
        vim.notify("No marks found, showing all marks...", vim.log.levels.WARN)
        utils.set_global_toggle(true)
      end
    end

    if utils.get_global_toggle() then
      for _, m in pairs(marks.marks) do
        table.insert(filter_marks, m)
      end
    end

    local items = {} ---@type snacks.picker.finder.Item[]
    for _, m in ipairs(filter_marks) do
      local item = {
        text = m.desc,
        file = m.file,
        pos = { m.lineno, 0 },
        data = m.data,
        flags = "root",
      }
      table.insert(items, item)
    end

    ctx.picker.title = actions.get_title()
    return ctx.filter:filter(items)
  end

  local pick_opts = vim.tbl_deep_extend("keep", opts or {}, {
    title = actions.get_title(),
    finder = marks_finder,
    format = function(item, _)
      return { { item.text } }
    end,
    matcher = {
      frecency = true,
      sort_empty = true,
      file_pos = false,
    },
    supports_live = false,
    actions = {
      delete = actions.delete,
      switch_to_list = actions.switch_to_list,
      toggle_global = actions.toggle_global,
      rename_mark = actions.update_desc,
    },
    win = {
      title = "{title}",
    },
  })

  require("snacks.picker").pick(pick_opts)
end

return M
