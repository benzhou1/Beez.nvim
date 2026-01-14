use crate::buffers::PinnedBuffer;
use crate::marks::{GlobalMark, LocalMark};
use mlua::{IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::clone::Clone;
use std::collections::HashMap;
use std::fs;
use std::io::BufReader;
use std::path::{Path, PathBuf};

#[derive(Serialize, Deserialize, Clone)]
pub struct Stack {
    name: String,
    pinned_buffers: Vec<PinnedBuffer>,
    local_marks: Vec<LocalMark>,
    global_marks: HashMap<String, Vec<GlobalMark>>,
}

impl IntoLua for Stack {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("name", self.name)?;
        table.set("pinned_buffers", self.pinned_buffers)?;
        table.set("local_marks", self.local_marks)?;
        table.set("global_marks", self.global_marks)?;
        Ok(LuaValue::Table(table))
    }
}

impl Stack {
    // Return list of global marks in this stack
    pub fn list_global_marks(&self, path: Option<String>) -> Vec<GlobalMark> {
        match path {
            Some(p) => {
                let global_marks = match self.global_marks.get(&p) {
                    Some(gm) => gm,
                    None => return Vec::new(),
                };
                global_marks.clone()
            }
            None => self
                .global_marks
                .clone()
                .into_values()
                .flatten()
                .collect::<Vec<GlobalMark>>(),
        }
    }
}

#[derive(Serialize, Deserialize)]
struct StacksIn {
    active: Option<String>,
    stacks: HashMap<String, Stack>,
}

pub struct StacksManager {
    pub active: Option<String>,
    projects: HashMap<String, Stacks>,
}

impl StacksManager {
    /// Initializes the StacksManager struct
    pub fn new(project: String, base_dir: &str) -> Self {
        let dir_path = Path::new(base_dir);
        if !dir_path.exists() {
            fs::create_dir_all(dir_path)
                .unwrap_or_else(|_| panic!("Failed to create directory: {base_dir}"));
        }

        let mut projects: HashMap<String, Stacks> = HashMap::new();
        for entry in fs::read_dir(dir_path).unwrap() {
            let entry = entry.unwrap();
            let path = entry.path();
            if path.is_dir() {
                let project_name = path.file_name().unwrap().to_str().unwrap().to_string();
                let stacks = Stacks::new(path.to_str().unwrap());
                projects.insert(project_name, stacks);
            }
        }

        StacksManager {
            active: Some(project.clone()),
            projects,
        }
    }

    // Get current active stacks
    pub fn get_stacks(&self) -> Option<&Stacks> {
        match &self.active {
            Some(name) => self.projects.get(name),
            None => None,
        }
    }
    pub fn get_stacks_mut(&mut self) -> Option<&mut Stacks> {
        match &self.active {
            Some(name) => self.projects.get_mut(name),
            None => None,
        }
    }

    // List all stacks across projects
    pub fn list_stacks(&self) -> Vec<Stacks> {
        self.projects.values().cloned().collect()
    }
}

#[derive(Clone)]
pub struct Stacks {
    target_file: PathBuf,
    pub active: Option<String>,
    stacks: HashMap<String, Stack>,
}

impl Stacks {
    /// Initializes the Stacks struct
    pub fn new(base_dir: &str) -> Self {
        let dir_path = Path::new(base_dir);
        if !dir_path.exists() {
            fs::create_dir_all(dir_path)
                .unwrap_or_else(|_| panic!("Failed to create directory: {base_dir}"));
        }

        let target_file = dir_path.join("stacks.json");
        let mut active: Option<String> = None;
        let mut stacks: HashMap<String, Stack> = HashMap::new();
        if !target_file.exists() {
            fs::File::create(&target_file)
                .unwrap_or_else(|_| panic!("Failed to create file: {:?}", target_file.to_str()));

            let j = json!({"stacks": stacks});
            fs::write(&target_file, j.to_string())
                .unwrap_or_else(|_| panic!("Failed to write to file: {:?}", target_file.to_str()));
        } else {
            let file = fs::File::open(&target_file)
                .unwrap_or_else(|_| panic!("Failed to open file: {:?}", target_file.to_str()));
            let reader = BufReader::new(file);
            let parsed: StacksIn = serde_json::from_reader(reader)
                .unwrap_or_else(|_| panic!("Failed to parse json file: {:?}", target_file.to_str()));
            stacks = parsed.stacks;
            active = parsed.active;
        }

        Stacks {
            target_file,
            active,
            stacks,
        }
    }

    /// Adds a new stack if it doesn't already exist and sets it as active
    pub fn add(&mut self, name: String) -> bool {
        if self.stacks.contains_key(&name) {
            return false;
        }
        let stack = Stack {
            name: name.to_string(),
            pinned_buffers: Vec::new(),
            local_marks: Vec::new(),
            global_marks: HashMap::new(),
        };
        self.stacks.insert(name.to_string(), stack);
        self.active = Some(name);
        self.save();
        true
    }

    /// Saves the current stacks to the target file
    pub fn save(&self) {
        // Serialize stacks to a JSON string.
        let out = StacksIn {
            active: self.active.clone(),
            stacks: self.stacks.clone(),
        };
        let j =
            serde_json::to_string(&out).unwrap_or_else(|_| panic!("Failed to serialize stacks to JSON"));

        fs::write(&self.target_file, j)
            .unwrap_or_else(|_| panic!("Failed to save to file: {:?}", self.target_file.to_str()));
    }

    /// Returns a list of all stacks
    pub fn list(&self) -> Vec<Stack> {
        self.stacks.values().cloned().collect::<Vec<Stack>>()
    }

    /// Sets the active stack by name if it exists
    pub fn set_active(&mut self, name: String) -> bool {
        if !self.stacks.contains_key(&name) {
            return false;
        }
        self.active = Some(name);
        self.save();
        true
    }

    /// Checks if the given name is the active stack
    pub fn is_active(&self, name: String) -> bool {
        match &self.active {
            Some(active_name) => active_name == &name,
            None => false,
        }
    }

    /// Gets a stack by name if it exists
    pub fn get(&self, name: Option<String>) -> Option<Stack> {
        if name.is_none() {
            match &self.active {
                Some(active_name) => return self.stacks.get(active_name).cloned(),
                None => return None,
            }
        }
        self.stacks.get(&name.clone().unwrap()).cloned()
    }

    /// Removes a stack by name and returns it if it existed
    pub fn remove(&mut self, name: String) -> Option<Stack> {
        let stack = self.get(Some(name.clone()));
        match stack {
            Some(s) => {
                self.stacks.remove(name.as_str());
                if self.active == Some(name) {
                    self.active = None;
                }
                self.save();
                Some(s)
            }
            None => None,
        }
    }

    /// Renames a stack with old name to a new one
    pub fn rename(&mut self, old_name: String, new_name: String) -> bool {
        if !self.stacks.contains_key(&old_name) || self.stacks.contains_key(&new_name) {
            return false;
        }
        let mut stack = self.stacks.remove(&old_name).unwrap();
        stack.name = new_name.clone();
        self.stacks.insert(new_name.clone(), stack);
        if self.active == Some(old_name) {
            self.active = Some(new_name);
        }
        self.save();
        true
    }

    // Pins a buffer by path and a label to the active stack
    pub fn pin_buffer(&mut self, path: String, label: String) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        // First remove any existing pinned buffer with the same path and label
        stack
            .pinned_buffers
            .retain(|b| b.path != path && b.label != label);

        let pb = PinnedBuffer { path, label };
        stack.pinned_buffers.push(pb);
        self.save();
        true
    }

    // Unpins a buffer by path from the active stack
    pub fn unpin_buffer(&mut self, path: String) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let original_len = stack.pinned_buffers.len();
        stack.pinned_buffers.retain(|b| b.path != path);
        if stack.pinned_buffers.len() == original_len {
            return false;
        }
        self.save();
        true
    }

    // Return a list of pinned buffers in the active stack
    pub fn list_pinned_buffers(&self) -> Vec<PinnedBuffer> {
        let stack = match self.get(None) {
            Some(s) => s,
            None => return Vec::new(),
        };
        stack.pinned_buffers
    }

    // Finds a pinned buffer by path in the active stack
    pub fn get_pinned_buffer(&self, path: String) -> Option<PinnedBuffer> {
        let stack = self.get(None)?;
        stack.pinned_buffers.into_iter().find(|pb| pb.path == path)
    }

    // Adds a global mark to the active stack
    pub fn add_global_mark(&mut self, path: String, desc: String, line: String, lineno: i32) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let global_mark = GlobalMark {
            stack: active_name.clone(),
            path: path.clone(),
            desc,
            line,
            lineno,
        };
        match stack.global_marks.contains_key(&path) {
            true => {
                let marks = stack.global_marks.get_mut(&path).unwrap();
                for gm in marks.iter_mut() {
                    if gm.lineno == lineno {
                        gm.desc = global_mark.desc;
                        gm.line = global_mark.line;
                        self.save();
                        return true;
                    }
                }
                marks.push(global_mark);
            }
            false => {
                stack.global_marks.insert(path, vec![global_mark]);
            }
        }
        self.save();
        true
    }

    // Removes a global mark from active stack
    pub fn remove_global_mark(&mut self, path: String, lineno: i32) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let global_marks = match stack.global_marks.get_mut(&path) {
            Some(gm) => gm,
            None => return false,
        };

        let original_len = global_marks.len();
        global_marks.retain(|m| !(m.path == path && m.lineno == lineno));
        if stack.global_marks.len() == original_len {
            return false;
        }
        self.save();
        true
    }

    // Return list of global marks in the active stack
    pub fn list_global_marks(&self, path: Option<String>) -> Vec<GlobalMark> {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return Vec::new(),
        };
        let stack = match self.stacks.get(&active_name) {
            Some(s) => s,
            None => return Vec::new(),
        };
        stack.list_global_marks(path)
    }

    // Updates a global mark
    pub fn update_global_mark(
        &mut self,
        path: String,
        lineno: i32,
        new_lineno: Option<i32>,
        new_desc: Option<String>,
    ) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let global_marks = match stack.global_marks.get_mut(&path) {
            Some(gm) => gm,
            None => return false,
        };
        let mut save = false;
        for gm in global_marks {
            if gm.path == path && gm.lineno == lineno {
                if new_lineno.is_some() {
                    gm.lineno = new_lineno.unwrap();
                    save = true;
                }
                if new_desc.is_some() {
                    ::tracing::info!("Updating desc to {:?}", new_desc);
                    gm.desc = new_desc.clone().unwrap();
                    save = true;
                }
            }
        }
        if save {
            self.save();
        }
        save
    }

    // Adds a local mark to the active stack
    pub fn add_local_mark(&mut self, path: String, line: String, lineno: i32) -> bool {
        self.remove_local_mark(path.clone(), lineno);
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let local_mark = LocalMark { path, line, lineno };
        stack.local_marks.push(local_mark);
        self.save();
        true
    }

    // Removes a local mark from active stack
    pub fn remove_local_mark(&mut self, path: String, lineno: i32) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };

        let original_len = stack.local_marks.len();
        stack
            .local_marks
            .retain(|m| !(m.path == path && m.lineno == lineno));

        // Dont save if nothing was removed
        if stack.local_marks.len() == original_len {
            return false;
        }
        self.save();
        true
    }

    // Return list of local marks in the active stack
    pub fn list_local_marks(&self) -> Vec<LocalMark> {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return Vec::new(),
        };
        let stack = match self.stacks.get(&active_name) {
            Some(s) => s,
            None => return Vec::new(),
        };
        stack.local_marks.clone()
    }

    // Updates a local mark
    pub fn update_local_mark(&mut self, path: String, lineno: i32, new_lineno: Option<i32>) -> bool {
        let active_name = match &self.active {
            Some(name) => name.clone(),
            None => return false,
        };
        let stack = match self.stacks.get_mut(&active_name) {
            Some(s) => s,
            None => return false,
        };
        let mut save = false;
        for lm in stack.local_marks.iter_mut() {
            if lm.path == path && lm.lineno == lineno && new_lineno.is_some() {
                lm.lineno = new_lineno.unwrap();
                save = true;
            }
        }
        if save {
            self.save();
        }
        save
    }
}
