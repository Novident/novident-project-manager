//! Verbatim I/O tests — the core invariant of the schema-agnostic engine:
//! a write followed by a read must be byte-exact (no re-serialization).

use rust_lib_novident_project_manager::api::manager::{create_project_skeleton, open_project};
use std::fs;
use std::path::PathBuf;

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("novident_io_{tag}_{nanos}"));
        fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

#[test]
fn write_read_roundtrip_is_verbatim() {
    let t = TempDir::new("roundtrip");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();
    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();

    // A schema file with a "future" field Dart might add — must survive verbatim.
    let json = r#"{"schema_version":1,"project":{"name":"X"},"future_field":123,"nested":{"a":true}}"#;
    pm.write_file("files/metadata.json".to_string(), json.to_string())
        .unwrap();

    let read = pm.read_file("files/metadata.json".to_string()).unwrap();
    assert_eq!(read, json, "write→read must be byte-exact");

    pm.write_file("indexation/binder.index.json".to_string(), "{}".to_string())
        .unwrap();
    assert_eq!(
        pm.read_file("indexation/binder.index.json".to_string())
            .unwrap(),
        "{}"
    );
}

#[test]
fn delete_file_is_idempotent() {
    let t = TempDir::new("delete");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();
    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();

    pm.write_file("layouts/a.json".to_string(), "{}".to_string())
        .unwrap();
    pm.delete_file("layouts/a.json".to_string()).unwrap();
    assert!(pm.read_file("layouts/a.json".to_string()).is_none());

    // Deleting again is not an error.
    pm.delete_file("layouts/a.json".to_string()).unwrap();
}

#[test]
fn list_files_lists_sorted() {
    let t = TempDir::new("list");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();
    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();

    pm.write_file("layouts/b.json".to_string(), "{}".to_string())
        .unwrap();
    pm.write_file("layouts/a.json".to_string(), "{}".to_string())
        .unwrap();

    assert_eq!(
        pm.list_files("layouts".to_string()),
        vec!["a.json".to_string(), "b.json".to_string()]
    );
}
