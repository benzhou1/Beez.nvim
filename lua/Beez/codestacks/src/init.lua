--- @return string
local function get_lib_extension()
  if jit.os:lower() == "mac" or jit.os:lower() == "osx" then
    return ".dylib"
  end
  if jit.os:lower() == "windows" then
    return ".dll"
  end
  return ".so"
end

-- search for the lib in the /target/release directory with and without the lib prefix
-- since MSVC doesn't include the prefix
local base_path = debug.getinfo(1).source:match("@?(.*/)")

-- The ? will replace whatever string is used for require
local paths = {
  base_path .. "../target/release/lib?" .. get_lib_extension(),
  base_path .. "../target/release/?" .. get_lib_extension(),
}

local cargo_target_dir = os.getenv("CARGO_TARGET_DIR")
if cargo_target_dir then
  table.insert(paths, cargo_target_dir .. "/release/lib?" .. get_lib_extension())
  table.insert(paths, cargo_target_dir .. "/release/?" .. get_lib_extension())
end

package.cpath = package.cpath .. ";" .. table.concat(paths, ";")

-- Here we are using codestacks_nvim that will replace ?
local ok, codestacks = pcall(require, "codestacks_nvim")
if not ok then
  error(
    "Failed to load codestacks rust backend. Make sure that it has been built with `cargo build --release`"
  )
end

return codestacks
