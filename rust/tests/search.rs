//! Search tests — reindex + quick/full search over the schema-agnostic engine.

use rust_lib_novident_project_manager::api::manager::{create_project_skeleton, open_project};
use rust_lib_novident_project_manager::api::manager::ProjectManager;
use rust_lib_novident_project_manager::api::search::{QuickMatch, StructuralMatch};
use std::fs;
use std::path::PathBuf;

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("novident_search_{tag}_{nanos}"));
        fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn setup() -> (TempDir, ProjectManager, String) {
    let t = TempDir::new("search");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();

    let id = "d4e5f6a7-b8c9-0123-defa-234567890123";
    let dir = t.0.join("files").join(id);
    fs::create_dir_all(&dir).unwrap();
    fs::write(
        dir.join("content.json"),
        r#"{"type":"page","children":[{"type":"paragraph","attributes":{"delta":[{"insert":"The quick brown fox"}]}}]}"#,
    )
    .unwrap();
    fs::write(dir.join("notes.txt"), "a plot note").unwrap();

    // Write a binder so `reindex_search` can discover the node structurally.
    let binder = serde_json::json!({
        "tree": [{"id": id, "name": "Chapter 1", "children": []}],
        "lookup": {}
    });
    fs::write(
        t.0.join("indexation/binder.index.json"),
        binder.to_string(),
    )
    .unwrap();

    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();
    pm.reindex_search().unwrap();
    (t, pm, id.to_string())
}

#[test]
fn quick_search_finds_text() {
    let (_t, pm, _id) = setup();
    let res = pm
        .search("quick".to_string(), "{}".to_string(), "quick".to_string())
        .unwrap();
    let matches: Vec<QuickMatch> = serde_json::from_str(&res).unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].field, "text");
}

#[test]
fn quick_search_is_case_insensitive_by_default() {
    let (_t, pm, _id) = setup();
    let res = pm
        .search("QUICK".to_string(), "{}".to_string(), "quick".to_string())
        .unwrap();
    let matches: Vec<QuickMatch> = serde_json::from_str(&res).unwrap();
    assert_eq!(matches.len(), 1);
}

#[test]
fn quick_search_matches_notes_and_title() {
    let (_t, pm, _id) = setup();
    let notes = pm
        .search("plot".to_string(), "{}".to_string(), "quick".to_string())
        .unwrap();
    let m: Vec<QuickMatch> = serde_json::from_str(&notes).unwrap();
    assert_eq!(m.len(), 1);
    assert_eq!(m[0].field, "notes");

    let title = pm
        .search("Chapter".to_string(), "{}".to_string(), "quick".to_string())
        .unwrap();
    let m: Vec<QuickMatch> = serde_json::from_str(&title).unwrap();
    assert_eq!(m.len(), 1);
    assert_eq!(m[0].field, "title");
}

#[test]
fn full_search_resolves_block_path() {
    let (_t, pm, _id) = setup();
    let res = pm
        .search("quick".to_string(), "{}".to_string(), "full".to_string())
        .unwrap();
    let matches: Vec<StructuralMatch> = serde_json::from_str(&res).unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].path, vec![0]);
    assert_eq!(matches[0].block_type, "paragraph");
}

#[test]
fn search_status_reflects_reindex() {
    let (_t, pm, _id) = setup();
    let status: serde_json::Value = serde_json::from_str(&pm.search_status()).unwrap();
    assert_eq!(status["stale"], false);
}
