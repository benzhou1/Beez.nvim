local u = require("Beez.u")
local M = {}

--- Neo-img previewer
M.neo_img = {
  name = "neo_img",
  priority = 1,
  resolve = function(_, item)
    if not item.data.filename then
      return false
    end
    local ok, image = pcall(require, "neo-img.utils")
    if not ok or not image then
      return false
    end

    local ext = u.paths.ext(item.data.filename)
    if ext == nil then
      return false
    end
    local supported = require("neo-img.config").defaults.supported_extensions[ext]
    return supported
  end,
  preview = function(_, item, env)
    local neo_img = require("neo-img.utils")
    neo_img.display_image(item.data.filename, env.win)
  end,
}

return M
