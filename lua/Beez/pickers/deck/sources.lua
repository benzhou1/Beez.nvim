local actions = require("Beez.pickers.deck.actions")
local decorators = require("Beez.pickers.deck.decorators")
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

--- Gets currently opened buffer list
---@param opts table
---@return table
local function buffer_items(opts)
  opts = opts or {}
  local cs = require("Beez.codestacks")
  local buffers = cs.bufferlist.list()
  local items = {}
  for _, buf in ipairs(buffers) do
    if cs.bufferlist.is_valid(buf) then
      local item = {
        data = {
          bufnr = buf.id,
          filename = buf.path,
          source = "buffer",
        },
      }
      formatters.filename_first.transform(opts)(item)
      if item.display_text then
        table.insert(items, item)
      end
    end
  end
  return items
end

--- Extended buffer picker from deck
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.buffers(opts)
  opts = utils.resolve_opts(opts, { buf_flags = true, buf_recent = true })
  local buf_source = utils.resolve_source(opts, {
    name = "buffers",

    execute = function(ctx)
      local items = buffer_items(opts)
      for i, item in ipairs(items) do
        item.data.i = i
        ctx.item(item)
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", "open"),
      require("deck").alias_action("delete", "delete_buf"),
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
    },
  })

  local specifier = utils.resolve_specifier(opts, { start_prompt = true })
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

--- Gets a list of recent files items
---@param opts? table
---@return table
local function get_recent_files(opts)
  opts = opts or {}
  local cs = require("Beez.codestacks")
  local recent_files = cs.recentfiles.list()
  local items = {}
  for _, r in ipairs(recent_files) do
    local item = {
      data = {
        filename = r,
        source = "recent_files",
      },
    }
    table.insert(items, item)
  end
  return items
end

--- Recent files source
---@param opts table
---@ruturn deck.Source, deck.StartConfigSpecifier
function M.files_recent(opts)
  opts = utils.resolve_opts(opts, { source_opts = { limit = 100 } })
  local source = utils.resolve_source(opts, {
    name = "recent_files",
    execute = function(ctx)
      local recent_files = get_recent_files(opts)
      for _, item in ipairs(recent_files) do
        formatters.filename_first.transform(opts)(item)
        ctx.item(item)
      end
      ctx.done()
    end,
    actions = {
      require("deck").alias_action("default", "open"),
      require("deck").alias_action("delete", "remove_recent"),
      actions.remove_recent,
    },
  })

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
  source.actions = u.tables.extend(source.actions, actions.toggle_cwd())

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
  buf_source.actions = u.tables.extend(buf_source.actions, actions.toggle_cwd())
  local recent_source, _ = M.files_recent(opts)
  recent_source.actions = u.tables.extend(recent_source.actions, actions.toggle_cwd())
  local files_source, specifier = M.files(opts)
  local sources = { buf_source, recent_source, files_source }
  return sources, specifier
end

--- Deck source for fff.nvim
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.fff(opts)
  opts = utils.resolve_opts(opts)
  local fff = require("fff")
  local file_picker = require("fff.file_picker")

  if not file_picker.is_initialized() then
    local setup_success = file_picker.setup()
    if not setup_success then
      vim.notify("Failed to initialize file picker", vim.log.levels.ERROR)
    end
  end

  local function parse_query(query)
    local sep = query:find("  ") or #query
    local dynamic_query = query:sub(1, sep)
    local matcher_query = query:sub(sep + 2)
    return {
      dynamic_query = dynamic_query:gsub("^%s+", ""):gsub("%s+$", ""),
      matcher_query = matcher_query:gsub("^%s+", ""):gsub("%s+$", ""),
    }
  end

  local source = utils.resolve_source(opts, {
    name = "fff",
    parse_query = parse_query,
    execute = function(ctx)
      local config = ctx.get_config()
      local query = ctx.get_query()
      local dynamic_query = parse_query(query).dynamic_query
      local cwd = opts.root_dir
      if config.toggles.cwd == true then
        cwd = vim.fn.getcwd()
      end

      -- If no query then show list of opened buffers first
      if query == "" then
        local buf_items = buffer_items(opts)
        for _, b in ipairs(buf_items) do
          ctx.item(b)
        end
      end

      local fff_config = require("fff.conf").get()
      if fff_config.base_path ~= cwd then
        fff.change_indexing_directory(cwd)
        fff.scan_files()
      end
      if ctx.aborted() then
        return ctx.done()
      end

      local fff_result = file_picker.search_files(
        dynamic_query,
        100,
        4,
        vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
        false
      )
      for _, f in ipairs(fff_result) do
        if ctx.aborted() then
          return ctx.done()
        end
        local item = {
          data = {
            query = query,
            filename = f.path,
            source = "fff",
          },
        }
        formatters.filename_first.transform(opts)(item)
        ctx.item(item)
      end

      -- Include recent files with deck default matcher
      if query ~= "" then
        local items = {}
        local recent_files = get_recent_files(opts)
        local matcher = require("deck.builtin.matcher.default")
        for _, recent_item in ipairs(recent_files) do
          if recent_item.data.filename ~= nil and recent_item.data.filename ~= "" then
            local basename = u.paths.basename(recent_item.data.filename)
            if basename ~= nil then
              local score = matcher.match(query, basename)
              -- Add directory score
              if score > 0 then
                local dirname = u.paths.dirname(recent_item.data.filename)
                if dirname ~= nil then
                  score = matcher.match(query, dirname) + score
                  recent_item.data.score = score
                  recent_item.data.source = "recent_files"
                  recent_item.data.query = query
                  formatters.filename_first.transform(opts)(recent_item)
                  table.insert(items, recent_item)
                end
              end
            end
          end
        end

        table.sort(items, function(a, b)
          return (a.data.score or 0) > (b.data.score or 0)
        end)
        for _, i in ipairs(items) do
          ctx.item(i)
        end
      end
      ctx.done()
    end,
    actions = u.tables.extend({
      require("deck").alias_action("default", "open"),
    }, actions.toggle_cwd()),
    decorators = {
      decorators.query,
      decorators.buf_flags,
      decorators.source,
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

--- Grep deck source and specifier
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.grep(opts)
  opts = utils.resolve_opts(opts, { is_grep = true, filename_first = false })
  local source = utils.resolve_source(opts, require("deck.builtin.source.grep")(opts.source_opts))
  source.actions = u.tables.extend(source.actions, actions.toggle_cwd())
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
          table.insert(item.display_text, { before_match, "String" })
          table.insert(item.display_text, { query_match, "Search" })
          table.insert(item.display_text, { after_match, "String" })
        else
          table.insert(item.display_text, { match, "String" })
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
  source.actions = u.tables.extend(
    source.actions,
    actions.find_files({ name = "find_files_under_dir", dir = true }),
    actions.grep_files({ name = "grep_files_under_dir", dir = true })
  )
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
  table.insert(source.actions, actions.open_oil({ keep_open = false }))
  table.insert(source.actions, actions.open_oil({ keep_open = true }))
  table.insert(source.actions, require("deck").alias_action("prev_default", "open_oil_parent"))
  table.insert(source.actions, actions.open_oil({ parent = true }))
  table.insert(source.actions, actions.open_external({ quit = opts.open_external.quit }))
  table.insert(source.actions, actions.open_external({ parent = true, quit = opts.open_external.quit }))
  source.actions =
    u.tables.extend(source.actions, actions.toggle_cwd(), actions.find_files(), actions.grep_files())

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

    actions = u.tables.extend(
      {
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
      actions.find_files({ name = "find_files_under_dir", dir = true }),
      actions.grep_files({ name = "grep_files_under_dir", dir = true })
    ),
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

--- Deck source for jump list
---@param opts table
---@return deck.Source, deck.StartConfigSpecifier
function M.jump_list(opts)
  opts = utils.resolve_opts(opts, { filename_first = false })
  local source = utils.resolve_source(opts, {
    name = "jump_list",
    execute = function(ctx)
      local jl = vim.fn.getjumplist()
      local list = u.tables.reverse(jl[1])
      local curr_idx = math.max(#list - jl[2], 1)

      for i, j in ipairs(list) do
        local filepath = vim.api.nvim_buf_get_name(j.bufnr)
        local filename = u.paths.basename(filepath)
        local line = u.os.read_line_at(filepath, j.lnum)
        local current = i == curr_idx
        local hl = "String"
        if current then
          hl = "Search"
        end
        local item = {
          display_text = {
            { filename, hl },
            { ":", "String" },
            { tostring(j.lnum), "String" },
            { " ", "String" },
            { line, "Comment" },
          },
          data = {
            current = current,
            filename = filepath,
            lnum = j.lnum,
          },
        }
        ctx.item(item)
      end
      ctx.done()
    end,

    actions = {
      require("deck").alias_action("default", "open"),
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
