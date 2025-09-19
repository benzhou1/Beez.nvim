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

local paths = {
  base_path .. "target/release/lib?" .. get_lib_extension(),
  base_path .. "target/release/?" .. get_lib_extension(),
}

local cargo_target_dir = os.getenv("CARGO_TARGET_DIR")
if cargo_target_dir then
  table.insert(paths, cargo_target_dir .. "/release/lib?" .. get_lib_extension())
  table.insert(paths, cargo_target_dir .. "/release/?" .. get_lib_extension())
end

package.cpath = package.cpath .. ";" .. table.concat(paths, ";")

local ok, res = pcall(require, "codestacks_nvim")
if not ok then
  error(
    "Failed to load codestacks rust backend. Make sure that it has been built with `cargo build --release`"
  )
end
---@type Beez.codestacks.backend
local backend = res

---@class Beez.codestacks.backend
---@field init_tracing fun(path: string, level: string): boolean
---@field setup fun(project: string, base_dir: string, recent_files_limit: integer): boolean
---@field add_stack fun(name: string): boolean
---@field is_active_stack fun(name: string): boolean
---@field list_stacks fun(): Beez.codestacks.Stack[]
---@field remove_stack fun(name: string): Beez.codestacks.Stack?
---@field rename_stack fun(old_name: string): boolean
---@field set_active_stack fun(name: string): boolean
---@field get_active_stack fun(): Beez.codestacks.Stack?
---@field get_stack fun(name?: string): Beez.codestacks.Stack?
---@field add_recent_file fun(path: string): boolean
---@field remove_recent_file fun(path: string): boolean
---@field list_recent_files fun(): string[]
---@field save_recent_files fun(): boolean
---@field pin_buffer fun(path: string, label: string): boolean
---@field unpin_buffer fun(path: string): boolean
---@field list_pinned_buffers fun(): Beez.codestacks.PinnedBuffer[]
---@field enable_recent_files fun(enable: boolean): boolean
---@field get_pinned_buffer fun(path: string): Beez.codestacks.PinnedBuffer?
---@field add_global_mark fun(path: string, desc: string, line: string, lineno: integer): boolean
---@field remove_global_mark fun(path: string, lineno: integer): boolean
---@field list_global_marks fun(path?: string): Beez.codestacks.GlobalMark[]
---@field list_all_global_marks fun(): Beez.codestacks.GlobalMark[]
---@field update_global_mark fun(path: string, lineno: integer, new_lineno?: integer): boolean
---@field add_local_mark fun(path: string, line: string, lineno: integer): boolean
---@field remove_local_mark fun(path: string, lineno: integer): boolean
---@field list_local_marks fun(path?: string): Beez.codestacks.LocalMark[]
---@field update_local_mark fun(path: string, lineno: integer, new_lineno?: integer): boolean

return backend
