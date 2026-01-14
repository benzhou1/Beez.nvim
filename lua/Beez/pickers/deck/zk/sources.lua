local M = {}

--- Deck source for zk notes
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.notes(opts)
  local System = require("deck.kit.System")
  local utils = require("Beez.pickers.deck.utils")
  local zkp = require("plugins.zk")
  local actions = require("Beez.pickers.deck.zk.actions")
  local u = require("Beez.u")

  opts = utils.resolve_opts(opts, { is_grep = false, filename_first = false })
  local function parse_query(query)
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
      local delimiter = "\t"
      local command = {
        "zk",
        "list",
        "--no-input",
        "-f",
        "{{title}}" .. delimiter .. "{{path}}",
        "-s",
        "modified-",
      }
      if query and query ~= "" then
        table.insert(command, "-m")
        table.insert(command, "title:" .. query)
      end

      ctx.on_abort(System.spawn(command, {
        cwd = zkp.notebook_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local parts = vim.split(text, delimiter)
          local title, path = parts[1], parts[2]
          local item = {
            data = { query = query, path = vim.fs.joinpath(zkp.notebook_dir, path), rel_path = path },
            display_text = {
              { title, "String" },
            },
          }
          ctx.item(item)
        end,
        on_exit = function()
          ctx.done()
        end,
      }))
    end,
    actions = u.tables.extend(actions.open.action(), {
      require("deck").alias_action("default", opts.default_action or actions.open.name),
    }),
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
