local utils = require("beez.pickers.snacks.codemarks.utils")
local M = {}

--- Picker action to delete the currently selected item
function M.delete(picker)
  local item = picker:selected({ fallback = true })[1]
  if item == nil then
    return
  end

  local marks = require("beez.codemarks").marks
  marks:del(item.data)

  picker:close()
  vim.schedule(function()
    require("snacks.picker").resume()
  end)
end

--- Focus the list window
function M.switch_to_list(picker)
  require("snacks.picker.actions").cycle_win(picker)
  require("snacks.picker.actions").cycle_win(picker)
end

--- Toggles global flag
function M.toggle_global(picker)
  utils.set_global_toggle(not utils.get_global_toggle())
  picker:close()
  vim.schedule(function()
    -- HACK: This is a hack to update the title of the picker after resuming
    picker.last.opts.title = utils.get_title()
    picker:resume()
  end)
end

--- Updates the description of the mark under the cursor
function M.update_desc(picker)
  local item = picker:selected({ fallback = true })[1]
  if item == nil then
    return
  end

  local marks = require("beez.codemarks").marks
  local mark = marks:get(item.data)
  if mark == nil then
    return
  end

  vim.ui.input({ prompt = "Update the mark desription", default = mark.desc }, function(res)
    if res == nil then
      return
    end
    picker:close()
    marks:update(item.data, { desc = res }, function()
      vim.schedule(function()
        picker:resume()
      end)
    end)
  end)
end

return M
