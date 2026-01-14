local sources = require("Beez.pickers.deck.lsp.sources")
local M = {}

--- Deck picker for definitions
---@param opts? table
function M.go_to_definitions(opts)
  opts = opts or {}
  sources.get_definitions(function(items)
    if #items == 0 then
      return
    end

    if #items == 1 then
      local item = items[1]
      -- If not in an overloop popup, add current position to jumplist
      if not vim.w.is_overlook_popup then
        vim.cmd("normal! m'")
      end

      local ok, overlook_ui = pcall(require, "overlook.ui")
      if not ok then
        vim.cmd("e " .. item.data.filename)
        return
      end

      overlook_ui.create_popup({
        target_bufnr = item.data.target_bufnr,
        lnum = item.data.lnum,
        col = item.data.col,
        title = item.data.filename,
      })
      return
    end
    local source, specifier = sources.go_to_definitions(items, opts)
    local ctx = require("deck").start(source, specifier)
    ctx.set_preview_mode(true)
  end)
end

--- Deck picker for references
---@param opts? table
function M.find_references(opts)
  opts = opts or {}
  sources.get_references(function(items)
    if #items == 0 then
      return
    end

    if #items == 1 then
      local item = items[1]
      -- If not in an overloop popup, add current position to jumplist
      if not vim.w.is_overlook_popup then
        vim.cmd("normal! m'")
      end

      local ok, overlook_ui = pcall(require, "overlook.ui")
      if not ok then
        vim.cmd("e " .. item.data.filename)
        return
      end

      overlook_ui.create_popup({
        target_bufnr = item.data.target_bufnr,
        lnum = item.data.lnum,
        col = item.data.col,
        title = item.data.filename,
      })
      return
    end
    local source, specifier = sources.find_references(items, opts)
    local ctx = require("deck").start(source, specifier)
    ctx.set_preview_mode(true)
  end)
end

return M
