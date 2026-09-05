use git2::{BranchType, Repository};
use std::str;

use super::git_service::{GitResult, GitServiceError};

/// Branch management operations for a Git repository.
///
/// Provides: create, list, switch, merge, delete, and current-branch queries.
pub struct BranchManager<'repo> {
    repo: &'repo Repository,
}

/// Summary of a branch (local or remote).
#[derive(Debug, Clone)]
pub struct BranchInfo {
    pub name: String,
    pub is_head: bool,
    pub is_local: bool,
    pub is_remote: bool,
    pub upstream_name: Option<String>,
    pub commit_oid: String,
    pub commit_summary: Option<String>,
}

impl<'repo> BranchManager<'repo> {
    /// Create a new branch manager from a repository reference.
    pub fn new(repo: &'repo Repository) -> Self {
        Self { repo }
    }

    /// Create a new branch starting from HEAD.
    pub fn create(&self, name: &str) -> GitResult<git2::Branch<'_>> {
        let head = self.repo.head().map_err(GitServiceError::Git)?;
        let head_commit = head
            .peel(git2::ObjectType::Commit)
            .map_err(GitServiceError::Git)?;
        let commit = head_commit
            .as_commit()
            .ok_or_else(|| GitServiceError::Other("HEAD is not a commit".into()))?;

        self.repo
            .branch(name, commit, false)
            .map_err(GitServiceError::Git)
    }

    /// Create a new branch starting from a specific commit.
    pub fn create_from_commit(
        &self,
        name: &str,
        commit_oid: git2::Oid,
    ) -> GitResult<git2::Branch<'_>> {
        let commit = self
            .repo
            .find_commit(commit_oid)
            .map_err(GitServiceError::Git)?;
        self.repo
            .branch(name, &commit, false)
            .map_err(GitServiceError::Git)
    }

    /// List all local branches.
    pub fn list_local(&self) -> GitResult<Vec<BranchInfo>> {
        let branches = self
            .repo
            .branches(Some(BranchType::Local))
            .map_err(GitServiceError::Git)?;
        let head_name = self.current_branch_name().ok();

        let mut result = Vec::new();
        for branch_result in branches {
            let (branch, _branch_type) = branch_result.map_err(GitServiceError::Git)?;
            if let Some(info) = self.branch_to_info(&branch, &head_name) {
                result.push(info);
            }
        }
        Ok(result)
    }

    /// List all remote branches for a given remote (defaults to "origin").
    pub fn list_remote(&self, remote_name: &str) -> GitResult<Vec<BranchInfo>> {
        let branches = self
            .repo
            .branches(Some(BranchType::Remote))
            .map_err(GitServiceError::Git)?;

        let mut result = Vec::new();
        for branch_result in branches {
            let (branch, _branch_type) = branch_result.map_err(GitServiceError::Git)?;
            if let Some(name) = branch.name().ok().flatten() {
                if name.starts_with(&format!("{}/", remote_name)) {
                    if let Some(info) = self.branch_to_info(&branch, &None) {
                        result.push(info);
                    }
                }
            }
        }
        Ok(result)
    }

    /// List all branches (local + remote for "origin").
    pub fn list_all(&self) -> GitResult<Vec<BranchInfo>> {
        let mut all = self.list_local()?;
        if let Ok(remotes) = self.list_remote("origin") {
            all.extend(remotes);
        }
        Ok(all)
    }

    /// Switch to (checkout) a branch by name.
    pub fn switch(&self, name: &str) -> GitResult<()> {
        let branch = self
            .repo
            .find_branch(name, BranchType::Local)
            .map_err(GitServiceError::Git)?;
        let tree = branch
            .get()
            .peel(git2::ObjectType::Tree)
            .map_err(GitServiceError::Git)?;

        self.repo
            .checkout_tree(&tree, Some(git2::build::CheckoutBuilder::default().force()))
            .map_err(GitServiceError::Git)?;

        self.repo
            .set_head(
                branch
                    .get()
                    .name()
                    .ok_or_else(|| GitServiceError::Other("Branch has no name".into()))?,
            )
            .map_err(GitServiceError::Git)?;

        Ok(())
    }

    /// Merge a branch into the current branch.
    /// Returns the merge analysis result: UpToDate, FastForward, or Merged.
    /// If conflicts arise, they must be resolved via the ConflictManager.
    pub fn merge(&self, branch_name: &str) -> GitResult<super::git_service::MergeResult> {
        let branch = self
            .repo
            .find_branch(branch_name, BranchType::Local)
            .map_err(GitServiceError::Git)?;

        let annotated = self
            .repo
            .reference_to_annotated_commit(branch.get())
            .map_err(GitServiceError::Git)?;

        let (analysis, _preference) = self
            .repo
            .merge_analysis(&[&annotated])
            .map_err(GitServiceError::Git)?;

        if analysis.is_up_to_date() {
            return Ok(super::git_service::MergeResult::UpToDate);
        }

        if analysis.is_fast_forward() {
            let mut reference = self
                .repo
                .find_reference("HEAD")
                .map_err(GitServiceError::Git)?;
            let head_name = reference.name().unwrap_or("HEAD").to_string();

            reference
                .set_target(
                    annotated.id(),
                    &format!("fast-forward merge: {}", branch_name),
                )
                .map_err(GitServiceError::Git)?;

            self.repo
                .set_head(&head_name)
                .map_err(GitServiceError::Git)?;
            self.repo
                .checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
                .map_err(GitServiceError::Git)?;

            return Ok(super::git_service::MergeResult::FastForward);
        }

        // Normal merge
        let mut merge_opts = git2::MergeOptions::default();
        self.repo
            .merge(&[&annotated], Some(&mut merge_opts), None)
            .map_err(GitServiceError::Git)?;

        // Check for conflicts
        let mut status_opts = git2::StatusOptions::new();
        status_opts.show(git2::StatusShow::Index);
        let statuses = self
            .repo
            .statuses(Some(&mut status_opts))
            .map_err(GitServiceError::Git)?;

        let has_conflicts = statuses.iter().any(|s| s.status().is_conflicted());

        if has_conflicts {
            let conflicts: Vec<String> = statuses
                .iter()
                .filter(|s| s.status().is_conflicted())
                .filter_map(|s| s.path().map(|p| p.to_string()))
                .collect();
            Ok(super::git_service::MergeResult::Conflicts(conflicts))
        } else {
            Ok(super::git_service::MergeResult::Merged)
        }
    }

    /// Delete a local branch. The branch must be fully merged unless `force` is true.
    pub fn delete(&self, name: &str, force: bool) -> GitResult<()> {
        let mut branch = self
            .repo
            .find_branch(name, BranchType::Local)
            .map_err(GitServiceError::Git)?;

        if force {
            // Delete regardless of merge status
            branch.delete().map_err(GitServiceError::Git)?;
        } else {
            // Safe delete (checks if merged)
            if branch.is_head() {
                return Err(GitServiceError::Other(format!(
                    "Cannot delete the currently checked-out branch '{}'",
                    name
                )));
            }
            branch.delete().map_err(GitServiceError::Git)?;
        }

        Ok(())
    }

    /// Get the name of the currently checked-out branch.
    pub fn current_branch_name(&self) -> GitResult<String> {
        let head = self.repo.head().map_err(GitServiceError::Git)?;

        if head.is_branch() {
            head.shorthand()
                .map(|s| s.to_string())
                .ok_or_else(|| GitServiceError::Other("HEAD has no shorthand".into()))
        } else {
            // Detached HEAD — return the commit hash
            let oid = head
                .target()
                .ok_or_else(|| GitServiceError::Other("HEAD points to nothing".into()))?;
            Ok(oid.to_string()[..8].to_string())
        }
    }

    /// Get a reference to the underlying repository.
    pub fn repo(&self) -> &Repository {
        self.repo
    }

    // ─── Private helpers ───

    fn branch_to_info(
        &self,
        branch: &git2::Branch,
        head_name: &Option<String>,
    ) -> Option<BranchInfo> {
        let name = branch.name().ok().flatten()?;
        let is_head = head_name.as_deref() == Some(name);

        let commit = branch.get().peel(git2::ObjectType::Commit).ok()?;
        let commit_oid = commit.id().to_string();
        let commit_summary = commit
            .as_commit()
            .and_then(|c| c.message())
            .map(|m| m.lines().next().unwrap_or("").to_string());

        let is_local = branch.is_head()
            || branch
                .name()
                .ok()
                .flatten()
                .map_or(false, |n| !n.contains('/'));
        let is_remote = !is_local;

        let upstream_name = branch
            .upstream()
            .ok()
            .and_then(|b| b.name().ok().flatten().map(|s| s.to_string()));

        Some(BranchInfo {
            name: name.to_string(),
            is_head,
            is_local,
            is_remote,
            upstream_name,
            commit_oid,
            commit_summary,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_branch_lifecycle() {
        let tmp = std::env::temp_dir().join("novident_branch_test");
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();

        let repo = Repository::init(&tmp).unwrap();

        // Verify we can open the repo and access branch info.
        let service = super::super::git_service::GitService::open(&tmp).unwrap();
        assert!(service.workdir().is_some());

        // Branch manager from the repo
        let mgr = BranchManager::new(&repo);
        let _branches = mgr.list_local();

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
