local tasks = require("Beez.flotes.tasks")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.tasks.utils")
local M = {}

M.open_task = {
  name = "open_task",
  execute = function(ctx)
    local _, item = utils.get_current_task(ctx)
    ctx.hide()
    M.show_task_deck({ task_id = item.data.id })
  end,
}

M.show_task = {
  name = "show_task",
  execute = function(ctx)
    local t, _ = utils.get_current_task(ctx)
    ctx.hide()

    local task_id = t.parent.id
    M.show_task_deck({ task_id = task_id, task_select = t.id })
  end,
}

M.parent_task = function(opts)
  return {
    name = "parent_task",
    execute = function(ctx)
      local tl = tasks.get_tasks()
      local t = tl:get(opts.task_id)
      assert(t ~= nil, "Task not found: " .. opts.task_id)
      ctx.hide()

      local task_id = tl.root.id
      if t.parent ~= nil then
        task_id = t.parent.id
      end
      M.show_task_deck({ task_id = task_id, task_select = t.id })
    end,
  }
end

M.toggle_show_done = {
  name = "toggle_show_done",
  execute = function(ctx)
    M.toggles.show_done = not M.toggles.show_done
    ctx.execute()
  end,
}

M.edit_tasks = function(opts)
  opts = opts or {}
  return {
    name = opts.name or "edit_tasks",
    execute = function(ctx)
      local tl = tasks.get_tasks()
      local parent = nil
      if opts.parent_id ~= nil then
        parent = tl:get(opts.parent_id)
      else
        parent = tl.root
      end

      local lines = {}
      local items = {}
      local curr_item = ctx.get_cursor_item()
      local buf_offset = 6 -- 1 for hyphen, 1 for space, 3 for state, 1 for space
      local pos = vim.api.nvim_win_get_cursor(0)
      for _, item in ipairs(ctx.get_rendered_items()) do
        local line = item.data.task:line()
        line = u.strs.trim(line)
        parent = item.data.task.parent
        table.insert(lines, line)
        items[item.data.task.id] = item.data.task
      end
      assert(parent ~= nil, "Parent not found")

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_name(buf, "edit_tasks.md")
      vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
      vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
      vim.api.nvim_set_option_value("modified", false, { buf = buf })
      vim.api.nvim_set_option_value("filetype", "md", { buf = buf })

      vim.api.nvim_set_current_buf(buf)
      -- vim.api.nvim_win_set_height(0, opts.static_height or math.floor(vim.o.lines * 0.25))
      -- Clears undo history
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("setlocal undolevels=-1")
        vim.cmd('exe "normal a \\<BS>\\<Esc>"')
        vim.cmd("setlocal undolevels=100")
      end)

      vim.keymap.set("n", "q", function()
        vim.api.nvim_win_hide(0)
      end, { buffer = buf })

      local autocmds = {}
      local saved = false
      table.insert(
        autocmds,
        vim.api.nvim_create_autocmd("BufWriteCmd", {
          pattern = ("<buffer=%s>"):format(buf),
          callback = function()
            vim.api.nvim_set_option_value("modified", false, { buf = buf })
            lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local require_save = false
            for _, line in ipairs(lines) do
              local t = tasks.Task:new(line)
              local exist_t = items[t.id]
              if exist_t == nil then
                t.text = u.strs.trim(t.text)
                tl:insert(parent, t)
                require_save = true
              else
                local updated = exist_t:update(t)
                if updated then
                  require_save = true
                end
                items[t.id] = nil
              end
            end
            -- Tasks remaining means they were deleted
            for _, item in pairs(items) do
              local task = tl:get(item.id)
              if task ~= nil then
                tl:remove(task)
                require_save = true
              end
            end
            if require_save then
              tl:save()
            end
            saved = true
            vim.api.nvim_win_hide(0)
            ctx.show()
            ctx.execute()
          end,
        })
      )
      vim.api.nvim_create_autocmd({ "BufDelete", "WinClosed" }, {
        once = true,
        pattern = ("<buffer=%s>"):format(buf),
        callback = function()
          for _, autocmd in ipairs(autocmds) do
            vim.api.nvim_del_autocmd(autocmd)
          end
          if not saved then
            vim.schedule(function()
              ctx.show()
              ctx.execute()
            end)
          end
        end,
      })

      if opts.action == "insert" then
        local new_pos = { pos[1], pos[2] + 2 }
        vim.api.nvim_win_set_cursor(0, new_pos)
        vim.api.nvim_feedkeys("i", "n", false)
      elseif opts.action == "insert_above_line" then
        vim.api.nvim_win_set_cursor(0, pos)
        vim.api.nvim_feedkeys("O", "n", false)
      elseif opts.action == "insert_line" then
        vim.api.nvim_win_set_cursor(0, pos)
        vim.api.nvim_feedkeys("o", "n", false)
      elseif opts.action == "insert_start" then
        vim.api.nvim_win_set_cursor(0, { pos[1], buf_offset })
        vim.api.nvim_feedkeys("i", "n", false)
      elseif opts.action == "insert_end" then
        vim.api.nvim_win_set_cursor(0, {
          pos[1],
          buf_offset + u.utf8.len(curr_item.data.task.text),
        })
        vim.api.nvim_feedkeys("i", "n", false)
      elseif opts.action == "delete_char" then
        local new_pos = { pos[1], pos[2] + 2 }
        vim.api.nvim_win_set_cursor(0, new_pos)
        vim.api.nvim_feedkeys("x", "n", false)
      elseif opts.action == "replace_char" then
        local new_pos = { pos[1], pos[2] + 2 }
        vim.api.nvim_win_set_cursor(0, new_pos)
        vim.api.nvim_feedkeys("r", "n", false)
      elseif opts.action == "delete" then
        vim.api.nvim_win_set_cursor(0, pos)
        vim.api.nvim_feedkeys("dd", "n", false)
      end
    end,
  }
end

return M
