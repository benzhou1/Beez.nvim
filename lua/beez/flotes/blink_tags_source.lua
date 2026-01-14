--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
function source.new(opts)
  opts = opts or {}
  local self = setmetatable({}, { __index = source })
  self.opts = opts
  return self
end

-- (Optional) Enable the source in specific contexts only
function source:enabled()
  local f = require("beez.flotes")
  return vim.bo.filetype == "markdown" and vim.api.nvim_buf_get_name(0):startswith(f.config.notes_dir)
end

-- (Optional) Non-alphanumeric characters that trigger the source
function source:get_trigger_characters()
  return { "#" }
end

function source:get_completions(ctx, callback)
  if ctx.trigger.character == nil or ctx.trigger.character ~= "#" then
    callback({
      items = {},
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
    return function() end
  end
  local f = require("beez.flotes")
  -- ctx (context) contains the current keyword, cursor position, bufnr, etc.

  -- You should never filter items based on the keyword, since blink.cmp will
  -- do this for you

  -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItem
  --- @type lsp.CompletionItem[]

  local command = {
    "rg",
    "--column",
    "--line-number",
    "--ignore-case",
    "-e",
    [[\s#\w+]],
    f.config.notes_dir,
  }
  local res = vim.system(command, {}, function(out)
    local lines = vim.split(out.stdout, "\n", { plain = true })
    local tags = {}
    local items = {}
    for _, line in ipairs(lines) do
      for tag in line:gmatch("#([^%s]+)") do
        if tags[tag] == nil and not tag:startswith("task:") then
          tags[tag] = true
          local item = {
            -- Label of the item in the UI
            label = "#" .. tag,
            kind = require("blink.cmp.types").CompletionItemKind.Text,
            filterText = tag,
            sortText = tag,
            textEdit = {
              newText = tag,
              range = {
                start = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
                ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
              },
            },
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
          }
          table.insert(items, item)
        end
      end
    end
    callback({
      items = items,
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
  end)
end

return source
