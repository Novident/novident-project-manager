//! Git + snapshot tests (local operations only; push/pull need a remote).

use rust_lib_novident_project_manager::api::manager::{create_project_skeleton, open_project};
use rust_lib_novident_project_manager::api::manager::ProjectManager;
use rust_lib_novident_project_manager::api::version::git_types::{
    GitBranchInfo, GitCommitInfo, GitStatusEntry,
};
use std::fs;
use std::path::{Path, PathBuf};

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> Self {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("novident_git_{tag}_{nanos}"));
        fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn init_git(path: &Path) {
    let repo = git2::Repository::init(path).expect("git init");
    let mut index = repo.index().expect("index");
    index
        .add_all(["*"].iter(), git2::IndexAddOption::DEFAULT, None)
        .expect("add all");
    index.write().expect("index write");
    let tree_id = index.write_tree().expect("write tree");
    let tree = repo.find_tree(tree_id).expect("find tree");
    let sig = git2::Signature::now("Test", "test@novident.dev").expect("sig");
    repo.commit(Some("HEAD"), &sig, &sig, "initial", &tree, &[])
        .expect("initial commit");
}

fn setup() -> (TempDir, ProjectManager) {
    let t = TempDir::new("git");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();
    init_git(&t.0);
    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();
    (t, pm)
}

fn author() -> String {
    serde_json::json!({"name": "Elena", "email": "e@x.com"}).to_string()
}

#[test]
fn git_commit_and_status() {
    let (_t, pm) = setup();

    let res = pm.git_commit("snapshot".to_string(), author()).unwrap();
    let v: serde_json::Value = serde_json::from_str(&res).unwrap();
    assert!(v["oid"].is_string());

    let status = pm.git_status().unwrap();
    let entries: Vec<GitStatusEntry> = serde_json::from_str(&status).unwrap();
    // After a commit the tree is clean, or whatever remains is not conflicted.
    assert!(entries.iter().all(|e| !e.is_conflicted));
}

#[test]
fn git_log_and_branches() {
    let (_t, pm) = setup();

    let log = pm.git_log(10).unwrap();
    let entries: Vec<GitCommitInfo> = serde_json::from_str(&log).unwrap();
    assert!(!entries.is_empty(), "expected at least the initial commit");
    assert!(!entries[0].oid.is_empty());

    let branches = pm.git_branches().unwrap();
    let list: Vec<GitBranchInfo> = serde_json::from_str(&branches).unwrap();
    assert!(list.iter().any(|b| b.name == "main" || b.name == "master"));
}

#[test]
fn git_command_on_non_repo_errors() {
    let t = TempDir::new("norepo");
    create_project_skeleton(t.0.to_string_lossy().to_string()).unwrap();
    let pm = open_project(t.0.to_string_lossy().to_string()).unwrap();

    let err = pm.git_commit("x".to_string(), author()).unwrap_err();
    assert_eq!(err.code, rust_lib_novident_project_manager::api::error::ErrorCode::Git);

    let err = pm.git_status().unwrap_err();
    assert_eq!(err.code, rust_lib_novident_project_manager::api::error::ErrorCode::Git);
}

#[test]
fn snapshot_create_list_restore() {
    let (_t, pm) = setup();

    let info = pm.snapshot_create(1).unwrap();
    let snap: serde_json::Value = serde_json::from_str(&info).unwrap();
    let snap_id = snap["id"].as_str().unwrap().to_string();
    assert!(!snap_id.is_empty());

    let list = pm.snapshot_list().unwrap();
    let snaps: Vec<serde_json::Value> = serde_json::from_str(&list).unwrap();
    assert_eq!(snaps.len(), 1);
    assert_eq!(snaps[0]["id"], snap_id.as_str());

    pm.snapshot_restore(snap_id).unwrap();

    // Missing snapshot → error.
    let err = pm.snapshot_restore("nope".to_string()).unwrap_err();
    assert_eq!(err.code, rust_lib_novident_project_manager::api::error::ErrorCode::Io);
}
