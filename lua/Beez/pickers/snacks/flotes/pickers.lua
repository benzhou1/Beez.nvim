local actions = require("Beez.pickers.snacks.flotes.actions")
local M = {}

--- Snacks picker for notes
---@param opts snacks.picker.Config?
function M.notes(opts)
  opts = opts or {}
  local flotes = require("Beez.flotes")
  local u = require("Beez.u")

  local function notes_finder(finder_opts, ctx)
    local cwd = flotes.config.notes_dir
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
    confirm = actions.confirm,
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
      delete = actions.delete,
      create_new_note = actions.create,
      create_new_note_template = actions.create_from_template,
      switch_to_list = actions.swtich_to_list,
    },
    win = {
      input = {
        keys = {
          ["<S-cr>"] = {
            "create_new_note",
            mode = { "n", "i" },
            desc = "Create new note",
          },
        },
      },
    },
  })
  require("snacks.picker").pick(picker_opts)
end

--- Snacks picker for templates
---@param opts snacks.picker.Config?
function M.templates(opts)
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
    confirm = actions.create,
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
      switch_to_list = actions.swtich_to_list,
    },
    win = {
      input = {
        keys = {
          ["<esc>"] = {
            "switch_to_list",
            mode = { "n" },
            desc = "Switch to list view",
          },
        },
      },
    },
  })
  require("snacks.picker").pick(picker_opts)
end

local add_link_finder_opts = {
  layout = {
    layout = {
      width = 80,
      height = 15,
      min_width = 80,
      min_height = 15,
      preview = false,
      relative = "cursor",
      backdrop = false,
      box = "vertical",
      border = "rounded",
      title = "{title} {live} {flags}",
      title_pos = "center",
      { win = "input", height = 1, border = "bottom" },
      { win = "list", border = "none" },
    },
  },
  format = function(item, _)
    return { { item.title } }
  end,
  actions = {
    close = actions.add_link_finder_close,
    cancel = actions.add_link_finder_close,
  },
  win = {
    input = {
      keys = {
        ["<tab>"] = {
          "confirm",
          mode = { "n", "i" },
          desc = "Confirm selection",
        },
        ["<S-CR>"] = {
          "create_new_note",
          mode = { "n", "i" },
          desc = "Create new note",
        },
      },
    },
  },
}

--- Inserts a link to a note at the cursor position
---@param opts table
function M.insert_link(opts)
  local f = require("Beez.flotes")
  local links = require("Beez.flotes.links")
  local picker_opts = vim.tbl_deep_extend("keep", opts or {}, add_link_finder_opts, {
    confirm = function(picker)
      picker:close()
      local item = picker:current()
      if not item then
        return
      end
      if f.config.open_in_float then
        ---@diagnostic disable-next-line: undefined-field
        f.states.float:focus()
      end
      links.add_link_at_cursor(item.file)
    end,
    actions = {
      create_new_note = actions.create_link,
    },
  })
  M.notes(picker_opts)
end

--- Replace selection with a link to a note
---@param opts table
function M.replace_with_link(opts)
  local u = require("Beez.u")
  -- Get the current visual selection
  local s, e = u.nvim.get_visual_selection_col_range()
  local line = vim.api.nvim_get_current_line()
  local f = require("Beez.flotes")
  local links = require("Beez.flotes.links")

  local picker_opts = vim.tbl_deep_extend("keep", opts or {}, add_link_finder_opts, {
    confirm = function(picker)
      picker:close()
      local item = picker:current()
      if not item then
        return
      end
      if f.config.open_in_float then
        ---@diagnostic disable-next-line: undefined-field
        f.states.float:focus()
      end
      links.replace_with_link(line, s, e, item.file)
    end,
    actions = {
      create_new_note = actions.replace_link(line),
    },
  })
  M.notes(picker_opts)
end

return M
