local M = {
  spec = {
    dir = "~/Projects/nvim_forks/nvim-deck",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
}

--- Returns deck items that are visually selected.
---@param ctx deck.Context
---@return deck.Item[]
function M.get_visually_selected_items(ctx)
  local s, e = require("u").nvim.get_visual_selection_row_range()
  local items = {}
  for i = s, e do
    local item = ctx.get_rendered_items()[i]
    if item then
      table.insert(items, item)
    end
  end
  return items
end

--- Select items in the visual selection.
---@param ctx deck.Context
---@param opts? {toggle: boolean}
function M.select_items_in_visual_selection(ctx, opts)
  opts = opts or {}
  local items = M.get_visually_selected_items(ctx)
  for _, item in ipairs(items) do
    if opts.toggle then
      ctx.set_selected(item, not ctx.get_selected(item))
    else
      ctx.set_selected(item, true)
    end
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
end

local function keymaps(ctx)
  local u = require("Beez.u")
  local deck = require("deck")

  ctx.keymap("n", "?", deck.action_mapping("choose_action"))
  ctx.keymap("n", "R", deck.action_mapping("refresh"))
  ctx.keymap("n", "a", deck.action_mapping("prompt"))
  ctx.keymap("n", "<tab>", deck.action_mapping("toggle_select"))
  -- ctx.keymap("n", "vag", deck.action_mapping("toggle_select_all"))
  ctx.keymap("n", "P", deck.action_mapping("toggle_preview_mode"))
  ctx.keymap("n", "p", deck.action_mapping("paste"))
  ctx.keymap("n", "dd", deck.action_mapping("delete"))
  ctx.keymap("n", "<cr>", deck.action_mapping("default"))
  ctx.keymap("n", "<s-cr>", deck.action_mapping("alt_default"))
  ctx.keymap("n", "-", deck.action_mapping("prev_default"))
  ctx.keymap("n", "o", deck.action_mapping("open_keep"))
  ctx.keymap("n", "O", deck.action_mapping("insert_above"))
  ctx.keymap("n", "e", deck.action_mapping("write"))
  ctx.keymap("n", "i", deck.action_mapping("insert"))
  ctx.keymap("n", "I", deck.action_mapping("edit_line_start"))
  ctx.keymap("n", "A", deck.action_mapping("edit_line_end"))
  ctx.keymap("n", "x", deck.action_mapping("delete_char"))
  ctx.keymap("n", "r", deck.action_mapping("replace_char"))
  ctx.keymap("n", "<c-s>", deck.action_mapping("open_split"))
  ctx.keymap("n", "<c-v>", deck.action_mapping("open_vsplit"))
  ctx.keymap("n", "<C-u>", deck.action_mapping("scroll_preview_up"))
  ctx.keymap("n", "<C-d>", deck.action_mapping("scroll_preview_down"))
  ctx.keymap("n", "q", deck.action_mapping("hide"))
  ctx.keymap("n", "<esc>", deck.action_mapping("hide"))
  ctx.keymap("n", "gx", deck.action_mapping("open_external"))
  ctx.keymap("n", "gX", deck.action_mapping("open_parent_external"))
  ctx.keymap({ "n", "c" }, "<c-g>", deck.action_mapping("toggle1"))
  ctx.keymap({ "n", "c" }, "<c-t>", deck.action_mapping("toggle2"))
  ctx.keymap({ "n" }, "<C-i>", function(_)
    vim.cmd("wincmd p")
  end)

  ctx.keymap("x", "<tab>", function()
    M.select_items_in_visual_selection(ctx, { toggle = true })
  end)

  ctx.keymap("x", "d", function()
    M.select_items_in_visual_selection(ctx)
    deck.action_mapping("delete")(ctx)
  end)

  -- If you want to start the filter by default, call ctx.prompt() here
  if ctx.get_config().start_prompt then
    ctx.prompt()
  end
end

local function global_actions()
  local deck = require("deck")
  deck.register_action({
    name = "hide",
    execute = function(ctx)
      ctx.hide()
      vim.schedule(function()
        -- If focus ends up on noneckpain buffer then switch to the next window
        if vim.o.filetype == "no-neck-pain" then
          pcall(vim.cmd.wincmd, "w")
        end
        -- Need to cleanup neo image after deck is closed
        local ok, image = pcall(require, "neo-img.image")
        if ok then
          image.Delete()
        end
      end)
    end,
  })
  deck.register_action({
    name = "prev_default",
    execute = function(_) end,
  })
end

local function autocmds(opts)
  opts = opts or {}

  -- Setup autocmds
  local augroup = vim.api.nvim_create_augroup("deck.easy", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      local bufname = vim.api.nvim_buf_get_name(0)
      local valid = vim.fn.filereadable(bufname) == 1
      if opts.flotes_dir then
        local ignore_patterns = {
          ".*%.cache",
          opts.flotes_dir .. ".*",
        }
        for _, pattern in ipairs(ignore_patterns) do
          valid = valid and not bufname:match(pattern)
          if not valid then
            break
          end
        end
      end

      if not valid then
        return
      end

      -- Add the current file to recent files
      local recent_files = require("deck.builtin.source.recent_files")
      recent_files:add(vim.fs.normalize(bufname))

      if opts.sort_bufferline then
        -- Sort bufferline by recent files
        local bufferline_state = require("bufferline.state")
        if next(bufferline_state.components) == nil then
          return
        end

        local recent_map = {}
        for i, path in ipairs(recent_files.file.contents) do
          recent_map[path] = i
        end
        require("bufferline").sort_by(function(a, b)
          local a_idx = 1
          local b_idx = 1
          if recent_map[a.path] then
            a_idx = recent_map[a.path]
          end
          if recent_map[b.path] then
            b_idx = recent_map[b.path]
          end
          return a_idx > b_idx
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = augroup,
    callback = function(e)
      ---@diagnostic disable-next-line: undefined-field
      local dir = e.cwd
      for _, pattern in ipairs(ignore_patterns) do
        if not dir:match(pattern) then
          return
        end
      end
      require("deck.builtin.source.recent_dirs"):add(dir)
    end,
  })
end

---@param config_opts? {autocmds?: boolean, sort_bufferline?: boolean, flotes_dir?: string}
function M.spec.config(_, opts, config_opts)
  config_opts = config_opts or {}
  local deck = require("deck")

  -- Apply pre-defined easy settings.
  -- For manual configuration, refer to the code in `deck/easy.lua`.
  require("deck.easy").setup({
    setup_recent_autocmds = false,
  })
  deck.setup(opts)

  -- Global actions
  global_actions()

  -- Set up buffer-specific key mappings for nvim-deck.
  vim.api.nvim_create_autocmd("User", {
    pattern = "DeckStart",
    callback = function(e)
      local ctx = e.data.ctx --[[@as deck.Context]]
      keymaps(ctx)
    end,
  })

  if config_opts.autocmds ~= false then
    autocmds({ sort_bufferline = config_opts.sort_bufferline, flotes_dir = config_opts.flotes_dir })
  end
end

M.spec.opts = {
  default_start_config = {
    view = function()
      return require("deck.builtin.view.bottom_picker")({
        max_height = math.floor(vim.o.lines * 0.25),
        static_height = math.floor(vim.o.lines * 0.25),
      })
    end,
    start_prompt = true,
    preview = {
      win_opts = function(curr_height)
        local height = math.floor(vim.o.lines * 0.25)
        return {
          height = height,
          width = vim.o.columns,
          row = vim.o.lines - curr_height - height - 3,
          col = 0,
        }
      end,
      set_title = function(win_config, filename)
        local u = require("Beez.u")
        win_config.title = filename and u.paths.basename(filename)
        win_config.title_pos = "center"
      end,
      win_hl = "Normal:Normal,FloatBorder:Comment,FloatTitle:CursorLineNr,FloatFooter:Normal",
    },
    before_prompt_cb = function(ctx)
      local u = require("Beez.u")
      local deck = require("deck")

      -- Enter will apply default action to the current item
      ctx.keymap({ "c" }, "<CR>", function(ctx)
        local cmdtype = vim.fn.getcmdtype()
        if cmdtype == "/" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
          return
        end

        if vim.fn.mode() == "c" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "t", false)
          u.async.delayed({
            delay = 100,
            cb = function()
              deck.action_mapping("default")(ctx)
            end,
          })
          return
        end

        deck.action_mapping("default")(ctx)
      end)

      -- Down will cancel input and move to the next item
      ctx.keymap({ "c" }, "<down>", function(_)
        if vim.fn.mode() == "c" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "t", false)
        end
        u.async.delayed({
          delay = 100,
          cb = function()
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes("<down>", true, false, true),
              "t",
              false
            )
          end,
        })
      end)

      -- Shift-Enter will apply alt-default action to the current item
      ctx.keymap({ "c" }, "<S-CR>", function(ctx)
        if vim.fn.mode() == "c" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "t", false)
        end
        u.async.delayed({
          delay = 100,
          cb = function()
            deck.action_mapping("alt_default")(ctx)
          end,
        })
      end)
    end,

    after_prompt_cb = function(ctx)
      pcall(vim.keymap.del, { "c" }, "<down>", { buffer = ctx.buf })
      pcall(vim.keymap.del, { "c" }, "<cr>", { buffer = ctx.buf })
      pcall(vim.keymap.del, { "c" }, "<s-cr>", { buffer = ctx.buf })
    end,
  },
}

return M
