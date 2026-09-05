use git2::{
    Cred, CredentialType, FetchOptions, IndexAddOption, MergeOptions, PushOptions, RemoteCallbacks,
    Repository, Signature, StatusOptions, StatusShow,
};
use serde::{Deserialize, Serialize};
use std::path::Path;

use super::credentials::{AuthMethod, GitCredentials};

/// Result type alias for git operations.
pub type GitResult<T> = Result<T, GitServiceError>;

/// High-level Git operations wrapping `git2`.
///
/// Provides: init, open, clone, fetch, push, pull (fetch+merge),
/// add-all, commit, status, remote management.
pub struct GitService {
    repo: Repository,
}

impl GitService {
    /// Initialize a new Git repository at the given path.
    pub fn init(path: impl AsRef<Path>) -> GitResult<Self> {
        let repo = Repository::init(path.as_ref()).map_err(GitServiceError::Git)?;
        Ok(Self { repo })
    }

    /// Open an existing Git repository.
    pub fn open(path: impl AsRef<Path>) -> GitResult<Self> {
        let repo = Repository::open(path.as_ref()).map_err(GitServiceError::Git)?;
        Ok(Self { repo })
    }

    /// Discover a repository from any directory within it, walking up to find `.git`.
    pub fn discover(path: impl AsRef<Path>) -> GitResult<Self> {
        let repo = Repository::discover(path.as_ref()).map_err(GitServiceError::Git)?;
        Ok(Self { repo })
    }

    /// Clone a remote repository.
    pub fn clone(
        url: &str,
        into_path: impl AsRef<Path>,
        credentials: &GitCredentials,
    ) -> GitResult<Self> {
        let mut builder = git2::build::RepoBuilder::new();

        let mut fetch_opts = FetchOptions::new();
        let mut callbacks = RemoteCallbacks::new();
        let url_owned = url.to_string();
        let creds = credentials.clone();

        callbacks.credentials(move |_url, username_from_url, allowed_types| {
            Self::create_credentials(&url_owned, username_from_url, allowed_types, &creds)
        });

        callbacks.transfer_progress(|stats| {
            if stats.received_objects() == stats.total_objects() {
                eprintln!(
                    "[git] Clone: resolving deltas {}/{}",
                    stats.indexed_deltas(),
                    stats.total_deltas()
                );
            }
            true
        });

        fetch_opts.remote_callbacks(callbacks);
        builder.fetch_options(fetch_opts);

        let repo = builder
            .clone(url, into_path.as_ref())
            .map_err(GitServiceError::Git)?;

        Ok(Self { repo })
    }

    /// Fetch from a remote. Defaults to "origin".
    pub fn fetch(&self, remote_name: &str, credentials: &GitCredentials) -> GitResult<()> {
        let mut remote = self
            .repo
            .find_remote(remote_name)
            .map_err(GitServiceError::Git)?;

        let mut fetch_opts = FetchOptions::new();
        let mut callbacks = RemoteCallbacks::new();
        let url = remote.url().unwrap_or("").to_string();
        let creds = credentials.clone();

        callbacks.credentials(move |_url, username_from_url, allowed_types| {
            Self::create_credentials(&url, username_from_url, allowed_types, &creds)
        });

        fetch_opts.remote_callbacks(callbacks);
        remote
            .fetch(&[] as &[&str], Some(&mut fetch_opts), None)
            .map_err(GitServiceError::Git)?;

        Ok(())
    }

    /// Push the given branch to a remote. Defaults to "origin".
    pub fn push(
        &self,
        remote_name: &str,
        branch: &str,
        credentials: &GitCredentials,
        force: bool,
    ) -> GitResult<()> {
        let mut remote = self
            .repo
            .find_remote(remote_name)
            .map_err(GitServiceError::Git)?;

        let mut push_opts = PushOptions::new();
        let mut callbacks = RemoteCallbacks::new();
        let url = remote.url().unwrap_or("").to_string();
        let creds = credentials.clone();

        callbacks.credentials(move |_url, username_from_url, allowed_types| {
            Self::create_credentials(&url, username_from_url, allowed_types, &creds)
        });

        push_opts.remote_callbacks(callbacks);

        let refspec = if force {
            format!("+refs/heads/{}:refs/heads/{}", branch, branch)
        } else {
            format!("refs/heads/{}:refs/heads/{}", branch, branch)
        };

        remote
            .push(&[&refspec], Some(&mut push_opts))
            .map_err(GitServiceError::Git)?;

        Ok(())
    }

    /// Pull from a remote: performs a fetch followed by a merge of the tracking branch.
    pub fn pull(
        &self,
        remote_name: &str,
        branch: &str,
        credentials: &GitCredentials,
    ) -> GitResult<MergeResult> {
        // 1. Fetch
        self.fetch(remote_name, credentials)?;

        // 2. Find the remote tracking branch reference
        let _fetch_head = self.repo.find_reference("FETCH_HEAD").ok();
        let remote_branch_ref = format!("refs/remotes/{}/{}", remote_name, branch);

        let annotated = self
            .repo
            .find_reference(&remote_branch_ref)
            .or_else(|_| self.repo.find_reference(&format!("refs/heads/{}", branch)))
            .and_then(|r| self.repo.reference_to_annotated_commit(&r))
            .map_err(|e| {
                GitServiceError::Git(git2::Error::new(
                    git2::ErrorCode::NotFound,
                    git2::ErrorClass::Reference,
                    format!("Remote branch {}/{} not found: {}", remote_name, branch, e),
                ))
            })?;

        // 3. Merge
        let (analysis, _preference) = self
            .repo
            .merge_analysis(&[&annotated])
            .map_err(GitServiceError::Git)?;

        if analysis.is_up_to_date() {
            return Ok(MergeResult::UpToDate);
        }

        if analysis.is_fast_forward() {
            let mut reference = self
                .repo
                .find_reference("HEAD")
                .map_err(GitServiceError::Git)?;
            let name = reference.name().unwrap_or("HEAD").to_string();

            reference
                .set_target(
                    annotated.id(),
                    &format!("fast-forward pull: {}/{}", remote_name, branch),
                )
                .map_err(GitServiceError::Git)?;

            self.repo.set_head(&name).map_err(GitServiceError::Git)?;

            self.repo
                .checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
                .map_err(GitServiceError::Git)?;

            return Ok(MergeResult::FastForward);
        }

        // Normal merge
        let mut merge_opts = MergeOptions::default();
        self.repo
            .merge(&[&annotated], Some(&mut merge_opts), None)
            .map_err(GitServiceError::Git)?;

        // Check for conflicts
        let mut status_opts = StatusOptions::new();
        status_opts.show(StatusShow::Index);
        let statuses = self
            .repo
            .statuses(Some(&mut status_opts))
            .map_err(GitServiceError::Git)?;

        let has_conflicts = statuses.iter().any(|s| s.status().is_conflicted());

        if has_conflicts {
            Ok(MergeResult::Conflicts(self.collect_conflicts(&statuses)))
        } else {
            Ok(MergeResult::Merged)
        }
    }

    /// Stage all changes (equivalent to `git add -A`).
    pub fn add_all(&self) -> GitResult<()> {
        let mut index = self.repo.index().map_err(GitServiceError::Git)?;
        index
            .add_all(["*"].iter(), IndexAddOption::DEFAULT, None)
            .map_err(GitServiceError::Git)?;
        index.write().map_err(GitServiceError::Git)?;
        Ok(())
    }

    /// Commit staged changes.
    pub fn commit(&self, message: &str, author: &GitCredentials) -> GitResult<git2::Oid> {
        let signature =
            Signature::now(&author.name, &author.email).map_err(GitServiceError::Git)?;

        let mut index = self.repo.index().map_err(GitServiceError::Git)?;
        let tree_id = index.write_tree().map_err(GitServiceError::Git)?;
        let tree = self.repo.find_tree(tree_id).map_err(GitServiceError::Git)?;

        let parents = match self.repo.head() {
            Ok(head) => {
                let head_obj = head
                    .peel(git2::ObjectType::Commit)
                    .map_err(GitServiceError::Git)?;
                vec![head_obj]
            }
            Err(_) => vec![], // Initial commit — no parents
        };

        let parent_refs: Vec<&git2::Commit> =
            parents.iter().filter_map(|o| o.as_commit()).collect();

        self.repo
            .commit(
                Some("HEAD"),
                &signature,
                &signature,
                message,
                &tree,
                &parent_refs,
            )
            .map_err(GitServiceError::Git)
    }

    /// Get the working directory status.
    pub fn status(&self) -> GitResult<Vec<StatusEntry>> {
        let mut status_opts = StatusOptions::new();
        status_opts
            .include_untracked(true)
            .renames_head_to_index(true)
            .renames_index_to_workdir(true);

        let statuses = self
            .repo
            .statuses(Some(&mut status_opts))
            .map_err(GitServiceError::Git)?;

        let entries: Vec<StatusEntry> = statuses
            .iter()
            .map(|s| StatusEntry {
                path: s.path().unwrap_or("").to_string(),
                status: format!("{:?}", s.status()),
                is_new: s.status().is_index_new() || s.status().is_wt_new(),
                is_modified: s.status().is_index_modified() || s.status().is_wt_modified(),
                is_deleted: s.status().is_index_deleted() || s.status().is_wt_deleted(),
                is_conflicted: s.status().is_conflicted(),
            })
            .collect();

        Ok(entries)
    }

    /// Get the remote URL for a named remote.
    pub fn remote_url(&self, remote_name: &str) -> Option<String> {
        self.repo
            .find_remote(remote_name)
            .ok()
            .and_then(|r| r.url().map(|s| s.to_string()))
    }

    /// Set or add a remote URL.
    pub fn set_remote(&self, remote_name: &str, url: &str) -> GitResult<()> {
        if self.repo.find_remote(remote_name).is_ok() {
            self.repo
                .remote_set_url(remote_name, url)
                .map_err(GitServiceError::Git)?;
        } else {
            self.repo
                .remote(remote_name, url)
                .map_err(GitServiceError::Git)?;
        }
        Ok(())
    }

    /// Get a reference to the underlying `git2::Repository`.
    pub fn inner(&self) -> &Repository {
        &self.repo
    }

    /// Walk the current branch's history, newest first.
    pub fn log(&self, max_count: usize) -> GitResult<Vec<CommitLogEntry>> {
        let head = self.repo.head().map_err(GitServiceError::Git)?;
        let head_oid = head
            .target()
            .ok_or_else(|| GitServiceError::Other("HEAD sin objetivo".into()))?;
        let mut revwalk = self.repo.revwalk().map_err(GitServiceError::Git)?;
        revwalk.push(head_oid).map_err(GitServiceError::Git)?;
        revwalk
            .set_sorting(git2::Sort::TIME)
            .map_err(GitServiceError::Git)?;

        let mut entries = Vec::new();
        for oid in revwalk.take(max_count) {
            let oid = oid.map_err(GitServiceError::Git)?;
            let commit = self.repo.find_commit(oid).map_err(GitServiceError::Git)?;
            entries.push(CommitLogEntry {
                oid: oid.to_string(),
                summary: commit.summary().unwrap_or("").to_string(),
                message: commit.message().unwrap_or("").to_string(),
                author: commit.author().to_string(),
                time: commit.time().seconds(),
            });
        }
        Ok(entries)
    }

    /// Checkout a branch, tag or commit (commit/tag → detached HEAD).
    pub fn checkout(&self, target: &str) -> GitResult<()> {
        let obj = self
            .repo
            .revparse_single(target)
            .map_err(GitServiceError::Git)?;
        self.repo
            .checkout_tree(&obj, Some(git2::build::CheckoutBuilder::default().force()))
            .map_err(GitServiceError::Git)?;

        if let Ok(branch) = self.repo.find_branch(target, git2::BranchType::Local) {
            let name = branch
                .get()
                .name()
                .ok_or_else(|| GitServiceError::Other("branch sin nombre".into()))?;
            self.repo.set_head(name).map_err(GitServiceError::Git)?;
        } else {
            self.repo
                .set_head_detached(obj.id())
                .map_err(GitServiceError::Git)?;
        }
        Ok(())
    }

    /// Get the workdir path of this repository.
    pub fn workdir(&self) -> Option<&Path> {
        self.repo.workdir()
    }

    /// Get the path to the `.git` directory.
    pub fn path(&self) -> &Path {
        self.repo.path()
    }

    // ─── Private helpers ───

    fn create_credentials(
        url: &str,
        _username: Option<&str>,
        allowed_types: CredentialType,
        creds: &GitCredentials,
    ) -> Result<Cred, git2::Error> {
        let method = creds.auth_method_for_url(url);

        if allowed_types.contains(CredentialType::SSH_KEY)
            && method == AuthMethod::Ssh
            && let Some(ref ssh_key_path) = creds.ssh_key_path
        {
            let public_key_default = format!("{}.pub", ssh_key_path);
            let public_key_path = creds
                .ssh_public_key
                .as_deref()
                .unwrap_or(&public_key_default);

            return Cred::ssh_key(
                "git",
                Some(Path::new(public_key_path)),
                Path::new(ssh_key_path),
                None,
            );
        }

        if allowed_types.contains(CredentialType::USER_PASS_PLAINTEXT)
            && method == AuthMethod::Https
            && let Some(ref token) = creds.https_token
        {
            return Cred::userpass_plaintext(&creds.email, token);
        }

        // Default: try SSH agent / default key
        if allowed_types.contains(CredentialType::SSH_KEY) {
            return Cred::ssh_key_from_agent("git");
        }

        Err(git2::Error::new(
            git2::ErrorCode::Auth,
            git2::ErrorClass::Ssh,
            "No valid authentication method available. Configure SSH key or HTTPS token.",
        ))
    }

    /// Collect conflict file paths from status entries.
    fn collect_conflicts(&self, statuses: &git2::Statuses) -> Vec<String> {
        statuses
            .iter()
            .filter(|s| s.status().is_conflicted())
            .filter_map(|s| s.path().map(|p| p.to_string()))
            .collect()
    }
}

/// Result of a merge/pull operation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MergeResult {
    /// Already up to date — nothing to do.
    UpToDate,
    /// Fast-forward merge (no merge commit needed).
    FastForward,
    /// Successfully merged without conflicts.
    Merged,
    /// Merge completed but has conflicts that need resolution.
    Conflicts(Vec<String>),
}

/// A commit in the history log (serializable).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommitLogEntry {
    pub oid: String,
    pub summary: String,
    pub message: String,
    pub author: String,
    pub time: i64,
}

/// Simplified status entry for a file in the working tree.
#[derive(Debug, Clone)]
pub struct StatusEntry {
    pub path: String,
    pub status: String,
    pub is_new: bool,
    pub is_modified: bool,
    pub is_deleted: bool,
    pub is_conflicted: bool,
}

/// Error type for Git operations.
#[derive(Debug)]
pub enum GitServiceError {
    Git(git2::Error),
    Io(std::io::Error),
    Other(String),
}

impl From<git2::Error> for GitServiceError {
    fn from(e: git2::Error) -> Self {
        GitServiceError::Git(e)
    }
}

impl From<std::io::Error> for GitServiceError {
    fn from(e: std::io::Error) -> Self {
        GitServiceError::Io(e)
    }
}

impl std::fmt::Display for GitServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Git(e) => write!(f, "Git error: {}", e),
            Self::Io(e) => write!(f, "I/O error: {}", e),
            Self::Other(msg) => write!(f, "{}", msg),
        }
    }
}

impl std::error::Error for GitServiceError {}
