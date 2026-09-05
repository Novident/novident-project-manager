//! Verbatim file reads. The engine reads raw bytes/JSON and never interprets
//! the `.nov` schema (Dart owns that).

use std::fs;
use std::path::Path;

/// Reads a file relative to `root` as a UTF-8 string, if it exists and is readable.
pub fn read_file(root: &Path, relative: &str) -> Option<String> {
    fs::read_to_string(root.join(relative)).ok()
}

/// Alias for plain-text files (`notes.txt`).
pub fn read_text(root: &Path, relative: &str) -> Option<String> {
    read_file(root, relative)
}

/// Lists file names (not full paths) in a directory, sorted.
pub fn list_files(root: &Path, dir: &str) -> Vec<String> {
    let Ok(entries) = fs::read_dir(root.join(dir)) else {
        return Vec::new();
    };
    let mut out: Vec<String> = entries
        .flatten()
        .filter(|e| e.path().is_file())
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    out.sort();
    out
}

/// Lists directory names in a directory, sorted.
pub fn list_dirs(root: &Path, dir: &str) -> Vec<String> {
    let Ok(entries) = fs::read_dir(root.join(dir)) else {
        return Vec::new();
    };
    let mut out: Vec<String> = entries
        .flatten()
        .filter(|e| e.path().is_dir())
        .filter_map(|e| e.file_name().into_string().ok())
        .collect();
    out.sort();
    out
}
