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
    scroll_to_next_hunk = {
      "<f7>",
      function()
        de:scroll_to_hunk()
      end,
      desc = "Scroll to next hunk",
    },
    scroll_to_prev_hunk = {
      "<s-f7>",
      function()
        de:scroll_to_hunk(true)
      end,
      desc = "Scroll to previous hunk",
    },
  }
  local rtree_keymaps = {
    focus_otree = {
      "<c-k>",
      function()
        de:focus_other_tree()
      end,
      desc = "Focus the output file tree window",
      buffer = rtree_buf,
    },
  }
  local otree_keymaps = {
    focus_rtree = {
      "<c-j>",
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
      "-",
      function()
        de:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
    focus_retree = {
      "<c-j>",
      function()
        de:focus_rtree()
      end,
      buffer = buffer,
      desc = "Focus the original commit tree window",
    },
    focus_otree = {
      "<c-k>",
      function()
        de:focus_otree()
      end,
      buffer = buffer,
      desc = "Focus the new commit tree window",
    },
    next_file = {
      "<tab>",
      function()
        de:move_to_file()
      end,
      buffer = buffer,
      desc = "Move to the next file",
    },
    prev_file = {
      "<s-tab>",
      function()
        de:move_to_file(true)
      end,
      buffer = buffer,
      desc = "Move to the previous file",
    },
  }
  return keymaps
end

function M.right(de, buffer)
  local actions = require("vscode-diff.render.keymaps").actions
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
      "-",
      function()
        de:focus_prev_tree()
      end,
      buffer = buffer,
      desc = "Focus the previous commit tree window",
    },
    focus_rtree = {
      "<c-j>",
      function()
        de:focus_rtree()
      end,
      buffer = buffer,
      desc = "Focus the original commit tree window",
    },
    focus_otree = {
      "<c-k>",
      function()
        de:focus_otree()
      end,
      buffer = buffer,
      desc = "Focus the new commit tree window",
    },
    apply_and_quit = {
      "\\<cr>",
      function()
        de:apply_and_quit()
      end,
      buffer = buffer,
      desc = "Quit and apply changes",
    },
    next_file = {
      "<tab>",
      function()
        de:move_to_file()
      end,
      buffer = buffer,
      desc = "Move to the next file",
    },
    prev_file = {
      "<s-tab>",
      function()
        de:move_to_file(true)
      end,
      buffer = buffer,
      desc = "Move to the previous file",
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
    next_hunk = {
      "<f7>",
      function()
        local left_buf, _ = de.diff:get_buffers()
        actions.navigate_next_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      end,
      desc = "Navigate to the next hunk",
    },
    prev_hunk = {
      "<s-f7>",
      function()
        local left_buf, _ = de.diff:get_buffers()
        actions.navigate_prev_hunk(vim.api.nvim_get_current_tabpage(), left_buf)()
      end,
      desc = "Navigate to the prev hunk",
    },
  }
  return keymaps
end

return M
