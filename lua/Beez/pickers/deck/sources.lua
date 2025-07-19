local actions = require("Beez.pickers.deck.actions")
local formatters = require("Beez.pickers.deck.formatters")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")
local M = {
  toggles = {
    global_codemarks = false,
  },
}

--- Deck source for dap brepoints
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.breakpoints(opts)
  opts = utils.resolve_opts(opts)
  local source = utils.resolve_source(opts, {
    name = "breakpoints",

    execute = function(ctx)
      local breakpoints = require("dap.breakpoints").get()
      for bufnr, bps in pairs(breakpoints) do
        local file = vim.api.nvim_buf_get_name(bufnr)
        for _, bp in ipairs(bps) do
          local item = {
            data = {
              bufnr = bufnr,
              filename = file,
              lnum = bp.line,
            },
          }
          formatters.filename_first.transform(opts)(item)
          ctx.item(item)
        end
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", "open"),
      require("deck").alias_action("delete", "delete_breakpoint"),
      {
        name = "delete_breakpoint",
        execute = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            require("dap.breakpoints").remove(item.data.bufnr, item.data.lnum)

            local ok, _ = pcall(require, "persistent-breakpoints")
            if ok then
              require("persistent-breakpoints.api").breakpoints_changed_in_current_buffer(
                item.data.filename,
                item.data.bufnr
              )
            end

            if opts.delcb then
              opts.delcb()
            end
          end
          ctx.execute()
        end,
      },
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Extended buffer picker from deck
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.buffers(opts)
  opts = utils.resolve_opts(opts, { buf_flags = true })
  local buf_source = utils.resolve_source(opts, {
    name = "buffers",

    execute = function(ctx)
      local buffers = vim.api.nvim_list_bufs()
      local items = {}
      for _, buf in ipairs(buffers) do
        local bufname = vim.api.nvim_buf_get_name(buf)
        local basename = u.paths.basename(bufname)
        local acceptable = u.nvim.valid_buf(buf, { current = false })
        acceptable = acceptable and bufname ~= "" and basename ~= nil and basename ~= ""
        if acceptable then
          local filename = bufname
          local info = vim.fn.getbufinfo(buf)[1]
          local item = {
            data = {
              info = info,
              bufnr = buf,
              filename = filename,
            },
          }
          formatters.filename_first.transform(opts)(item)
          if item.display_text then
            items[item.data.filename] = item
          end

          local ok, _ = pcall(require, "bufferline")
          if ok then
            local elements = require("bufferline.commands").get_elements()
            local groups = require("bufferline.groups")
            for _, e in ipairs(elements.elements) do
              if e.id == buf then
                item.data.pinned = groups._is_pinned(e)
              end
            end
          end
        end
      end

      -- Use recent file index to sort
      for i, path in ipairs(require("deck.builtin.source.recent_files").file.contents) do
        if items[path] then
          items[path].data.recent = i
        end
      end
      -- Convert back to list to sort
      local items_list = {}
      for _, item in pairs(items) do
        table.insert(items_list, item)
      end
      -- Sort by recency
      table.sort(items_list, function(a, b)
        local a_score = a.data.recent or 1
        local b_score = b.data.recent or 1
        if a.data.pinned then
          a_score = 9999
        end
        if b.data.pinned then
          b_score = 9999
        end
        return a_score > b_score
      end)

      for _, item in ipairs(items_list) do
        ctx.item(item)
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", "open"),
      require("deck").alias_action("delete", "delete_buf"),
      require("deck").alias_action("paste", "pin_buf"),
      {
        name = "delete_buf",
        resolve = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            if item.data.bufnr then
              return true
            end
          end
          return false
        end,
        execute = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            if item.data.bufnr then
              Snacks.bufdelete(item.data.bufnr)
            end
          end
          ctx.execute()
        end,
      },
      {
        name = "pin_buf",
        resolve = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            if item.data.bufnr then
              return true
            end
          end
          return false
        end,
        execute = function(ctx)
          local elements = require("bufferline.commands").get_elements()
          for _, item in ipairs(ctx.get_action_items()) do
            for _, e in ipairs(elements.elements) do
              if e.id == item.data.bufnr then
                ---@diagnostic disable-next-line: redundant-parameter
                require("bufferline.groups").toggle_pin(e)
              end
            end
          end
          ctx.execute()
        end,
      },
    },
  })

  local specifier = utils.resolve_specifier(opts, { start_prompt = false })
  return buf_source, specifier
end

--- Fasder files deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.files_fasder(opts)
  opts = utils.resolve_opts(opts)
  local source = utils.resolve_source(opts, {
    name = "fasder",
    execute = function(ctx)
      local query = ctx.get_query()

      -- Not sure why the async way doesn't work
      local output = vim.fn.system("fasder -fl")
      for line in output:gmatch("[^\r\n]+") do
        local item = {
          data = { query = query, filename = line },
        }
        formatters.filename_first.transform(opts)(item)
        ctx.item(item)
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", opts.default_action or "open"),
      require("deck").alias_action("delete", "remove_fasder"),
      actions.open_external({ quit = opts.open_external.quit }),
      actions.open_external({ parent = true, quit = opts.open_external.quit }),
      {
        name = "remove_fasder",
        resolve = function(ctx)
          local symbols = require("deck.symbols")
          for _, item in ipairs(ctx.get_action_items()) do
            if item[symbols.source].name == "fasder" then
              return true
            end
          end
          return false
        end,
        execute = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            local cmd = {
              "fasder",
              "-D",
              item.data.filename,
            }
            vim.fn.system(table.concat(cmd, " "))
          end
          ctx.execute()
        end,
      },
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Recent files source
---@param opts table
---@ruturn deck.Source, deck.StartConfigSpecifier
function M.files_recent(opts)
  opts = utils.resolve_opts(opts, { source_opts = { limit = 100 } })
  local source = require("deck.builtin.source.recent_files")(opts.source_opts)

  local _actions = {
    require("deck").alias_action("default", "open"),
    require("deck").alias_action("delete", "remove_recent"),
    actions.remove_recent,
  }
  source = utils.resolve_source(opts, source)
  source.actions = _actions

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Files deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.files(opts)
  opts = utils.resolve_opts(opts)
  local source = require("deck.builtin.source.files")(opts.source_opts)
  source = utils.resolve_source(opts, source)
  table.insert(source.actions, require("deck").alias_action("toggle1", "toggle_cwd"))
  table.insert(source.actions, actions.toggle_cwd)
  table.insert(source.actions, require("deck").alias_action("delete", "delete_file"))

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Smart recent files deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.files_recent_smart(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {})
  local fasder_source, _ = M.files_fasder(opts)
  local recent_source, specifier = M.files_recent(opts)
  local sources = { recent_source, fasder_source }
  return sources, specifier
end

--- Smart deck source
---@param opts table
---@return table<deck.Source>, deck.StartConfigSpecifier
function M.files_smart(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {})
  local buf_source, _ = M.buffers(opts)
  local recent_source, _ = M.files_recent(opts)
  local files_source, specifier = M.files(opts)
  local sources = { buf_source, recent_source, files_source }
  return sources, specifier
end

--- Grep deck source and specifier
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.grep(opts)
  opts = utils.resolve_opts(opts, { is_grep = true, filename_first = false })
  local source = utils.resolve_source(opts, require("deck.builtin.source.grep")(opts.source_opts))
  table.insert(source.actions, require("deck").alias_action("toggle1", "toggle_cwd"))
  table.insert(source.actions, actions.toggle_cwd)
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Grep current buffer deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.grep_buffer(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local filename = vim.api.nvim_buf_get_name(0)
  local source = utils.resolve_source(
    opts,
    require("deck.builtin.source.grep")(vim.tbl_deep_extend("keep", opts.source_opts, {
      live = true,
      cmd = function(query)
        local cmd = {
          "rg",
          "--ignore-case",
          "--column",
          "--line-number",
          "--sort",
          "path",
        }
        for _, glob in ipairs(opts.source_opts.ignore_globs or {}) do
          table.insert(cmd, "--glob")
          table.insert(cmd, "!" .. glob)
        end
        table.insert(cmd, query)
        table.insert(cmd, filename)
        return cmd
      end,
      transform = function(item, text)
        local lnum = tonumber(text:match("^(%d+):%d+:"))
        local match = text:match("^%d+:%d+:(.*)$")

        item.data.filename = filename
        item.data.lnum = lnum
        item.display_text = {
          { tostring(lnum), "Comment" },
          { "   " },
        }

        local start_idx, end_idx = string.find(string.lower(match), string.lower(item.data.query))
        if start_idx ~= nil and end_idx ~= nil and item.data.query ~= "" then
          local before_match = string.sub(match, 1, start_idx - 1)
          local query_match = string.sub(match, start_idx, end_idx)
          local after_match = string.sub(match, end_idx + 1)
          table.insert(item.display_text, { before_match, "Normal" })
          table.insert(item.display_text, { query_match, "Search" })
          table.insert(item.display_text, { after_match, "Normal" })
        else
          table.insert(item.display_text, { match, "Normal" })
        end
      end,
    }))
  )
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Workspace tags deck source
---@return deck.Source, deck.StartConfigSpecifier
function M.tags_workspace(opts)
  local ctags_file = u.paths.ctags_file(true)
  opts = utils.resolve_opts(opts, {
    is_grep = false,
    filename_first = false,
    source_opts = {
      name = "workspace_tags",
      cmd = function(query)
        local cmd = {
          "rg",
          "--no-heading",
          "--smart-case",
        }
        for _, glob in ipairs(opts.source_opts.ignore_globs or {}) do
          table.insert(cmd, "--glob")
          table.insert(cmd, "!" .. glob)
        end
        table.insert(cmd, query)
        table.insert(cmd, ctags_file)
        return cmd
      end,
      transform = formatters.ctags.transform(true),
    },
  })
  local source, specifier = M.grep(opts)
  return source, specifier
end

--- Search for document tags deck
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.tags_document(opts)
  opts = utils.resolve_opts(opts)
  local System = require("deck.kit.System")
  local notify = require("deck.notify")
  local source = utils.resolve_source(opts, {
    name = "document_tags",
    execute = function(ctx)
      local query = ctx.get_query()
      local cmd = {
        "ctags",
        "-f",
        "-",
        vim.api.nvim_buf_get_name(0),
      }
      ctx.on_abort(System.spawn(cmd, {
        cwd = vim.fn.getcwd(),
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local item = {
            data = { query = query },
          }
          formatters.ctags.transform(false)(item, text)
          ctx.item(item)
        end,
        on_stderr = function(text)
          notify.show({
            { { ("[tags: stderr] %s"):format(text), "ErrorMsg" } },
          })
        end,
        on_exit = function()
          ctx.done()
        end,
      }))
    end,
  })

  source.actions = {
    require("deck").alias_action("default", "open"),
  }

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Recent dirs deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.dirs_recent(opts)
  opts = utils.resolve_opts(opts, { open_external = { quit = false } })
  local source = require("deck.builtin.source.recent_dirs")(opts.source_opts)

  source.actions = {}
  table.insert(
    source.actions,
    require("deck").alias_action("default", opts.default_action or "open_oil")
  )
  table.insert(source.actions, actions.open_oil({ keep_open = false }))
  table.insert(source.actions, require("deck").alias_action("open_keep", "open_oil_keep"))
  table.insert(source.actions, actions.open_oil({ keep_open = true }))
  table.insert(source.actions, require("deck").alias_action("prev_default", "open_oil_parent"))
  table.insert(source.actions, actions.open_oil({ parent = true }))
  table.insert(source.actions, require("deck").alias_action("delete", "remove_recent"))
  table.insert(source.actions, actions.remove_recent)
  table.insert(source.actions, actions.open_external({ quit = opts.open_external.quit }))
  table.insert(source.actions, actions.open_external({ parent = true, quit = opts.open_external.quit }))
  source = utils.resolve_source(opts, source)

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Dirs deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.dirs(opts)
  opts = utils.resolve_opts(opts, { open_external = { quit = false } })
  local source = require("deck.builtin.source.dirs")(opts.source_opts)
  source = utils.resolve_source(opts, source)
  source.actions = {}
  table.insert(
    source.actions,
    require("deck").alias_action("default", opts.default_action or "open_oil")
  )
  table.insert(source.actions, require("deck").alias_action("open_keep", "open_oil_keep"))
  table.insert(source.actions, require("deck").alias_action("toggle1", "toggle_cwd"))
  table.insert(source.actions, actions.toggle_cwd)
  table.insert(source.actions, actions.open_oil({ keep_open = false }))
  table.insert(source.actions, actions.open_oil({ keep_open = true }))
  table.insert(source.actions, require("deck").alias_action("prev_default", "open_oil_parent"))
  table.insert(source.actions, actions.open_oil({ parent = true }))
  table.insert(source.actions, actions.open_external({ quit = opts.open_external.quit }))
  table.insert(source.actions, actions.open_external({ parent = true, quit = opts.open_external.quit }))

  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Zoxide dirs deck source
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.dirs_fasder(opts)
  opts = utils.resolve_opts(opts)
  local source = utils.resolve_source(opts, {
    name = "fasder",
    execute = function(ctx)
      local query = ctx.get_query()

      -- Not sure why the async way doesn't work
      local output = vim.fn.system("fasder -dl")
      for line in output:gmatch("[^\r\n]+") do
        local item = {
          data = { query = query, filename = line },
        }
        formatters.filename_first.transform(opts)(item)
        ctx.item(item)
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", opts.default_action or "open_oil"),
      require("deck").alias_action("alt_default", "open_oil_keep"),
      require("deck").alias_action("prev_default", "open_oil_parent"),
      require("deck").alias_action("delete", "remove_fasder"),
      actions.open_oil({ keep_open = false }),
      actions.open_oil({ keep_open = true }),
      actions.open_oil({ parent = true }),
      actions.open_external({ quit = opts.open_external.quit }),
      actions.open_external({ parent = true, quit = opts.open_external.quit }),
      actions.open_zed({ quit = opts.open_zed.quit }),
      {
        name = "remove_fasder",
        resolve = function(ctx)
          local symbols = require("deck.symbols")
          for _, item in ipairs(ctx.get_action_items()) do
            if item[symbols.source].name == "fasder" then
              return true
            end
          end
          return false
        end,
        execute = function(ctx)
          for _, item in ipairs(ctx.get_action_items()) do
            local cmd = {
              "fasder",
              "-D",
              item.data.filename,
            }
            vim.fn.system(table.concat(cmd, " "))
          end
          ctx.execute()
        end,
      },
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Smart dirs deck source combines recent, dirs and zioxide
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.dirs_smart(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {})
  local recent_source, _ = M.dirs_recent(opts)
  local zoxide_source, _ = M.dirs_fasder(opts)
  local dirs_source, specifier = M.dirs(opts)

  return {
    recent_source,
    zoxide_source,
    dirs_source,
  }, specifier
end

--- Deck picker for git status
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.git_status(opts)
  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local git_status = require("deck.builtin.source.git.status")(opts)
  git_status.actions[1] = require("deck").alias_action("default", "open_keep")
  local specifier = utils.resolve_specifier(opts)
  return git_status, specifier
end

--- Grep help deck source and specifier
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.help_grep(opts)
  opts = utils.resolve_opts(opts, { is_grep = true, filename_first = false })
  local source = utils.resolve_source(opts, require("deck.builtin.source.helpgrep")(opts.source_opts))
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
