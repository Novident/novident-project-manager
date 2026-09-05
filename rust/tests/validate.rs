//! Structural validation tests (schema-agnostic, contract-driven).

use rust_lib_novident_project_manager::api::validate::{Severity, validate_project};
use std::fs;
use std::path::{Path, PathBuf};

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("novident_val_{tag}_{nanos}"));
        fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn write(root: &Path, rel: &str, contents: &str) {
    let path = root.join(rel);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, contents).unwrap();
}

#[test]
fn empty_dir_reports_missing_required() {
    let t = TempDir::new("empty");
    let issues = validate_project(&t.0, 1);

    let missing_dirs = issues
        .iter()
        .filter(|i| i.code == "required_dir.missing")
        .count();
    let missing_files = issues
        .iter()
        .filter(|i| i.code == "required_file.missing")
        .count();
    assert!(missing_dirs >= 8, "expected >=8 missing dirs, got {missing_dirs}");
    assert!(missing_files >= 8, "expected >=8 missing files, got {missing_files}");
}

#[test]
fn minimal_valid_project_has_no_errors() {
    let t = TempDir::new("minimal");

    for dir in [
        "files",
        "files/external",
        "indexation",
        "history",
        "layouts",
        "compiler/formats",
        "compiler/exports",
        "snapshots",
    ] {
        fs::create_dir_all(t.0.join(dir)).unwrap();
    }
    for file in [
        "files/metadata.json",
        "files/backup.json",
        "indexation/icon.index.json",
        "indexation/corkboard.index.json",
        "indexation/search.index.json",
        "indexation/target.index.json",
    ] {
        write(&t.0, file, "{}");
    }
    write(
        &t.0,
        "indexation/binder.index.json",
        r#"{"tree": [], "lookup": {}}"#,
    );
    write(
        &t.0,
        "indexation/sections.index.json",
        r#"{"sections": ["structured-based"], "outline": {"folder": {}, "file": {}}}"#,
    );

    let issues = validate_project(&t.0, 1);
    let errors: Vec<_> = issues
        .iter()
        .filter(|i| i.severity == Severity::Error)
        .collect();
    assert!(errors.is_empty(), "unexpected errors: {errors:?}");
    assert!(
        issues.iter().any(|i| i.code == "optional_file.missing"),
        "missing .gitignore should be a warning"
    );
}

#[test]
fn example_project_flags_invalid_icon_index() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("src/assets/example.nov");
    let issues = validate_project(&root, 1);
    assert!(
        issues.iter().any(|i| i.path == "indexation/icon.index.json" && i.code == "json.invalid"),
        "expected icon.index.json to be flagged as invalid JSON; got: {issues:?}"
    );
}
