use std::env;
use std::fs;
use std::io::{self, BufRead, Write};
use std::path::PathBuf;

struct Task {
    text: String,
    is_done: bool,
}

fn get_paths() -> (PathBuf, PathBuf) {
    let home = env::var("HOME").expect("HOME not found");
    
    let mut md_path = PathBuf::from(&home);
    md_path.push(".todo.md");
    
    // Прячем QML файл от системы автоперезагрузки Quickshell!
    let qml_path = PathBuf::from("/tmp/TodoData.qml");
    
    (md_path, qml_path)
}

fn load_tasks(path: &PathBuf) -> Vec<Task> {
    let mut tasks = Vec::new();
    if let Ok(file) = fs::File::open(path) {
        let reader = io::BufReader::new(file);
        for line in reader.lines().filter_map(Result::ok) {
            let t = line.trim();
            if t.starts_with("- [ ] ") { tasks.push(Task { text: t[6..].to_string(), is_done: false }); }
            else if t.starts_with("- [x] ") || t.starts_with("- [X] ") { tasks.push(Task { text: t[6..].to_string(), is_done: true }); }
        }
    }
    tasks
}

fn save_md(path: &PathBuf, tasks: &[Task]) {
    if let Ok(mut f) = fs::File::create(path) {
        for t in tasks {
            let mark = if t.is_done { "x" } else { " " };
            writeln!(f, "- [{}] {}", mark, t.text).unwrap();
        }
    }
}

// 💅 МАГИЯ ЗДЕСЬ: Генерируем нативный QML-компонент
fn save_qml(path: &PathBuf, tasks: &[Task]) {
    if let Ok(mut f) = fs::File::create(path) {
        writeln!(f, "import QtQuick").unwrap();
        writeln!(f, "ListModel {{").unwrap();
        
        for task in tasks {
            let esc = task.text.replace('\\', "\\\\").replace('\"', "\\\"");
            let bool_str = if task.is_done { "true" } else { "false" };
            writeln!(f, "    ListElement {{ taskText: \"{}\"; isDone: {} }}", esc, bool_str).unwrap();
        }
        
        writeln!(f, "}}").unwrap();
    }
}

fn main() {
    let (md_path, qml_path) = get_paths();
    let mut tasks = load_tasks(&md_path);
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 {
        let command = args[1].as_str();
        match command {
            "add" if args.len() > 2 => {
                tasks.insert(0, Task { text: args[2..].join(" "), is_done: false });
                save_md(&md_path, &tasks);
            }
            "toggle" if args.len() > 2 => {
                if let Ok(idx) = args[2].parse::<usize>() {
                    if idx < tasks.len() { tasks[idx].is_done = !tasks[idx].is_done; save_md(&md_path, &tasks); }
                }
            }
            "delete" if args.len() > 2 => {
                if let Ok(idx) = args[2].parse::<usize>() {
                    if idx < tasks.len() { tasks.remove(idx); save_md(&md_path, &tasks); }
                }
            }
            _ => {} 
        }
    }
    
    // Перезаписываем QML файл при любом чихе
    save_qml(&qml_path, &tasks);
}