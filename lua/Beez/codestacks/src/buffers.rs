use mlua::{IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};
use std::{
    clone::Clone,
    fs,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
};

#[derive(Serialize, Deserialize, Clone)]
pub struct PinnedBuffer {
    pub path: String,
    pub label: String,
}

impl IntoLua for PinnedBuffer {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("path", self.path)?;
        table.set("label", self.label)?;
        Ok(LuaValue::Table(table))
    }
}

pub struct RecentFiles {
    pub target_file: PathBuf,
    pub files: Vec<String>,
    pub limit: i32,
    pub enabled: bool,
}

impl RecentFiles {
    // Instantiates recent files list
    pub fn new(base_dir: String, limit: i32) -> Self {
        let dir_path = Path::new(&base_dir);
        if !dir_path.exists() {
            fs::create_dir_all(dir_path)
                .unwrap_or_else(|_| panic!("Failed to create directory: {base_dir}"));
        }

        let target_file = dir_path.join("recentfiles.txt");
        let mut files: Vec<String> = Vec::new();
        if !target_file.exists() {
            fs::File::create(&target_file)
                .unwrap_or_else(|_| panic!("Failed to create file: {:?}", target_file.to_str()));

            fs::write(&target_file, "")
                .unwrap_or_else(|_| panic!("Failed to write to file: {:?}", target_file.to_str()));
        } else {
            let file = fs::File::open(&target_file)
                .unwrap_or_else(|_| panic!("Failed to open file: {:?}", target_file.to_str()));
            let reader = BufReader::new(file);
            match reader.lines().collect() {
                Ok(lines) => files = lines,
                Err(e) => panic!(
                    "Failed to read lines from file: {:?}, error: {}",
                    target_file.to_str(),
                    e
                ),
            }
        }

        RecentFiles {
            target_file,
            files,
            limit,
            enabled: true,
        }
    }

    // Adds a file to the recent files list
    pub fn add(&mut self, file_path: String) {
        if !self.enabled {
            return;
        }

        // Get rid of duplicates and move to front
        self.files.retain(|p| *p != file_path);
        self.files.insert(0, file_path);
        self.save();
    }

    // Removes a file from the recent files list
    pub fn remove(&mut self, file_path: String) {
        if !self.enabled {
            return;
        }
        self.files.retain(|p| *p != file_path);
        self.save();
    }

    // Lists the recent files
    pub fn list(&self) -> Vec<String> {
        self.files.clone()
    }

    // Sets enabled status
    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
    }

    // Saves the recent files list to disk
    pub fn save(&mut self) {
        // Truncate before saving
        if self.files.len() > self.limit as usize {
            self.files.truncate(self.limit as usize);
        }
        fs::write(&self.target_file, self.files.to_vec().join("\n"))
            .unwrap_or_else(|_| panic!("Failed to write to file: {:?}", self.target_file.to_str()));
    }
}
