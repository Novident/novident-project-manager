use std::path::PathBuf;

#[cfg(test)]
mod tests {
    use rust_lib_novident_project_manager::api::version::NovidentRepo;

    use super::*;

    #[test]
    fn test_open_example_project() {
        // Locate the example.nov project relative to the crate
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into());
        let base = PathBuf::from(&manifest_dir);
        let example_path = PathBuf::from(base.parent().unwrap()).join("assets/example.nov");

        // This test just verifies parsing doesn't panic
        if example_path.exists() {
            let repo = NovidentRepo::open(&example_path);
            if let Ok(repo) = repo {
                let project = repo.parse_project();
                if let Ok(proj) = project {
                    assert!(!proj.project_id.is_empty());
                    assert!(!proj.documents.is_empty());
                }
            }
        }
    }
}
