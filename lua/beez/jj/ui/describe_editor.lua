---@class Beez.jj.ui.DescEditor
---@field path string
---@field win number
---@field buf number
DescEditor = {}
DescEditor.__index = DescEditor

--- Instantiates a new DescEditor
---@return Beez.jj.ui.DescEditor
function DescEditor.new()
  local d = {}
  setmetatable(d, DescEditor)

  d.path = nil
  d.win = nil
  d.buf = nil
  return d
end

--- Renders a describe editor populated with given lines
---@param lines string[]
---@param opts {on_quit: fun(new_content: string[], saved: boolean)?, filter: fun(new_content: string[]): string[]}?
function DescEditor:render(lines, opts)
  -- Only one describe editor at a time
  if self.win ~= nil then
    vim.api.nvim_set_current_win(self.win)
    return
  end

  opts = opts or {}
  local NuiLine = require("nui.line")
  local u = require("beez.u")

  -- Create temp buffer
  self.path = vim.fn.tempname()
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].modifiable = true
  vim.bo[self.buf].readonly = false
  vim.bo[self.buf].buftype = ""
  -- Need a name to make it editable
  vim.api.nvim_buf_set_name(self.buf, self.path)

  -- Create a split for the editor window
  vim.cmd("vsplit")
  self.win = vim.api.nvim_get_current_win()

  for i, l in ipairs(lines) do
    local is_comment = l:startswith("JJ:")
    -- Highlight changes files differently
    local start, status, path = l:match("^(.-)([%a])%s+([%w%._%-]+/[%w%._%-/]+)$")
    local nl = NuiLine()
    if status ~= nil and path ~= nil then
      nl:append(start, "Comment")
      local hl = "String"
      if status == "A" then
        hl = "Added"
      end
      nl:append(status, hl)
      nl:append(" ", "String")
      nl:append(path, hl)
    elseif is_comment then
      nl:append(l, "Comment")
    else
      nl:append(l, "String")
    end
    nl:render(self.buf, -1, i)
  end

  vim.api.nvim_win_set_buf(self.win, self.buf)

  local saved = false
  -- Q to quit ignoring changes
  u.keymaps.set({
    {
      "q",
      function()
        saved = false
        vim.cmd("q")
      end,
      desc = "Quit and ignore changes",
      buffer = self.buf,
    },
  })

  -- Track whether buffer was saved or not
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(_)
      saved = true
    end,
    once = true,
    buffer = self.buf,
  })

  local autocmd_id
  -- Traack if window has been closed
  autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      -- Only want to do this for the editor window
      if args.match ~= tostring(self.win) then
        return
      end

      -- Clean up autocmd so that its one shot
      vim.api.nvim_del_autocmd(autocmd_id)

      -- Read the buffer lines
      local new_content = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
      if opts.filter ~= nil then
        new_content = opts.filter(new_content)
      end

      -- Cleanup the editor window
      self:cleanup()
      -- Only proceed if changes were saved
      if not saved then
        return
      end

      if opts.on_quit ~= nil then
        opts.on_quit(new_content, saved)
      end
    end,
  })
end

--- Cleans up the editor window
function DescEditor:cleanup()
  if self.win == nil then
    return
  end

  local is_modified = vim.api.nvim_get_option_value("modified", { buf = self.buf })
  -- Force discard changes and unload buffer
  if is_modified then
    vim.api.nvim_set_option_value("modified", false, { buf = self.buf })
    vim.cmd("bdelete! " .. self.buf)
  end
  -- Close the describe window
  pcall(vim.api.nvim_win_close, self.win, true)

  self.buf = nil
  self.win = nil
  self.path = nil
end

return DescEditor
