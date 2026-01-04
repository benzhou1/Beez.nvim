---@class Beez.jj.ui.JJLogTree
---@field editor_buf integer?
---@field editor_winid integer?
---@field winid integer
---@field buf integer
---@field tree NuiTree
JJLogTree = {}
JJLogTree.__index = JJLogTree

--- Instantiates a new JJLogTree
---@return Beez.jj.ui.JJLogTree
function JJLogTree.new()
  local NuiTree = require("nui.tree")
  local NuiLine = require("nui.line")
  local t = {}
  setmetatable(t, JJLogTree)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false

  t.editor_buf = nil
  t.editor_winid = nil

  t.winid = nil
  t.buf = buf
  t.tree = NuiTree({
    bufnr = buf,
    nodes = {},

    --- Use the line index or commit_id as a node identifier
    ---@param node NuiTree.Node
    ---@return string
    get_node_id = function(node)
      if node.data.commit_id then
        return node.data.commit_id
      end
      return node.data.i
    end,

    --- Reconstruct the log line from its data parts if its a commit line otherwise display it as normal if its a description
    ---@param node NuiTree.Node
    ---@return NuiLine | string
    prepare_node = function(node)
      local l = NuiLine()
      -- Normal line just display it
      if node.data.commit_id == nil then
        return node.text
      end
      -- Reconstruct line from its data parts
      l:append(node.data.marker, node.data.marker == "@" and "Added" or "String")
      l:append(node.data.first:gsub(node.data.marker, "", 1), "String")
      l:append(node.data.change_id, "String")
      l:append(" ", "String")
      l:append(node.data.author, "Added")
      l:append(" ", "String")
      l:append(node.data.date, "Comment")
      l:append(" ", "String")
      if node.data.branch ~= nil then
        l:append(node.data.branch, "String")
        l:append(" ", "String")
      end
      if node.data.ref ~= nil then
        l:append(node.data.ref, "Added")
        l:append(" ", "String")
      end
      l:append(node.data.commit_uuid, "Search")
      l:append(node.data.commit_id:gsub(node.data.commit_uuid, "", 1), "String")
      return l
    end,
  })
  return t
end

--- Opens a editor window as a vsplit with specified content and hooks for when editor is closed
---@param content string[]
---@param opts? {on_quit?: fun(new_content: string[], saved: boolean), filter?: fun(content: string[]): string[]}
function JJLogTree:_open_editor_window(content, opts)
  opts = opts or {}
  if not self:is_focused() then
    return
  end

  local u = require("Beez.u")
  -- A new edit is being made, clean up any existing editor window
  if self.editor_winid ~= nil then
    self:cleanup({ buf = false })
  end

  -- Create a split for the editor window
  vim.cmd("vsplit")
  self.editor_winid = vim.api.nvim_get_current_win()
  self.editor_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.editor_buf].modifiable = true
  vim.bo[self.editor_buf].readonly = false

  vim.schedule(function()
    local tmpname = vim.fn.tempname()
    -- Populate the buffer with existing description
    vim.api.nvim_buf_set_lines(self.editor_buf, 0, -1, false, content)
    vim.api.nvim_win_set_buf(self.editor_winid, self.editor_buf)
    -- Make it a normal buffer with a name so that it can be saved
    vim.bo[self.editor_buf].buftype = ""
    vim.api.nvim_buf_set_name(self.editor_buf, tmpname)

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
        buffer = self.editor_buf,
      },
    })

    -- Track whether buffer was saved or not
    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = function(_)
        saved = true
      end,
      once = true,
      buffer = self.editor_buf,
    })

    local autocmd_id
    -- Traack if window has been closed
    autocmd_id = vim.api.nvim_create_autocmd("WinClosed", {
      callback = function(args)
        -- Only want to do this for the editor window
        if args.match ~= tostring(self.editor_winid) then
          return
        end

        -- Clean up autocmd so that its one shot
        vim.api.nvim_del_autocmd(autocmd_id)

        -- Read the buffer lines
        local new_content = vim.api.nvim_buf_get_lines(self.editor_buf, 0, -1, false)
        if opts.filter ~= nil then
          new_content = opts.filter(new_content)
        end

        -- Cleanup the editor window
        self:cleanup({ buf = false })
        -- Only proceed if changes were saved
        if not saved then
          return
        end

        if opts.on_quit ~= nil then
          opts.on_quit(new_content, saved)
        end
      end,
    })
  end)
end

-----------------------------------------------------------------------------------------------
--- STATE
-----------------------------------------------------------------------------------------------
--- Gets the commit id for the current jj log line
---@return string?
function JJLogTree:commit_id()
  local node = self.tree:get_node()
  if node == nil then
    return
  end

  return node.data.commit_id
end

-----------------------------------------------------------------------------------------------
--- ACTIONS
-----------------------------------------------------------------------------------------------
--- Renders jj log tree
---@param cb? fun()
function JJLogTree:render(cb)
  local NuiTree = require("nui.tree")
  local commands = require("Beez.jj.commands")

  -- Get output from jj log
  commands.log(function(err, log_lines)
    if err ~= nil then
      return
    end

    local lines = vim.split(log_lines, "\n")
    local nodes = {}
    for _, l in ipairs(lines) do
      -- Gets the first part of the line up to the first alpha numeric char
      local first, rest = l:match("^(.-[%W_]*)([%w].*)$")
      -- Split up the rest of the line by space delimiter
      local groups = vim.split(rest or "", " ")

      local marker, change_id, author, date, time, branch, ref, commit_id, commit_uuid
      marker = first ~= nil and vim.split(first, " ")[1] or nil

      -- Use marker symbol to determine if its a commit line or a description line
      if marker == "◆" or marker == "@" or marker == "○" then
        change_id = groups[1]
        author = groups[2]
        date = groups[3]
        time = groups[4]
        -- Sometimes just the ref is present
        if #groups == 6 then
          ref = groups[5]
          if not ref:contains("()") then
            branch = ref
            ref = nil
          end
          commit_id = groups[6]
        -- Sometimes branch and ref are present
        elseif #groups == 7 then
          branch = groups[5]
          ref = groups[6]
          commit_id = groups[7]
        else
          commit_id = groups[5]
        end
      end

      -- Extract the unique commit uuid from the commit id
      if commit_id ~= nil then
        local g = vim.split(commit_id, "%[")
        commit_id = g[1]
        commit_uuid = vim.split(g[2], "%]")[1]
      end
      if date ~= nil then
        date = date .. " " .. time
      end

      local node = NuiTree.Node({
        text = l,
        data = {
          i = #nodes + 1,
          first = first,
          marker = marker,
          author = author,
          change_id = change_id,
          commit_uuid = commit_uuid,
          date = date,
          commit_id = commit_id,
          branch = branch,
          ref = ref,
        },
      })
      table.insert(nodes, node)
    end

    vim.schedule(function()
      self.tree:set_nodes(nodes)
      self.tree:render()
      if self.winid == nil then
        self.winid = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(self.winid, self.buf)
        vim.wo[self.winid].number = false
        vim.wo[self.winid].relativenumber = false
        vim.api.nvim_win_set_height(self.winid, 15)
      end
      if cb ~= nil then
        cb()
      end
    end)
  end)
end

--- Checks whether the log view is focused
---@return boolean
function JJLogTree:is_focused()
  local curr_win = vim.api.nvim_get_current_win()
  return curr_win == self.winid
end

--- Creates a new jj commit before or after the current commit under the cursor
---@param opts? {before?: string, after?: string}
function JJLogTree:new_commit(opts)
  opts = opts or {}
  local commands = require("Beez.jj.commands")
  commands.new(function(err)
    if err ~= nil then
      return
    end
    self:render()
  end, { before = opts.before, after = opts.after })
end

--- Runs jj undo
function JJLogTree:undo()
  local commands = require("Beez.jj.commands")
  commands.undo(function(err)
    if err ~= nil then
      return
    end
    self:render()
  end)
end

--- Squashes current working copy into current commit under the cursor and imitate the commit message in a split
function JJLogTree:squash()
  -- JJ: Enter a description for the combined commit.
  -- JJ: Description from the destination commit:
  -- fix(u.cmds): Cleanup cmds to use u.cmds instead of Beez.cmds
  -- fix(cmds.neovide): Cleanup open_neohub and open_flotes
  --
  -- JJ: Description from source commit:
  -- first line
  -- second line
  -- third line
  --
  -- JJ: Change ID: qpymynyn
  -- JJ: This commit contains the following changes:
  -- JJ:     M lua/Beez/cmds/init.lua
  -- JJ:     M lua/Beez/cmds/neovide.lua
  -- JJ:     M lua/Beez/jj/commands.lua
  -- JJ:     M lua/Beez/jj/init.lua
  -- JJ:     M lua/Beez/jj/ui/log_tree.lua
  -- JJ:     M lua/Beez/jj/ui/status_tree.lua
  -- JJ:     M lua/Beez/jj/ui/view.lua
  -- JJ:     M lua/Beez/jj/ui/vscode_diff.lua
  -- JJ:
  -- JJ: Lines starting with "JJ:" (like this one) will be removed.

  local u = require("Beez.u")
  local commands = require("Beez.jj.commands")
  local commit_id = self:commit_id()
  if commit_id == nil then
    return
  end

  -- Get the description of the source commit
  local log_source_desc_opts = { r = "@", T = "description", no_graph = true, wait = false }
  local log_source_desc_sys = commands.log(nil, log_source_desc_opts)
  -- Get the description of the dest commit
  local log_dest_desc_opts = { r = commit_id, T = "description", no_graph = true, wait = false }
  local log_dest_desc_sys = commands.log(nil, log_dest_desc_opts)
  -- Get the changed files from the source commit
  local log_diff_source_opts = { no_graph = true, r = "@", summary = true, wait = false }
  local log_diff_source_sys = commands.diff(nil, log_diff_source_opts)
  -- Get the changed files from the dest commit
  local log_diff_dest_opts = { no_graph = true, r = commit_id, summary = true, wait = false }
  local log_diff_dest_sys = commands.diff(nil, log_diff_dest_opts)
  -- Shouldnt happen but just in case
  if
    log_source_desc_sys == nil
    or log_dest_desc_sys == nil
    or log_diff_source_sys == nil
    or log_diff_dest_sys == nil
  then
    return
  end

  --- Wait for a command to finish and log error. If error try to cancel the rest of the commands
  ---@param sys vim.SystemObj
  ---@param rest vim.SystemObj[]
  ---@return string?
  local function wait_for_sys(sys, rest)
    local sys_comp = sys:wait()
    if sys_comp.stderr ~= nil and sys_comp.stderr ~= "" then
      vim.notify(
        "Error trying to get commit description for squash: " .. sys_comp.stderr,
        vim.log.levels.WARN
      )
      for _, s in ipairs(rest) do
        s:kill(9)
      end
      return
    end
    return sys_comp.stdout
  end

  -- Wait for everything to finish
  local log_source_desc = wait_for_sys(log_source_desc_sys, {
    log_dest_desc_sys,
    log_diff_source_sys,
    log_diff_dest_sys,
  })
  local log_dest_desc = wait_for_sys(log_dest_desc_sys, {
    log_source_desc_sys,
    log_diff_source_sys,
    log_diff_dest_sys,
  })
  local log_diff_source = wait_for_sys(log_diff_source_sys, {
    log_source_desc_sys,
    log_dest_desc_sys,
    log_diff_dest_sys,
  })
  local log_diff_dest = wait_for_sys(log_diff_dest_sys, {
    log_source_desc_sys,
    log_dest_desc_sys,
    log_diff_source_sys,
  })
  -- Handle any errors
  if
    log_source_desc == nil
    or log_dest_desc == nil
    or log_diff_source == nil
    or log_diff_dest == nil
  then
    return
  end

  -- Create the editor content
  local lines = {
    "JJ: Enter a description for the combined commit.",
    "JJ: Description from the destination commit:",
  }
  u.tables.extend(lines, vim.split(log_dest_desc, "\n"))
  table.insert(lines, "JJ: Description from he source commit:")
  u.tables.extend(lines, vim.split(log_source_desc, "\n"))
  table.insert(lines, "JJ: This commit contains the following changes:")

  -- Insert unique changed files from source and dest commit
  local unique_files = {}
  for _, l in ipairs(u.tables.extend(vim.split(log_diff_dest, "\n"), vim.split(log_diff_source, "\n"))) do
    local s = vim.split(l, " ")
    if s[2] ~= nil then
      unique_files[s[2]] = s[1]
    end
  end
  for fp, st in pairs(unique_files) do
    if fp ~= "" then
      table.insert(lines, "JJ:\t" .. st .. " " .. fp)
    end
  end
  table.insert(lines, 'JJ: Lines starting with "JJ:" (like this one) will be removed.')

  self:_open_editor_window(lines, {
    on_quit = function(new_lines, saved)
      print("🪵 new_lines =", vim.inspect(new_lines))
      if not saved then
        return
      end

      -- Use jj squash with -m
      commands.squash(function(err)
        if err ~= nil then
          return
        end
        self:render()
      end, { m = table.concat(new_lines, "\n"), to = commit_id })
    end,
    filter = function(content)
      -- Filter out JJ: lines
      local filtered = {}
      for _, l in ipairs(content) do
        if not l:match("^JJ:") and l ~= "" then
          table.insert(filtered, l)
        end
      end
      return filtered
    end,
  })
end

--- Edits the current commit under the cursor
function JJLogTree:edit()
  local commands = require("Beez.jj.commands")
  local commit_id = self:commit_id()
  if commit_id == nil then
    return
  end

  commands.edit(commit_id, function(err)
    if err ~= nil then
      return
    end
    self:render()
  end)
end

--- Describes the current commit or description under the cursor
--- Creates a separate window for editing the description
--- Description is only applied if changes are saved and quit
function JJLogTree:describe(opts)
  opts = opts or {}
  if not self:is_focused() then
    return
  end

  local commands = require("Beez.jj.commands")
  local commit_id = opts.commit_id or self:commit_id()

  -- On a description line attempt to find the commit line above it
  if commit_id == nil then
    local pos = vim.api.nvim_win_get_cursor(self.winid)
    while pos[1] > 1 do
      pos[1] = pos[1] - 1
      local node = self.tree:get_node(pos[1])
      if node == nil then
        return
      end
      if node.data.commit_id ~= nil then
        commit_id = node.data.commit_id
        break
      end
    end
  end

  if commit_id == nil then
    vim.notify("No commit found to describe", vim.log.levels.WARN)
    return
  end
  -- Grab the existing description for the commit by using jj log
  local log_opts = { r = commit_id or "@", T = "builtin_draft_commit_description", no_graph = true }
  commands.log(function(err, stdout)
    if err ~= nil then
      return
    end

    vim.schedule(function()
      local lines = vim.split(stdout, "\n")
      -- Last line is empty, remove itbuiltin_draft_commit_description
      table.remove(lines)
      -- Add instruction line for JJ
      table.insert(lines, 'JJ: Lines starting with "JJ:" (like this one) will be removed.')

      self:_open_editor_window(lines, {
        on_quit = function(new_lines, saved)
          if not saved then
            return
          end

          -- Use jj describe with -m to set the new description
          commands.describe(commit_id, function(derr)
            if derr ~= nil then
              return
            end
            self:render()
          end, { m = table.concat(new_lines, "\n") })
        end,
        filter = function(content)
          -- Filter out JJ: lines
          local filtered = {}
          for _, l in ipairs(content) do
            if not l:match("^JJ:") then
              table.insert(filtered, l)
            end
          end
          return filtered
        end,
      })
    end)
  end, log_opts)
end

--- Cleans up the describe window if it was created and log buffer
---@param opts? {buf?: boolean}
function JJLogTree:cleanup(opts)
  opts = opts or {}
  if opts.buf ~= false then
    -- Not sure why but we need to remove the buffer otherwise nvim thinks there is a change
    vim.api.nvim_buf_delete(self.buf, { force = true })
  end

  if self.editor_winid == nil then
    return
  end

  local is_modified = vim.api.nvim_get_option_value("modified", { buf = self.editor_buf })
  -- Force discard changes and unload buffer
  if is_modified then
    vim.api.nvim_set_option_value("modified", false, { buf = self.editor_buf })
    vim.cmd("bdelete! " .. self.editor_buf)
  end
  -- Close the describe window
  pcall(vim.api.nvim_win_close, self.editor_winid, true)

  self.editor_buf = nil
  self.editor_winid = nil
end

--- Maps default key bindings to the view
---@param view Beez.jj.ui.JJView
function JJLogTree:map(view)
  local u = require("Beez.u")
  local keymaps = {
    quit = {
      "q",
      function()
        view:quit()
      end,
    },
    new_above = {
      "O",
      function()
        local commit_id = self:commit_id()
        if commit_id == nil then
          return
        end
        self:new_commit({ after = commit_id })
        vim.notify("Created new commit above", vim.log.levels.INFO)
      end,
    },
    new_below = {
      "o",
      function()
        local commit_id = self:commit_id()
        if commit_id == nil then
          return
        end
        self:new_commit({ before = commit_id })
        vim.notify("Created new commit below", vim.log.levels.INFO)
      end,
    },
    undo = {
      "u",
      function()
        self:undo()
        vim.notify("Undo", vim.log.levels.INFO)
      end,
    },
    squash = {
      "s",
      function()
        self:squash()
      end,
    },
    edit = {
      "<cr>",
      function()
        self:edit()
      end,
    },
    describe_a = {
      "A",
      function()
        self:describe()
      end,
    },
    describe_i = {
      "I",
      function()
        self:describe()
      end,
    },
  }

  for _, k in pairs(keymaps) do
    u.keymaps.set({
      vim.tbl_deep_extend("keep", { buffer = self.buf }, k),
    })
  end
end

return JJLogTree
