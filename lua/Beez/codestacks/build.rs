fn main() {
    // Use pkg-config to find and link LuaJIT
    pkg_config::Config::new()
        .atleast_version("2.1")
        .probe("luajit")
        .unwrap();
}
