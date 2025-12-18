vim.api.nvim_create_user_command("BeezDiffEditor", function(params)
  local args = params.fargs
  if #args < 2 then
    vim.notify(
      "Error: BeezDiffEditor expects three arguments (left, right[, output])",
      vim.log.levels.ERROR
    )
    return
  end
  require("Beez.jj").diffeditor(args[1], args[2], args[3])
end, {
  nargs = "*",
})
