// src/lib.rs
use mlua::prelude::*;
use once_cell::sync::Lazy;
use std::sync::RwLock;
pub mod buffers;
mod errors;
pub mod marks;
mod stacks;
mod tracing;
use crate::{buffers::RecentFiles, stacks::StacksManager};
use errors::Errors;
use stacks::Stack;

pub static STACKS: Lazy<RwLock<Option<StacksManager>>> = Lazy::new(|| RwLock::new(None));
pub static RECENT_FILES: Lazy<RwLock<Option<buffers::RecentFiles>>> = Lazy::new(|| RwLock::new(None));

// Initialize tracing for the module
pub fn init_tracing(_: &Lua, (log_file_path, log_level): (String, Option<String>)) -> LuaResult<String> {
    crate::tracing::init_tracing(&log_file_path, log_level.as_deref())
        .map_err(|e| LuaError::RuntimeError(format!("Failed to initialize tracing: {}", e)))
}

/// Setup stacks
pub fn setup(
    _: &Lua,
    (project, base_dir, recent_files_limit): (String, String, i32),
) -> LuaResult<bool> {
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    if stacks_man.is_some() {
        return Ok(false);
    }
    *stacks_man = Some(StacksManager::new(project.clone(), &base_dir));

    ::tracing::info!("Stacks initialized...");

    let mut recent_files = RECENT_FILES.write().map_err(|_| Errors::AcquireRecentFilesLock)?;
    if recent_files.is_some() {
        return Ok(false);
    }
    *recent_files = Some(RecentFiles::new(base_dir, recent_files_limit));

    ::tracing::info!("Recent files initialized...");
    Ok(true)
}

/// Creates a new stack
pub fn add_stack(_: &Lua, name: String) -> LuaResult<bool> {
    ::tracing::info!("Adding new stack: {}", name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.add(name)),
        None => Ok(false),
    }
}

/// Removes a stack by name
pub fn remove_stack(_: &Lua, name: String) -> LuaResult<Option<Stack>> {
    ::tracing::info!("Removing stack: {}", name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        None => Ok(None),
        Some(ss) => Ok(ss.remove(name)),
    }
}

// Returns the current active stack name
pub fn get_active_stack(_: &Lua, _: ()) -> LuaResult<Option<String>> {
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        Some(ss) => Ok(ss.active.clone()),
        None => Ok(None),
    }
}

/// Checks if name is the active stack
pub fn is_active_stack(_: &Lua, name: String) -> LuaResult<bool> {
    ::tracing::info!("Checking if stack is active: {}", name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        None => Ok(false),
        Some(ss) => Ok(ss.is_active(name)),
    }
}

/// Sets the active stack by name
pub fn set_active_stack(_: &Lua, name: String) -> LuaResult<bool> {
    ::tracing::info!("Setting active stack: {}", name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.set_active(name)),
        None => Ok(false),
    }
}

/// List existing stacks
pub fn list_stacks(_: &Lua, _: ()) -> LuaResult<Vec<Stack>> {
    ::tracing::info!("Listing stacks...");
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        Some(ss) => Ok(ss.list()),
        None => Ok(vec![]),
    }
}

/// Renames a stack from old_name to new_name
pub fn rename_stack(_: &Lua, (old_name, new_name): (String, String)) -> LuaResult<bool> {
    ::tracing::info!("Renaming stack from {} to {}", old_name, new_name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.rename(old_name, new_name)),
        None => Ok(false),
    }
}

// Gets a stack by name, or the active stack if name is None
pub fn get_stack(_: &Lua, name: Option<String>) -> LuaResult<Option<Stack>> {
    ::tracing::info!("Getting stack: {:?}", name);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        None => Ok(None),
        Some(ss) => Ok(ss.get(name)),
    }
}

// Pins a buffer to the active stack with a label
pub fn pin_buffer(_: &Lua, (path, label): (String, String)) -> LuaResult<bool> {
    ::tracing::info!("Pinning buffer {} with label: {}", path, label);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.pin_buffer(path, label)),
        None => Ok(false),
    }
}

// Unpins a buffer from the active stack by path
pub fn unpin_buffer(_: &Lua, path: String) -> LuaResult<bool> {
    ::tracing::info!("Unpinning buffer {}", path);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        None => Ok(false),
        Some(ss) => Ok(ss.unpin_buffer(path)),
    }
}

// Returns a list of pinned buffers in the active stack
pub fn list_pinned_buffers(_: &Lua, _: ()) -> LuaResult<Vec<buffers::PinnedBuffer>> {
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        None => Ok(vec![]),
        Some(ss) => Ok(ss.list_pinned_buffers()),
    }
}

// Finds a pinned buffer by path in the active stack
pub fn get_pinned_buffer(_: &Lua, path: String) -> LuaResult<Option<buffers::PinnedBuffer>> {
    ::tracing::info!("Getting pinned buffer: {}", path);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        None => Ok(None),
        Some(ss) => Ok(ss.get_pinned_buffer(path)),
    }
}

// Adds a file to the recent files list
pub fn add_recent_file(_: &Lua, file_path: String) -> LuaResult<bool> {
    ::tracing::info!("Adding recent file: {}", file_path);
    let mut recent_files = RECENT_FILES.write().map_err(|_| Errors::AcquireStacksLock)?;
    let rf = Option::ok_or_else(recent_files.as_mut(), || Errors::RecentFilesNotInit)?;
    rf.add(file_path);
    Ok(true)
}

// Remove a file from the recent files list
pub fn remove_recent_file(_: &Lua, file_path: String) -> LuaResult<bool> {
    ::tracing::info!("Removing recent file: {}", file_path);
    let mut recent_files = RECENT_FILES.write().map_err(|_| Errors::AcquireStacksLock)?;
    let rf = Option::ok_or_else(recent_files.as_mut(), || Errors::RecentFilesNotInit)?;
    rf.remove(file_path);
    Ok(true)
}

// Gets a list of recent files
pub fn list_recent_files(_: &Lua, _: ()) -> LuaResult<Vec<String>> {
    let recent_files = RECENT_FILES.read().map_err(|_| Errors::AcquireStacksLock)?;
    let rf = Option::ok_or_else(recent_files.as_ref(), || Errors::RecentFilesNotInit)?;
    Ok(rf.list())
}

// Set enable stacks of recent files tracking
pub fn enable_recent_files(_: &Lua, enable: bool) -> LuaResult<bool> {
    ::tracing::info!("Setting recent files enabled: {}", enable);
    let mut recent_files = RECENT_FILES.write().map_err(|_| Errors::AcquireStacksLock)?;
    let rf = Option::ok_or_else(recent_files.as_mut(), || Errors::RecentFilesNotInit)?;
    rf.set_enabled(enable);
    Ok(true)
}

// Add global mark to the active stack
pub fn add_global_mark(
    _: &Lua,
    (path, desc, line, lineno): (String, String, String, i32),
) -> LuaResult<bool> {
    ::tracing::info!("Adding global mark: {} - {}", path, desc);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.add_global_mark(path, desc, line, lineno)),
        None => Ok(false),
    }
}

// Remove a global mark form the active stack
pub fn remove_global_mark(_: &Lua, (path, lineno): (String, i32)) -> LuaResult<bool> {
    ::tracing::info!("Removing global mark: {} at line {}", path, lineno);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.remove_global_mark(path, lineno)),
        None => Ok(false),
    }
}

// Return list of global marks in the active stack
pub fn list_global_marks(_: &Lua, path: Option<String>) -> LuaResult<Vec<marks::GlobalMark>> {
    ::tracing::info!("Listing global marks for path: {:?}", path);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        Some(ss) => {
            let mut marks = ss.list_global_marks(path);
            marks.sort_by(|a, b| a.desc.cmp(&b.desc));
            Ok(marks)
        }
        None => Ok(vec![]),
    }
}

// Return list of all global marks across projects
pub fn list_all_global_marks(_: &Lua, path: Option<String>) -> LuaResult<Vec<marks::GlobalMark>> {
    ::tracing::info!("Listing global marks for path: {:?}", path);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;

    match sm.get_stacks() {
        Some(ss) => Ok(ss.list().iter().flat_map(|s| s.list_global_marks(None)).collect()),
        None => Ok(vec![]),
    }
}

// Updates a global mark
pub fn update_global_mark(
    _: &Lua,
    (path, lineno, new_lineno, new_desc): (String, i32, Option<i32>, Option<String>),
) -> LuaResult<bool> {
    ::tracing::info!("Updating global mark for path: {} at line: {}", path, lineno);
    ::tracing::info!("new_lineno={:?}, desc={:?}", new_lineno, new_desc);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.update_global_mark(path, lineno, new_lineno, new_desc)),
        None => Ok(false),
    }
}

// Add local mark to the active stack
pub fn add_local_mark(_: &Lua, (path, lineno, line): (String, i32, String)) -> LuaResult<bool> {
    ::tracing::info!("Adding local mark: {}:{} - {}", path, lineno, line);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.add_local_mark(path, line, lineno)),
        None => Ok(false),
    }
}

// Remove a local mark form the active stack
pub fn remove_local_mark(_: &Lua, (path, lineno): (String, i32)) -> LuaResult<bool> {
    ::tracing::info!("Removing global mark: {} at line {}", path, lineno);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.remove_local_mark(path, lineno)),
        None => Ok(false),
    }
}

// Return list of local marks in the active stack
pub fn list_local_marks(_: &Lua, path: Option<String>) -> LuaResult<Vec<marks::LocalMark>> {
    ::tracing::info!("Listing local marks...");
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks() {
        Some(ss) => match path {
            Some(p) => Ok(ss
                .list_local_marks()
                .into_iter()
                .filter(|m| m.path == p)
                .collect()),
            None => Ok(ss.list_local_marks()),
        },
        None => Ok(vec![]),
    }
}

// Updates a local mark
pub fn update_local_mark(
    _: &Lua,
    (path, lineno, new_lineno): (String, i32, Option<i32>),
) -> LuaResult<bool> {
    ::tracing::info!("Updating local mark for path: {} at line: {}", path, lineno);
    ::tracing::info!("new_lineno={:?}", new_lineno);
    let mut stacks_man = STACKS.write().map_err(|_| Errors::AcquireStacksLock)?;
    let sm = Option::ok_or_else(stacks_man.as_mut(), || Errors::StacksNotInit)?;
    match sm.get_stacks_mut() {
        Some(ss) => Ok(ss.update_local_mark(path, lineno, new_lineno)),
        None => Ok(false),
    }
}

// Register your functions to be exposed to Lua.
// The function name `codestacks_nvim` will be the module name in Lua.
#[mlua::lua_module]
fn codestacks_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("init_tracing", lua.create_function(init_tracing)?)?;
    exports.set("setup", lua.create_function(setup)?)?;

    // Stack management functions
    exports.set("add_stack", lua.create_function(add_stack)?)?;
    exports.set("remove_stack", lua.create_function(remove_stack)?)?;
    exports.set("list_stacks", lua.create_function(list_stacks)?)?;
    exports.set("set_active_stack", lua.create_function(set_active_stack)?)?;
    exports.set("is_active_stack", lua.create_function(is_active_stack)?)?;
    exports.set("rename_stack", lua.create_function(rename_stack)?)?;
    exports.set("get_active_stack", lua.create_function(get_active_stack)?)?;
    exports.set("get_stack", lua.create_function(get_stack)?)?;

    // Recent files functions
    exports.set("add_recent_file", lua.create_function(add_recent_file)?)?;
    exports.set("remove_recent_file", lua.create_function(remove_recent_file)?)?;
    exports.set("list_recent_files", lua.create_function(list_recent_files)?)?;
    exports.set("enable_recent_files", lua.create_function(enable_recent_files)?)?;

    // Buffer management functions
    exports.set("pin_buffer", lua.create_function(pin_buffer)?)?;
    exports.set("unpin_buffer", lua.create_function(unpin_buffer)?)?;
    exports.set("list_pinned_buffers", lua.create_function(list_pinned_buffers)?)?;
    exports.set("get_pinned_buffer", lua.create_function(get_pinned_buffer)?)?;

    // Mark management functions
    exports.set("add_global_mark", lua.create_function(add_global_mark)?)?;
    exports.set("remove_global_mark", lua.create_function(remove_global_mark)?)?;
    exports.set("list_global_marks", lua.create_function(list_global_marks)?)?;
    exports.set(
        "list_all_global_marks",
        lua.create_function(list_all_global_marks)?,
    )?;
    exports.set("update_global_mark", lua.create_function(update_global_mark)?)?;
    // Local mark management functions
    exports.set("add_local_mark", lua.create_function(add_local_mark)?)?;
    exports.set("remove_local_mark", lua.create_function(remove_local_mark)?)?;
    exports.set("list_local_marks", lua.create_function(list_local_marks)?)?;
    exports.set("update_local_mark", lua.create_function(update_local_mark)?)?;

    Ok(exports)
}
