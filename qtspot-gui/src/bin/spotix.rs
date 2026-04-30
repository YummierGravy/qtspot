#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    qtspot_gui::qt::launcher::run();
}
