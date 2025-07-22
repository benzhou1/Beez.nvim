local picks = require("Beez.pickers.picks")
local u = require("Beez.u")
local M = {
  state = { type = nil },
}

---@class Beez.pick.opts
---@field type "snacks"|"fzf"|"deck"
---@field disable_preview? boolean
---@field cwd? boolean|string
---@field pick_opts? table

---@alias Beez.pick.name "smart"|"resume"|"find_files"|"git_files"|"grep"|"grep_string"|"grep_curbuf"|"grep_curbuf_ripgrep"|"grep_curbuf_live_grep"|"grep_curbuf_live_grep_ripgrep"|"lsp_definitions"|"lsp_references"|"lsp_implementations"|"lsp_type_definitions"|"lsp_symbols"|"lsp_workspace_symbols"|"codemarks.global_marks"|"codemarks.global_marks_update_line"|"codemarks.marks"|"codemarks.stacks"|"scratches"|"notes.find"|"notes.grep"|"notes.find_templates"|"dbfp.connections"|"dbfp.queries"|"notes.backlinks"

--- Pick a picker
---@param name Beez.pick.name
---@param opts? Beez.pick.opts
function M.pick(name, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    type = vim.g.lazyvim_picker or "deck",
  })

  local pickers = picks[name]
  if pickers == nil then
    error("Picker: " .. name .. " not found")
  end
  pickers = pickers()

  -- Use the resume of the previous picker type
  if name == "resume" then
    if M.state.type ~= nil then
      opts.type = M.state.type
    end
  end

  local pick = pickers[opts.type]
  if pick == nil then
    error("Picker: " .. opts.type .. "." .. name .. " not found")
  end

  local def_opts = {}
  if pick.def_opts ~= nil then
    def_opts = pick.def_opts(opts)
  end
  local pick_opts = vim.tbl_deep_extend("keep", opts.pick_opts or {}, def_opts)
  -- Disable preview for picker
  if opts.disable_preview == true then
    if opts.type == "snacks" then
      pick_opts.layout = pick_opts.layout or {}
      pick_opts.layout.preview = false
    elseif opts.type == "fzf" then
      pick_opts.winopts = pick_opts.winopts or {}
      pick_opts.winopts.preview = pick_opts.winopts.preview or {}
      pick_opts.winopts.preview.hidden = true
      -- Deck already has preview disabled by default
    end
  end

  -- Setup cwd for picker, defaults to root dir of current buffer
  local cwd = nil
  if opts.cwd ~= nil then
    if opts.cwd == true then
      cwd = vim.fn.getcwd()
    elseif type(opts.cwd) == "string" then
      cwd = opts.cwd
    end
  end
  if cwd == nil then
    cwd = u.root.get({ buf = vim.api.nvim_get_current_buf() })
  end
  pick_opts.cwd = cwd
  pick_opts.root_dir = cwd

  if pick.resume ~= false then
    M.state.type = opts.type
  end
  pick.run(pick_opts)
end

M.snacks = require("Beez.pickers.snacks")
M.fzf = require("Beez.pickers.fzf")
M.deck = require("Beez.pickers.deck")

return M
