local M = {}

--- Deck source for zk notes
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.notes(opts)
  local System = require("deck.kit.System")
  local utils = require("beez.pickers.deck.utils")
  local zkp = require("plugins.zk")
  local actions = require("beez.pickers.deck.zk.actions")
  local u = require("beez.u")
  local decorators = require("beez.pickers.deck.decorators")

  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })

  local function parse_query(query)
    -- Requires at least 2 characters to query
    if #query < 2 then
      return {
        dynamic_query = "",
        matcher_query = "",
      }
    end
    local sep = query:find("  ") or #query
    local dynamic_query = query:sub(1, sep)
    local matcher_query = query:sub(sep + 2)
    return {
      dynamic_query = dynamic_query:gsub("^%s+", ""):gsub("%s+$", ""),
      matcher_query = matcher_query:gsub("^%s+", ""):gsub("%s+$", ""),
    }
  end

  ---@type deck.Source
  local source = utils.resolve_source(opts, {
    name = "zk.notes",
    parse_query = parse_query,
    execute = function(ctx)
      local query = parse_query(ctx.get_query()).dynamic_query
      local note_delimiter = "|||"
      local line_delimiter = ",,,"
      local format = "{{title}}" .. line_delimiter .. "{{path}}"
      if query and query ~= "" and opts.body then
        format = format .. line_delimiter .. "{{snippets}}"
      end

      local function mk_item(line)
        local parts = vim.split(line, line_delimiter)
        local title, path, snippets = parts[1], parts[2], parts[3]
        local item = {
          data = { query = query, path = vim.fs.joinpath(zkp.notebook_dir, path), rel_path = path },
          display_text = {
            { title, "String" },
          },
        }
        if snippets and snippets ~= "" then
          table.insert(item.display_text, { " " })
          table.insert(item.display_text, { snippets, "Comment" })
        end
        ctx.item(item)
      end

      local command = {
        "zk",
        "list",
        "--no-input",
        "-f",
        format,
        "-s",
        "modified-",
        "-d",
        "\n" .. note_delimiter,
      }
      if query and query ~= "" then
        table.insert(command, "-m")
        if opts.body then
          table.insert(command, "body:" .. query)
        else
          table.insert(command, "title:" .. query)
        end
      end

      local prev_line = ""
      ctx.on_abort(System.spawn(command, {
        cwd = zkp.notebook_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          if not text:contains(note_delimiter) then
            prev_line = prev_line .. text
            return
          end

          local line = prev_line
          prev_line = text:gsub(note_delimiter, "")
          mk_item(line)
        end,
        on_exit = function()
          -- If there is only one note there will be no note_delimiter to trigger the last item
          local line = prev_line
          mk_item(line)
          ctx.done()
        end,
      }))
    end,
    actions = u.tables.extend(actions.open.action(), {
      require("deck").alias_action("default", opts.default_action or actions.open.name),
    }),
    decorators = {
      decorators.query,
    },
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
