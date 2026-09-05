use std::fs;
use std::path::PathBuf;

#[cfg(test)]
mod tests {
    use rust_lib_novident_project_manager::api::snapshot::SnapshotManager;

    use super::*;

    fn temp_root(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "novident-snap-{}-{tag}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn delete_removes_snapshot_and_errors_on_unknown_id() {
        let root = temp_root("delete");
        let manager = SnapshotManager::new(&root);
        let info = manager.create(1).expect("create");

        manager.delete(&info.id).expect("delete");
        assert!(!root.join("snapshots").join(&info.filename).exists());

        // Deleting twice (unknown id) is an error.
        assert!(manager.delete(&info.id).is_err());

        fs::remove_dir_all(&root).ok();
    }
}
