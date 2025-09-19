use mlua::{IntoLua, Lua, Result as LuaResult, Value as LuaValue};
use serde::{Deserialize, Serialize};
use std::clone::Clone;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct LocalMark {
    pub path: String,
    pub line: String,
    pub lineno: i32,
}

impl IntoLua for LocalMark {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("path", self.path)?;
        table.set("lineno", self.lineno)?;
        table.set("line", self.line)?;
        Ok(LuaValue::Table(table))
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GlobalMark {
    pub stack: String,
    pub path: String,
    pub line: String,
    pub lineno: i32,
    pub desc: String,
}

impl IntoLua for GlobalMark {
    fn into_lua(self, lua: &Lua) -> LuaResult<LuaValue> {
        let table = lua.create_table()?;
        table.set("path", self.path)?;
        table.set("line", self.line)?;
        table.set("desc", self.desc)?;
        table.set("lineno", self.lineno)?;
        table.set("stack", self.stack)?;
        Ok(LuaValue::Table(table))
    }
}
