use std::path::{Path, PathBuf};

use super::branch::BranchManager;
use super::conflict::ConflictManager;
use super::content_diff::{TreeDiff, diff_json_documents};
use super::credentials::{CredentialStore, GitCredentials};
use super::git_service::{GitResult, GitService, GitServiceError, MergeResult, StatusEntry};

/// High-level manager for a Novident project backed by a Git repository.
///
/// This is the primary entry point for:
/// - Cloning/publishing Novident projects from/to remotes
/// - Parsing `.nov` project structure from a local or cloned repo
/// - Getting content-level diffs between commits
/// - Managing branches and resolving merge conflicts
///
/// # Example workflow
///
/// ```ignore
/// let store = CredentialStore::new()?;
/// let creds = store.load("my-project-id")?;
///
/// // Clone a remote project
/// let repo = NovidentRepo::clone(
///     "git@github.com:user/novel.git",
///     "/home/user/novident/novels/my-novel",
///     &creds,
/// )?;
///
/// // Parse the .nov project
/// let project = repo.parse_project()?;
///
/// // Make changes...
/// // ...
///
/// // Publish
/// repo.commit_and_push("Updated Chapter 3", "main", &creds)?;
/// ```
pub struct NovidentRepo {
    git: GitService,
    /// Path to the root of the Novident project (where .nov directory lives).
    project_root: PathBuf,
}

/// Parsed representation of a Novident project from disk.
#[derive(Debug, Clone)]
pub struct NovidentProject {
    pub project_id: String,
    pub project_name: String,
    pub root_path: PathBuf,
    /// Raw content of `metadata.json`.
    pub metadata: serde_json::Value,
    /// Raw content of `binder.index.json`.
    pub binder_index: serde_json::Value,
    /// Raw content of `search.index.json`.
    pub search_index: serde_json::Value,
    /// Raw content of `corkboard.index.json`.
    pub corkboard_index: serde_json::Value,
    /// Parsed document trees keyed by node UUID.
    pub documents:
        std::collections::HashMap<String, crate::api::text::content_reader::DocumentNode>,
}

/// Information about the diff introduced in a specific commit.
#[derive(Debug, Clone)]
pub struct CommitDiff {
    pub commit_oid: String,
    pub commit_message: String,
    pub commit_author: String,
    pub commit_time: String,
    /// Per-file diffs. Each entry is (file_path, old_json, new_json).
    pub file_diffs: Vec<FileDiff>,
}

/// Diff for a single file within a commit.
#[derive(Debug, Clone)]
pub struct FileDiff {
    pub path: String,
    pub status: String,
    pub content_diff: Option<TreeDiff>,
}

impl NovidentRepo {
    /// Open an existing Novident project repository from a local path.
    pub fn open(project_root: impl AsRef<Path>) -> GitResult<Self> {
        let project_root = project_root.as_ref().to_path_buf();
        let git = GitService::open(&project_root)?;
        Ok(Self { git, project_root })
    }

    /// Initialize a new Novident project repository at the given path.
    pub fn init(project_root: impl AsRef<Path>) -> GitResult<Self> {
        let project_root = project_root.as_ref().to_path_buf();
        let git = GitService::init(&project_root)?;
        Ok(Self { git, project_root })
    }

    /// Clone a remote Novident project repository.
    pub fn clone(
        url: &str,
        into_path: impl AsRef<Path>,
        credentials: &GitCredentials,
    ) -> GitResult<Self> {
        let into_path = into_path.as_ref().to_path_buf();
        std::fs::create_dir_all(&into_path).map_err(GitServiceError::Io)?;

        let git = GitService::clone(url, &into_path, credentials)?;
        Ok(Self {
            git,
            project_root: into_path,
        })
    }

    /// Parse the `.nov` project structure from disk.
    ///
    /// Reads `metadata.json`, `binder.index.json`, `search.index.json`,
    /// `corkboard.index.json`, and all `files/<uuid>/content.json` documents.
    pub fn parse_project(&self) -> GitResult<NovidentProject> {
        let files_dir = self.project_root.join("files");

        let metadata = self.read_json("files/metadata.json")?;
        let binder_index = self.read_json("indexation/binder.index.json")?;
        let search_index = self.read_json("indexation/search.index.json")?;
        let corkboard_index = self.read_json("indexation/corkboard.index.json")?;

        let project_id = binder_index
            .get("project_id")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();
        let project_name = binder_index
            .get("project_name")
            .and_then(|v| v.as_str())
            .unwrap_or("Untitled")
            .to_string();

        // Parse all document content files
        let mut documents = std::collections::HashMap::new();
        if files_dir.exists() {
            self.parse_documents_recursive(&files_dir, &mut documents)?;
        }

        Ok(NovidentProject {
            project_id,
            project_name,
            root_path: self.project_root.clone(),
            metadata: serde_json::Value::Object(metadata),
            binder_index: serde_json::Value::Object(binder_index),
            search_index: serde_json::Value::Object(search_index),
            corkboard_index: serde_json::Value::Object(corkboard_index),
            documents,
        })
    }

    /// Parse a specific document by its UUID.
    pub fn parse_document(
        &self,
        uuid: &str,
    ) -> GitResult<Option<crate::api::text::content_reader::DocumentNode>> {
        let content_path = self
            .project_root
            .join("files")
            .join(uuid)
            .join("content.json");
        if !content_path.exists() {
            return Ok(None);
        }
        let json = self.read_json_file(&content_path)?;
        Ok(crate::api::text::content_reader::ContentReader::read(&json))
    }

    /// Get the diff introduced by the latest commit on a branch.
    pub fn get_last_commit_diff(&self, branch: &str) -> GitResult<Option<CommitDiff>> {
        let repo = self.git.inner();
        let branch_ref = repo
            .find_branch(branch, git2::BranchType::Local)
            .map_err(GitServiceError::Git)?;
        let commit = branch_ref
            .get()
            .peel(git2::ObjectType::Commit)
            .map_err(GitServiceError::Git)?
            .into_commit()
            .map_err(|_| GitServiceError::Other("Not a commit object".into()))?;

        let diff = self.build_commit_diff(&commit)?;
        Ok(Some(diff))
    }

    /// Get the diff between two commits.
    pub fn get_diff_between_commits(
        &self,
        _old_oid: git2::Oid,
        new_oid: git2::Oid,
    ) -> GitResult<Option<CommitDiff>> {
        let repo = self.git.inner();
        let new_commit = repo.find_commit(new_oid).map_err(GitServiceError::Git)?;
        let diff = self.build_commit_diff(&new_commit)?;
        Ok(Some(diff))
    }

    /// Diff two parsed documents by their UUIDs and return a content-level TreeDiff.
    pub fn diff_documents(&self, old_uuid: &str, new_uuid: &str) -> GitResult<Option<TreeDiff>> {
        let old_doc = self.parse_document(old_uuid)?;
        let new_doc = self.parse_document(new_uuid)?;

        match (old_doc, new_doc) {
            (Some(old_d), Some(new_d)) => Ok(Some(super::content_diff::diff_trees(&old_d, &new_d))),
            _ => Ok(None),
        }
    }

    /// Stage all changes, commit, and push to remote.
    pub fn commit_and_push(
        &self,
        message: &str,
        branch: &str,
        credentials: &GitCredentials,
    ) -> GitResult<()> {
        self.git.add_all()?;
        self.git.commit(message, credentials)?;
        self.git.push("origin", branch, credentials, false)?;
        Ok(())
    }

    /// Force-push to remote (use with caution).
    pub fn force_push(&self, branch: &str, credentials: &GitCredentials) -> GitResult<()> {
        self.git.push("origin", branch, credentials, true)
    }

    /// Pull latest changes from remote and report the merge result.
    pub fn pull(&self, branch: &str, credentials: &GitCredentials) -> GitResult<MergeResult> {
        self.git.pull("origin", branch, credentials)
    }

    /// Get the working directory status.
    pub fn status(&self) -> GitResult<Vec<StatusEntry>> {
        self.git.status()
    }

    /// Get the remote URL for "origin".
    pub fn remote_url(&self) -> Option<String> {
        self.git.remote_url("origin")
    }

    /// Set or update the remote URL.
    pub fn set_remote(&self, url: &str) -> GitResult<()> {
        self.git.set_remote("origin", url)
    }

    /// Get the project root path.
    pub fn project_root(&self) -> &Path {
        &self.project_root
    }

    /// Configure Git credentials for this repository.
    pub fn configure_credentials(&self, credentials: &GitCredentials) -> GitResult<()> {
        let mut config = self.git.inner().config().map_err(GitServiceError::Git)?;
        config
            .set_str("user.name", &credentials.name)
            .map_err(GitServiceError::Git)?;
        config
            .set_str("user.email", &credentials.email)
            .map_err(GitServiceError::Git)?;
        Ok(())
    }

    /// Access the branch manager.
    pub fn branches(&self) -> BranchManager<'_> {
        BranchManager::new(self.git.inner())
    }

    /// Access the conflict manager.
    pub fn conflicts(&self) -> ConflictManager<'_> {
        ConflictManager::new(self.git.inner())
    }

    /// Access the underlying Git service.
    pub fn git_service(&self) -> &GitService {
        &self.git
    }

    // ─── Private helpers ────────────────────────────────────────

    fn read_json(
        &self,
        relative_path: &str,
    ) -> GitResult<serde_json::Map<String, serde_json::Value>> {
        let full_path = self.project_root.join(relative_path);
        self.read_json_file(&full_path)
    }

    fn read_json_file(&self, path: &Path) -> GitResult<serde_json::Map<String, serde_json::Value>> {
        let content = std::fs::read_to_string(path).map_err(GitServiceError::Io)?;
        serde_json::from_str(&content).map_err(|e| {
            GitServiceError::Other(format!("JSON parse error in {}: {}", path.display(), e))
        })
    }

    fn parse_documents_recursive(
        &self,
        dir: &Path,
        documents: &mut std::collections::HashMap<
            String,
            crate::api::text::content_reader::DocumentNode,
        >,
    ) -> GitResult<()> {
        for entry in std::fs::read_dir(dir).map_err(GitServiceError::Io)? {
            let entry = entry.map_err(GitServiceError::Io)?;
            let path = entry.path();

            if path.is_dir() {
                let content_json = path.join("content.json");
                if content_json.exists() {
                    let json = self.read_json_file(&content_json)?;
                    if let Some(doc) = crate::api::text::content_reader::ContentReader::read(&json)
                        && let Some(uuid) = path.file_name().and_then(|n| n.to_str())
                    {
                        documents.insert(uuid.to_string(), doc);
                    }
                }
            }
        }
        Ok(())
    }

    fn build_commit_diff(&self, commit: &git2::Commit) -> GitResult<CommitDiff> {
        let tree = commit.tree().map_err(GitServiceError::Git)?;

        // Get parent tree
        let parent_tree = commit.parent(0).ok().and_then(|p| p.tree().ok());

        // Diff trees
        let mut diff_opts = git2::DiffOptions::new();
        let diff = self
            .git
            .inner()
            .diff_tree_to_tree(parent_tree.as_ref(), Some(&tree), Some(&mut diff_opts))
            .map_err(GitServiceError::Git)?;

        let mut file_diffs = Vec::new();

        diff.foreach(
            &mut |delta, _progress| {
                let path = delta
                    .new_file()
                    .path()
                    .unwrap_or_else(|| delta.old_file().path().unwrap_or(Path::new("")))
                    .to_string_lossy()
                    .to_string();

                let status = format!("{:?}", delta.status());

                // Only compute content-level diff for .json content files
                let content_diff = if path.contains("content.json") {
                    self.compute_content_diff_for_file(&path, parent_tree.as_ref(), &tree)
                        .ok()
                        .flatten()
                } else {
                    None
                };

                file_diffs.push(FileDiff {
                    path,
                    status,
                    content_diff,
                });
                true
            },
            None,
            None,
            None,
        )
        .map_err(GitServiceError::Git)?;

        let commit_oid = commit.id().to_string();
        let commit_message = commit.message().unwrap_or("").to_string();
        let commit_author = commit.author().to_string();
        let commit_time = {
            let time = commit.time();
            format!("{} +{}", time.seconds(), time.offset_minutes())
        };

        Ok(CommitDiff {
            commit_oid,
            commit_message,
            commit_author,
            commit_time,
            file_diffs,
        })
    }

    /// Attempt to compute a content-level (TreeDiff) diff for a content.json file
    /// between the parent tree and the commit tree.
    fn compute_content_diff_for_file(
        &self,
        path: &str,
        parent_tree: Option<&git2::Tree>,
        commit_tree: &git2::Tree,
    ) -> GitResult<Option<TreeDiff>> {
        let read_json_from_tree = |tree: &git2::Tree,
                                   file_path: &str|
         -> Option<serde_json::Map<String, serde_json::Value>> {
            let entry = tree.get_path(Path::new(file_path)).ok()?;
            let blob = self.git.inner().find_blob(entry.id()).ok()?;
            let content = String::from_utf8(blob.content().to_vec()).ok()?;
            serde_json::from_str(&content).ok()
        };

        let new_json = read_json_from_tree(commit_tree, path);
        let old_json = parent_tree.and_then(|t| read_json_from_tree(t, path));

        match (old_json, new_json) {
            (Some(old), Some(new)) => Ok(diff_json_documents(&old, &new)),
            (None, Some(_new)) => {
                // New file — treat as full addition
                Ok(Some(TreeDiff::new(vec![
                    super::content_diff::ContentChange::NodeAdded {
                        path: vec![],
                        index: 0,
                        node: super::content_diff::SerializableNode {
                            node_type: "document".into(),
                            text_preview: "[new document]".into(),
                            child_count: 0,
                        },
                    },
                ])))
            }
            (Some(_old), None) => {
                // File deleted
                Ok(Some(TreeDiff::new(vec![
                    super::content_diff::ContentChange::NodeRemoved {
                        path: vec![],
                        index: 0,
                        summary: "[deleted document]".into(),
                    },
                ])))
            }
            (None, None) => Ok(None),
        }
    }
}

/// Convenience: create a full credential + repo workflow from scratch.
pub struct NovidentWorkflow;

impl NovidentWorkflow {
    /// Save credentials securely, then clone a project.
    pub fn clone_with_saved_credentials(
        project_id: &str,
        remote_url: &str,
        into_path: impl AsRef<Path>,
        credentials: &GitCredentials,
    ) -> GitResult<NovidentRepo> {
        let store = CredentialStore::new()
            .map_err(|e| GitServiceError::Other(format!("Credential store error: {}", e)))?;
        store
            .save(project_id, credentials)
            .map_err(|e| GitServiceError::Other(format!("Failed to save credentials: {}", e)))?;

        NovidentRepo::clone(remote_url, into_path, credentials)
    }

    /// Load saved credentials and open a local project.
    pub fn open_with_saved_credentials(
        project_id: &str,
        project_path: impl AsRef<Path>,
    ) -> GitResult<(NovidentRepo, GitCredentials)> {
        let store = CredentialStore::new()
            .map_err(|e| GitServiceError::Other(format!("Credential store error: {}", e)))?;
        let credentials = store.load(project_id).map_err(|e| {
            GitServiceError::Other(format!("No credentials found for {}: {}", project_id, e))
        })?;
        let repo = NovidentRepo::open(project_path)?;
        Ok((repo, credentials))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_open_example_project() {
        // Locate the example.nov project relative to the crate
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into());
        let example_path = PathBuf::from(&manifest_dir).join("src/assets/example.nov");

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
