local M = {}

function M.tree(de, rtree_buf, otree_buf)
  local both_keymaps = {
    quit = {
      "q",
      function()
        de:quit()
      end,
      desc = "Quit and ignore changes",
    },
    focus_diff = {
      "<cr>",
      function()
        de:focus_right()
      end,
      desc = "Open selected file in diff editors",
    },
    next_file = {
      "k",
      function()
        de:move_to_file()
      end,
      desc = "Move to the next file and diff",
    },
    prev_file = {
      "j",
      function()
        de:move_to_file(true)
      end,
      desc = "Move to the previous file and diff",
    },
    toggle_file_change = {
      "<space>",
      function()
        de:toggle_file_change()
      end,
      desc = "Toggle entire file changed",
    },
    apply_and_quit = {
      "\\<cr>",
      function()
        vim.cmd("qa")
      end,
      desc = "Apply all changes and quit",
    },
    scroll_diff_down = {
      "K",
      function()
        de:scroll_diff(20)
      end,
      desc = "Scroll diff down",
    },
    scroll_diff_up = {
      "J",
      function()
        de:scroll_diff(-20)
      end,
      desc = "Scroll diff up",
    },
  }
  local rtree_keymaps = {
    focus_otree = {
      "l",
      function()
        de:focus_other_tree()
      end,
      desc = "Focus the output file tree window",
      buffer = rtree_buf,
    },
  }
  local otree_keymaps = {
    focus_rtree = {
      "h",
      function()
        de:focus_other_tree()
      end,
      desc = "Focus the right file tree window",
      buffer = otree_buf,
    },
  }
  local keymaps = vim.tbl_deep_extend("keep", rtree_keymaps, otree_keymaps)
  for k, v in pairs(both_keymaps) do
    keymaps[k .. "_rtree"] = vim.tbl_deep_extend("keep", { buffer = rtree_buf }, v)
    keymaps[k .. "_otree"] = vim.tbl_deep_extend("keep", { buffer = otree_buf }, v)
  end
  return keymaps
end

--- Default keymaps for the left side of the diff
---@param de Beez.jj.DiffEditor
---@param buffer integer
---@return table
function M.left(de, buffer)
  local keymaps = {
    quit = {
      "q",
      function()
        de:quit()
      end,
      buffer = buffer,
      desc = "Quit and ignore changes",
    },
    focus_prev_tree = {
      "<esc>",
      function()
        de:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
  }
  return keymaps
end

--- Default keymaps for the right side of diff
---@param de Beez.jj.DiffEditor
---@param buffer integer
---@return table
function M.right(de, buffer)
  local keymaps = {
    quit = {
      "q",
      function()
        de:quit()
      end,
      buffer = buffer,
      desc = "Quit and ignore changes",
    },
    focus_prev_tree = {
      "<esc>",
      function()
        de:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
    apply_and_quit = {
      "\\<cr>",
      function()
        de:apply_and_quit()
      end,
      buffer = buffer,
      desc = "Quit and apply changes",
    },
    toggle_hunk_change = {
      "<space>",
      function()
        de:toggle_hunk_change()
      end,
      buffer = buffer,
    },
    toggle_other_diff = {
      "\\\\",
      function()
        de:toggle_other_diff()
      end,
      desc = "Toggle between original/output diff",
      buffer = buffer,
    },
    next_hunk_k = {
      "k",
      function()
        de:move_to_hunk()
      end,
      desc = "Navigate to the next hunk",
    },
    next_hunk_l = {
      "l",
      function()
        de:move_to_hunk()
      end,
      desc = "Navigate to the next hunk",
    },
    prev_hunk_j = {
      "j",
      function()
        de:move_to_hunk(true)
      end,
      desc = "Navigate to the prev hunk",
    },
    prev_hunk_h = {
      "h",
      function()
        de:move_to_hunk(true)
      end,
      desc = "Navigate to the prev hunk",
    },
  }
  return keymaps
end

return M
