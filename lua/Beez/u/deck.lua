local M = {}

---@class Beez.u.deck.edit_list_opts
---@field save fun(items: deck.Item[], lines: string[]): boolean
---@field action "insert" | "insert_above_line" | "insert_line" | "insert_start" | "insert_end" | "delete_char" | "replace_char" | "delete"
---@field get_lines? fun(items: table<integer, deck.Item>): string[]
---@field filetype? string
---@field filename? string
---@field get_pos? fun(item: deck.Item, pos: number[]): number[]
---@field get_feedkey? fun(feedkey?: string): string

--- Generic function to edit a list of items in a scratch buffer
---@param ctx deck.Context
---@param opts Beez.u.deck.edit_list_opts
function M.edit_list(ctx, opts)
  local pos = vim.api.nvim_win_get_cursor(0)
  local win = vim.api.nvim_get_current_win()
  -- Get lines for buffer from callback
  local lines
  local items = {}
  local curr_items = ctx:get_items()
  local curr_item = ctx:get_cursor_item()
  for i, c in ipairs(curr_items) do
    items[i] = c
  end

  if opts.get_lines ~= nil then
    lines = opts.get_lines(items)
  else
    lines = {}
    for _, item in pairs(items) do
      table.insert(lines, item.data.text)
    end
  end

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, opts.filename or "deck_scratch")
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modified", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", opts.filetype or "", { buf = buf })

  -- Switch to the scratch buffer
  vim.api.nvim_set_current_buf(buf)

  -- Clears undo history
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("setlocal undolevels=-1")
    vim.cmd('exe "normal a \\<BS>\\<Esc>"')
    vim.cmd("setlocal undolevels=100")
  end)

  -- Create a keymap to close the buffer
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_hide(0)
  end, { buffer = buf })

  local autocmds = {}
  local saved = false
  -- Create autocmd for when buffer is saved
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      pattern = ("<buffer=%s>"):format(buf),
      callback = function()
        -- No longer allow buffer to be modified until save finishes
        vim.api.nvim_set_option_value("modified", false, { buf = buf })

        -- Get the new lines from the buffer
        local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        -- Pass new lines to the callback function
        saved = opts.save(items, new_lines)
        -- Hide the buffer after saving
        vim.api.nvim_win_hide(0)
        -- Show previous deck again
        ctx.show()
        ctx.execute()
      end,
    })
  )
  -- Make sure to cleanup autocmds if buffer is deleted or closed
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

  local new_pos = pos
  local feedkey = nil

  -- Move the cursor to specific position and then feed a key corresponding to the action
  if opts.action == "insert" then
    feedkey = "i"
  elseif opts.action == "insert_above" then
    feedkey = "O"
  elseif opts.action == "insert_below" then
    feedkey = "o"
  elseif opts.action == "insert_start" then
    feedkey = "I"
  elseif opts.action == "insert_end" then
    feedkey = "A"
  elseif opts.action == "delete_char" then
    feedkey = "x"
  elseif opts.action == "replace_char" then
    feedkey = "r"
  elseif opts.action == "delete_line" then
    feedkey = "dd"
  end

  if opts.get_pos ~= nil then
    new_pos = opts.get_pos(curr_item, new_pos)
  end
  vim.api.nvim_win_set_cursor(win, new_pos)
  if opts.get_feedkey ~= nil then
    feedkey = opts.get_feedkey(feedkey)
  end
  if feedkey ~= nil then
    vim.api.nvim_feedkeys(feedkey, "n", false)
  end
end

---@class Beez.u.deck.edit_actions_opts.opts
---@field disable? boolean
---@field action_name? string
---@field edit_opts? Beez.u.deck.edit_list_opts

---@class Beez.u.deck.edit_actions_opts
---@field prefix string
---@field edit_line fun(opts: Beez.u.deck.edit_list_opts): deck.Action
---@field edit_line_start? Beez.u.deck.edit_actions_opts.opts
---@field edit_line_end? Beez.u.deck.edit_actions_opts.opts
---@field insert? Beez.u.deck.edit_actions_opts.opts
---@field delete? Beez.u.deck.edit_actions_opts.opts
---@field write? Beez.u.deck.edit_actions_opts.opts
---@field delete_char? Beez.u.deck.edit_actions_opts.opts
---@field replace_char? Beez.u.deck.edit_actions_opts.opts
---@field insert_above? Beez.u.deck.edit_actions_opts.opts
---@field insert_below? Beez.u.deck.edit_actions_opts.opts

--- Convienence function for returning a set of deck actions for editing lines
---@param opts Beez.u.deck.edit_actions_opts
---@return deck.Action[]
function M.edit_actions(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    edit_line_start = {},
    edit_line_end = {},
    insert = {},
    delete = {},
    write = {},
    delete_char = {},
    replace_char = {},
    insert_above = {},
    insert_below = {},
  })
  local deck = require("deck")
  local actions = {}

  if not opts.edit_line_start.disable then
    local edit_line_start_name = opts.edit_line_start.action_name or opts.prefix .. "_edit_line_start"
    table.insert(actions, deck.alias_action("edit_line_start", edit_line_start_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = edit_line_start_name, action = "insert_start" },
      opts.edit_line_start.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.edit_line_end.disable then
    local edit_line_end_name = opts.edit_line_end.action_name or opts.prefix .. "_edit_line_end"
    table.insert(actions, deck.alias_action("edit_line_end", edit_line_end_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = edit_line_end_name, action = "insert_end" },
      opts.edit_line_end.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.insert.disable then
    local insert_name = opts.insert.action_name or opts.prefix .. "_insert"
    table.insert(actions, deck.alias_action("insert", insert_name))
    local edit_opts =
      vim.tbl_deep_extend("keep", { name = insert_name, action = "insert" }, opts.insert.edit_opts or {})
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.delete.disable then
    local delete_name = opts.delete.action_name or opts.prefix .. "_delete"
    table.insert(actions, deck.alias_action("delete", delete_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = delete_name, action = "delete_line" },
      opts.delete.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.write.disable then
    local write_name = opts.write.action_name or opts.prefix .. "_write"
    table.insert(actions, deck.alias_action("write", write_name))
    local edit_opts =
      vim.tbl_deep_extend("keep", { name = write_name, action = "edit" }, opts.write.edit_opts or {})
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.delete_char.disable then
    local delete_char_name = opts.delete_char.action_name or opts.prefix .. "_delete_char"
    table.insert(actions, deck.alias_action("delete_char", delete_char_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = delete_char_name, action = "delete_char" },
      opts.delete_char.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.replace_char.disable then
    local replace_char_name = opts.replace_char.action_name or opts.prefix .. "_replace_char"
    table.insert(actions, deck.alias_action("replace_char", replace_char_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = replace_char_name, action = "replace_char" },
      opts.replace_char.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.insert_above.disable then
    local insert_above_name = opts.insert_above.action_name or opts.prefix .. "_insert_above"
    table.insert(actions, deck.alias_action("insert_above", insert_above_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = insert_above_name, action = "insert_above" },
      opts.insert_above.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  if not opts.insert_below.disable then
    local insert_below_name = opts.insert_below.action_name or opts.prefix .. "_insert_below"
    table.insert(actions, deck.alias_action("open_keep", insert_below_name))
    local edit_opts = vim.tbl_deep_extend(
      "keep",
      { name = insert_below_name, action = "insert_below" },
      opts.insert_below.edit_opts or {}
    )
    table.insert(actions, opts.edit_line(edit_opts))
  end
  return actions
end

return M
