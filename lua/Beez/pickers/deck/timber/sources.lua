local M = {}
local actions = require("Beez.pickers.deck.timber.actions")
local u = require("Beez.u")
local utils = require("Beez.pickers.deck.utils")

--- Deck source for listing debug log statements under current project
---@param opts? table
---@return deck.Source, deck.StartConfigSpecifier
function M.log_statements(opts)
  opts = utils.resolve_opts(opts, { is_grep = true, filename_first = false })

  local timberp = require("plugins.timber")
  local System = require("deck.kit.System")
  local IO = require("deck.kit.IO")
  local timber_config = require("timber.config")
  local root_dir = opts.root_dir
  local ft = vim.bo.filetype
  local cmd = {
    "rg",
    "--column",
    "--line-number",
    "--ignore-case",
    timber_config.config.log_marker,
  }

  local source = utils.resolve_source(opts, {
    name = "timber.log_statements",
    execute = function(ctx)
      local logs = {}
      local query = ctx.get_query()

      ctx.on_abort(System.spawn(cmd, {
        cwd = root_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(line)
          local filename, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
          if filename == nil or text == nil or lnum == nil or col == nil then
            return
          end

          local path = IO.join(root_dir, filename)
          local curr_log = {
            query = query,
            filename = path,
            lnum = tonumber(lnum),
            col = tonumber(col),
            text = text,
            commented_out = timberp.is_commented_out(text, ft),
          }
          table.insert(logs, curr_log)
        end,
        on_exit = function()
          table.sort(logs, function(a, b)
            if a.filename == b.filename then
              return a.lnum < b.lnum
            else
              return a.filename < b.filename
            end
          end)

          for _, log in ipairs(logs) do
            local text_hl = "String"
            if log.commented_out then
              text_hl = "Comment"
            end

            local item = {
              display_text = {
                { log.filename .. ":" .. log.lnum .. " ", "Comment" },
                { log.text, text_hl },
              },
              data = {
                filename = log.filename,
                lnum = log.lnum,
                col = log.col,
                log = log,
              },
            }
            ctx.item(item)
          end
          ctx.done()
        end,
      }))
    end,
    actions = u.tables.extend({}, {
      require("deck").alias_action("default", "open"),
    }, actions.clear_log_statement(), actions.toggle_comment_log_statement({ ft = ft })),
  })
  local specifier = utils.resolve_specifier(opts)
  return source, specifier
end

return M
