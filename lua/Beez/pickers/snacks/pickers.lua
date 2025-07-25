local actions = require("Beez.pickers.snacks.actions")
local u = require("Beez.u")
local M = {}
local BONUS_FRECENCY = 8
local BONUS_CWD = 10

--- Custom smart picker
--- Combines buffers, oldfiles, and files
--- When no query is present buffers will be listed first in laseused order, followed by oldfiles and files
--- sorted by frequency and cwd
--- When query is present everything will be sorted by frecency
---@param opts table
---@type snacks.picker.finder
function M.smart(opts, ctx)
  local frecency = require("snacks.picker.core.frecency").new()
  local sources_config = require("snacks.picker.config.sources")
  local buffers_source = require("snacks.picker.source.buffers")
  local recent_source = require("snacks.picker.source.recent")
  local files_source = require("snacks.picker.source.files")
  local bufname = vim.api.nvim_buf_get_name(0)
  ---@diagnostic disable-next-line: param-type-mismatch>
  local cwd = vim.fs.normalize(opts.cwd or (vim.uv or vim.loop).cwd())

  -- Prevent duplicates
  local done = {}

  --- Apply frecency score to items
  ---@param item snacks.picker.Item
  ---@return boolean
  local function apply_frecency_score(item)
    local path = Snacks.picker.util.path(item)
    if not path or done[path] or path == bufname then
      return true
    end
    done[path] = true
    local score = (1 - 1 / (1 + frecency:get(item))) * BONUS_FRECENCY
    item.frecency = score
    if path:find(cwd, 1, true) then
      score = score + BONUS_CWD
    end
    item.score_add = score
    return false
  end

  -- All items
  local items = {}
  -- Get buffer items
  local buffer_opts = vim.tbl_extend("keep", sources_config.buffers, opts.buffer_opts or {})
  local buffer_items = buffers_source.buffers(buffer_opts, ctx)
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, item in ipairs(buffer_items) do
    local skip = apply_frecency_score(item)
    if not skip then
      table.insert(items, item)
    end
  end
  u.nvim.sort_bufs_by_lastused(items)

  -- oldfiles and files only
  local file_items = {}
  -- Get oldfiles
  local recent_opts = vim.tbl_extend("keep", sources_config.recent, opts.recent_opts or {})
  local gen_recent_items = recent_source.recent(recent_opts, ctx)

  ---@diagnostic disable-next-line: missing-parameter
  gen_recent_items(function(item)
    local skip = apply_frecency_score(item)
    if not skip then
      table.insert(file_items, item)
    end
  end)

  -- Get files
  local file_opts = vim.tbl_extend(
    "keep",
    { hidden = true, debug = { files = false } },
    sources_config.files,
    opts.file_opts or {}
  )
  local find = files_source.files(file_opts, ctx)
  -- Files finder is async so we gotta hack this so that we cna get files synchronously
  local async = require("snacks.picker.util.async")
  local task
  task = async.Async.new(function()
    ---@async
    find(function(item)
      local skip = apply_frecency_score(item)
      if not skip then
        table.insert(file_items, item)
      end
      ---@diagnostic disable-next-line: redundant-parameter
    end, task)
  end)
  task:wait()

  -- Sort oldfiles and files by frecency
  table.sort(file_items, function(a, b)
    return a.score_add > b.score_add
  end)
  -- Added sorted file items to all items
  for _, item in ipairs(file_items) do
    table.insert(items, item)
  end

  return ctx.filter:filter(items)
end

--- Find but for directories, opens in oil float
function M.dirs(opts, ctx)
  return require("snacks.picker.source.proc").proc({
    opts,
    {
      cmd = "fd",
      args = { "-td", "." },
      transform = function(item)
        item.file = item.text
      end,
    },
  }, ctx)
end

--- Picker for searching tasks
function M.tasks(opts)
  opts = opts or {}
  local show_done = true
  local cur_win = vim.api.nvim_get_current_win()
  local utils = require("plugins.oil.adapters.tasks.utils")
  local function tasks_finder(_, ctx)
    local tasks = require("plugins.oil.adapters.tasks.utils").get_tasks()
    local lines = {}
    for _, t in tasks:lines() do
      if utils.should_show_task(t, { show_done = show_done }) then
        local item = {
          text = t:line({ show_fields = false, show_hyphen = false }),
          id = t.id,
        }
        table.insert(lines, item)
      end
    end
    return ctx.filter:filter(lines)
  end

  local function confirm(opts)
    opts = opts or {}
    return function(picker)
      local tasks = require("plugins.oil.adapters.tasks.utils").get_tasks()
      local item = picker:selected({ fallback = true })[1]
      local task = tasks:get(item.id)
      assert(task ~= nil, "Task not found:" .. item.id)
      local path = ""
      local parent = task.parent
      while parent ~= nil do
        if parent.text ~= "root" then
          path = tostring(parent.id) .. "/" .. path
        end
        parent = parent.parent
      end
      picker:close()

      local url = "oil-tasks:///" .. path
      if opts.enter then
        vim.api.nvim_win_call(cur_win, function()
          vim.cmd("e " .. url .. tostring(task.id) .. "/")
        end)
      else
        vim.api.nvim_win_call(cur_win, function()
          vim.cmd("e " .. url)
          require("oil.view").set_last_cursor(url, task.text)
        end)
      end
    end
  end

  require("snacks.picker").pick({
    finder = tasks_finder,
    format = function(item, _)
      return { { item.text } }
    end,
    layout = {
      ---@diagnostic disable-next-line: assign-type-mismatch
      preview = false,
    },
    preview = "none",
    supports_live = false,
    confirm = confirm(),
    actions = {
      view_task = function(picker)
        confirm({ enter = true })(picker)
      end,
      toggle_show_done = function(picker)
        show_done = not show_done
        picker:close()

        require("u").async.delayed({
          delay = 250,
          cb = function()
            require("snacks.picker").resume()
          end,
        })
      end,
    },
    win = {
      input = {
        keys = {
          ["<S-CR>"] = {
            "view_task",
            mode = { "n", "i" },
            desc = "View the tasks's children",
          },
          ["<C-g>"] = {
            "toggle_show_done",
            mode = { "n", "i" },
            desc = "Toggle showing done tasks",
          },
        },
      },
    },
  })
end

--- Picker for dap breakpoints
function M.breakpoints(opts)
  local function breakpoint_finder(_, ctx)
    local breakpoints = require("dap.breakpoints").get()
    local items = {}
    for bufnr, bps in pairs(breakpoints) do
      local file = vim.api.nvim_buf_get_name(bufnr)
      for _, bp in ipairs(bps) do
        local item = {
          text = file .. ":" .. bp.line,
          buf = bufnr,
          file = file,
          pos = { bp.line, 0 },
        }
        table.insert(items, item)
      end
    end
    return ctx.filter:filter(items)
  end

  local pick_opts = vim.tbl_deep_extend("keep", opts or {}, {
    finder = breakpoint_finder,
    format = "file",
    actions = {
      switch_to_list = function(picker)
        require("snacks.picker.actions").cycle_win(picker)
        require("snacks.picker.actions").cycle_win(picker)
      end,
      delete = function(picker)
        local item = picker:selected({ fallback = true })[1]
        if item == nil then
          return
        end

        require("dap.breakpoints").remove(item.buf, item.pos[1])
        require("persistent-breakpoints.api").breakpoints_changed_in_current_buffer(item.file, item.buf)
        picker:close()
        picker:resume()
      end,
    },
    win = {
      input = {
        keys = {
          ["<esc>"] = {
            "switch_to_list",
            mode = { "i" },
            desc = "Switch to the list view",
          },
        },
      },
      list = {
        keys = {
          ["a"] = {
            "toggle_focus",
            desc = "Focus input",
          },
          ["dd"] = {
            "delete",
            desc = "Delete breakpoint",
          },
        },
      },
    },
  })
  require("snacks.picker").pick(pick_opts)
end

--- Snacks picker for notes
---@param opts snacks.picker.Config?
function M.notes_files(opts)
  opts = opts or {}
  local f = require("Beez.flotes")

  local function notes_finder(finder_opts, ctx)
    local cwd = f.config.notes_dir
    local cmd = "rg"
    local args = {
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--max-columns=500",
      "--max-columns-preview",
      "-g",
      "!.git",
    }
    local pattern, pargs = Snacks.picker.util.parse(ctx.filter.search)
    vim.list_extend(args, pargs)
    args[#args + 1] = "--"
    table.insert(args, pattern)
    table.insert(args, cwd)

    -- If the search is empty, show all notes
    if ctx.filter.search == "" then
      local new_args = { "^#", "-m", "1" }
      for _, v in ipairs(args) do
        table.insert(new_args, v)
      end
      table.insert(new_args, ctx.filter.search)
      args = new_args
    end
    return require("snacks.picker.source.proc").proc({
      finder_opts,
      {
        notify = false, -- never notify on grep errors, since it's impossible to know if the error is due to the search pattern
        cmd = cmd,
        args = args,
        ---@param item snacks.picker.finder.Item
        transform = function(item)
          local file, line, col, text = item.text:match("^(.+):(%d+):(%d+):(.*)$")
          if not file then
            if not item.text:match("WARNING") then
              Snacks.notify.error("invalid grep output:\n" .. item.text)
            end
            return false
          else
            local title = u.os.read_first_line(file)
            item.line = line
            item.title = title
            item.gtext = text
            item.file = file
            item.pos = { tonumber(line), tonumber(col) - 1 }
          end
        end,
      },
    }, ctx)
  end

  local picker_opts = vim.tbl_deep_extend("keep", opts, {
    finder = notes_finder,
    format = function(item, ctx)
      local parts = {}
      table.insert(parts, { item.title, "SnacksPickerFile" })
      if ctx.finder.filter.search ~= "" then
        if item.title ~= item.gtext then
          table.insert(parts, { " ", "String" })
          table.insert(parts, { item.gtext, "String" })
        end
      end
      return parts
    end,
    confirm = actions.note_confirm,
    matcher = {
      sort_empty = true,
      filename_bonus = false,
      file_pos = false,
      frecency = true,
    },
    sort = {
      fields = { "score:desc" },
    },
    regex = true,
    show_empty = true,
    live = true,
    supports_live = true,
    actions = {
      delete = actions.note_delete,
      create_new_note = actions.note_create,
      create_new_note_template = actions.note_template_create,
      switch_to_list = actions.note_switch_to_list,
    },
  })
  require("snacks.picker").pick(picker_opts)
end

--- Snacks picker for templates
---@param opts snacks.picker.Config?
function M.note_templates(opts)
  opts = opts or {}
  local f = require("Beez.flotes")
  local function templates_finder(finder_opts, ctx)
    local items = {}
    for name, template in pairs(f.config.templates.templates) do
      table.insert(items, {
        text = name,
        template = template.template,
        preview = { text = template.template },
        file = "flotes.templates.finder." .. name,
      })
    end
    return ctx.filter:filter(items)
  end

  local picker_opts = vim.tbl_deep_extend("keep", opts, {
    finder = templates_finder,
    confirm = actions.note_template_create,
    format = function(item, _)
      return { { item.text } }
    end,
    preview = "preview",
    matcher = {
      sort_empty = true,
      filename_bonus = false,
      file_pos = false,
      frecency = true,
    },
    sort = {
      fields = { "score:desc" },
    },
    show_empty = true,
    actions = {
      switch_to_list = actions.note_switch_to_list,
    },
  })
  require("snacks.picker").pick(picker_opts)
end

return M
