use git2::Repository;
use std::path::Path;

use super::git_service::{GitResult, GitServiceError};

/// How to resolve a merge conflict.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConflictResolution {
    /// Accept the "ours" side (current branch).
    AcceptOurs,
    /// Accept the "theirs" side (incoming branch).
    AcceptTheirs,
    /// Provide custom content as the resolved version.
    Custom(String),
}

/// Information about a single conflicted file.
#[derive(Debug, Clone)]
pub struct ConflictInfo {
    /// Relative path within the repository.
    pub path: String,
    /// Content from the current branch (ours).
    pub ours_content: Option<String>,
    /// Content from the incoming branch (theirs).
    pub theirs_content: Option<String>,
    /// Content from the common ancestor (base).
    pub ancestor_content: Option<String>,
    /// Whether the file was deleted on one side.
    pub ours_deleted: bool,
    pub theirs_deleted: bool,
}

/// Manages merge conflict detection and resolution.
///
/// After a merge operation results in conflicts, use this manager to:
/// 1. List conflicted files
/// 2. Inspect conflict details
/// 3. Resolve individual or all conflicts
/// 4. Abort the merge entirely
pub struct ConflictManager<'repo> {
    repo: &'repo Repository,
}

impl<'repo> ConflictManager<'repo> {
    pub fn new(repo: &'repo Repository) -> Self {
        Self { repo }
    }

    /// Check whether the repository is currently in a merge conflict state.
    pub fn is_in_conflict(&self) -> bool {
        self.repo
            .index()
            .ok()
            .is_some_and(|idx| idx.has_conflicts())
    }

    /// List all conflicted files with their details.
    pub fn detect_conflicts(&self) -> GitResult<Vec<ConflictInfo>> {
        let index = self.repo.index().map_err(GitServiceError::Git)?;
        let conflicts = index.conflicts().map_err(|e| GitServiceError::Git(e))?;

        let mut result = Vec::new();

        for conflict_result in conflicts {
            let conflict = conflict_result.map_err(|e| {
                GitServiceError::Git(git2::Error::new(
                    git2::ErrorCode::GenericError,
                    git2::ErrorClass::Index,
                    format!("Conflict iteration error: {}", e),
                ))
            })?;

            // Get the path from any side that exists
            let path = conflict
                .our
                .as_ref()
                .or(conflict.their.as_ref())
                .or(conflict.ancestor.as_ref())
                .map(|entry| String::from_utf8_lossy(&entry.path).to_string())
                .unwrap_or_else(|| "<unknown>".into());

            let ours_deleted = conflict.our.is_none();
            let theirs_deleted = conflict.their.is_none();

            let ancestor_content = conflict
                .ancestor
                .and_then(|entry| self.read_blob_content(entry.id));

            let ours_content = conflict
                .our
                .and_then(|entry| self.read_blob_content(entry.id));
            let theirs_content = conflict
                .their
                .and_then(|entry| self.read_blob_content(entry.id));

            result.push(ConflictInfo {
                path,
                ours_content,
                theirs_content,
                ancestor_content,
                ours_deleted,
                theirs_deleted,
            });
        }

        Ok(result)
    }

    /// Resolve a single conflicted file.
    ///
    /// After resolving all conflicts, call `finish_resolution()` to finalize.
    pub fn resolve(&self, path: &str, resolution: ConflictResolution) -> GitResult<()> {
        let mut index = self.repo.index().map_err(GitServiceError::Git)?;

        // Remove the conflicted entries from the index
        let path_bytes = Path::new(path);
        index.remove(path_bytes, 0).map_err(|e| {
            GitServiceError::Git(git2::Error::new(
                git2::ErrorCode::GenericError,
                git2::ErrorClass::Index,
                format!("Failed to remove conflict for {}: {}", path, e),
            ))
        })?;

        // Resolve based on strategy
        let resolved_content = match resolution {
            ConflictResolution::AcceptOurs => {
                // Read stage 2 (ours) from previous conflict entries
                // We re-read by marking it resolved
                self.read_stage_content(path, 2)?
            }
            ConflictResolution::AcceptTheirs => self.read_stage_content(path, 3)?,
            ConflictResolution::Custom(content) => Some(content),
        };

        // If there's content, write it to the working directory and re-stage
        if let Some(content) = resolved_content {
            let workdir = self
                .repo
                .workdir()
                .ok_or_else(|| GitServiceError::Other("No workdir".into()))?;
            let file_path = workdir.join(path);
            if let Some(parent) = file_path.parent() {
                std::fs::create_dir_all(parent).map_err(GitServiceError::Io)?;
            }
            std::fs::write(&file_path, &content).map_err(GitServiceError::Io)?;

            // Re-add to index (stage 0)
            let mut index = self.repo.index().map_err(GitServiceError::Git)?;
            index
                .add_path(Path::new(path))
                .map_err(GitServiceError::Git)?;
            index.write().map_err(GitServiceError::Git)?;
        }

        Ok(())
    }

    /// Resolve all conflicts with the same strategy.
    pub fn resolve_all(&self, resolution: ConflictResolution) -> GitResult<()> {
        let conflicts = self.detect_conflicts()?;
        let resolve_fn = &resolution;

        for conflict in &conflicts {
            self.resolve(&conflict.path, resolve_fn.clone())?;
        }

        Ok(())
    }

    /// Finish conflict resolution by writing the final index.
    /// Call this after resolving all conflicts.
    pub fn finish_resolution(&self) -> GitResult<()> {
        let mut index = self.repo.index().map_err(GitServiceError::Git)?;
        index.write().map_err(GitServiceError::Git)?;

        // Clean up merge state
        self.repo.cleanup_state().map_err(GitServiceError::Git)?;

        Ok(())
    }

    /// Abort the current merge operation, returning to the pre-merge state.
    pub fn abort_merge(&self) -> GitResult<()> {
        // Reset the index and working directory to HEAD
        let head = self.repo.head().map_err(GitServiceError::Git)?;
        let head_commit = head
            .peel(git2::ObjectType::Commit)
            .map_err(GitServiceError::Git)?;
        let head_tree = head_commit
            .as_commit()
            .ok_or_else(|| GitServiceError::Other("HEAD is not a commit".into()))?
            .tree()
            .map_err(GitServiceError::Git)?;

        self.repo
            .checkout_tree(
                head_tree.as_object(),
                Some(git2::build::CheckoutBuilder::default().force()),
            )
            .map_err(GitServiceError::Git)?;

        self.repo.cleanup_state().map_err(GitServiceError::Git)?;

        Ok(())
    }

    /// Get a reference to the underlying repository.
    pub fn repo(&self) -> &Repository {
        self.repo
    }

    // ─── Private helpers ───

    fn read_blob_content(&self, oid: git2::Oid) -> Option<String> {
        self.repo
            .find_blob(oid)
            .ok()
            .and_then(|blob| String::from_utf8(blob.content().to_vec()).ok())
    }

    /// Read content from a specific merge stage (1=ancestor, 2=ours, 3=theirs).
    fn read_stage_content(&self, path: &str, stage: i32) -> GitResult<Option<String>> {
        // After removing conflicts from the index, the staged content is gone.
        // We try to read from the original branch references.
        let head = self.repo.head().map_err(GitServiceError::Git)?;
        let head_tree = head
            .peel(git2::ObjectType::Commit)
            .map_err(GitServiceError::Git)?
            .as_commit()
            .and_then(|c| c.tree().ok())
            .ok_or_else(|| GitServiceError::Other("Cannot read HEAD tree".into()))?;

        match stage {
            2 => {
                // Ours — from HEAD
                head_tree
                    .get_path(Path::new(path))
                    .ok()
                    .and_then(|entry| self.read_blob_content(entry.id()))
                    .map_or(Ok(None), |c| Ok(Some(c)))
            }
            3 => {
                // Theirs — try MERGE_HEAD
                self.repo
                    .find_reference("MERGE_HEAD")
                    .ok()
                    .and_then(|r| r.peel(git2::ObjectType::Commit).ok())
                    .and_then(|c| c.as_commit().and_then(|c| c.tree().ok()))
                    .and_then(|tree| tree.get_path(Path::new(path)).ok())
                    .and_then(|entry| self.read_blob_content(entry.id()))
                    .map_or(Ok(None), |c| Ok(Some(c)))
            }
            _ => Ok(None),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_conflicts_on_clean_repo() {
        let tmp = std::env::temp_dir().join("novident_conflict_test");
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();

        let repo = Repository::init(&tmp).unwrap();
        let cm = ConflictManager::new(&repo);
        assert!(!cm.is_in_conflict());

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
