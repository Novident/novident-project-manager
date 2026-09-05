//! Novident Version Control Module
//!
//! Git-powered versioning for `.nov` projects. Provides:
//!
//! - **Remote operations**: clone, push, pull, fetch with SSH/HTTPS auth
//! - **Branch management**: create, list, switch, merge, delete branches
//! - **Conflict handling**: detect, inspect, resolve (ours/theirs/custom), abort
//! - **Content-level diff**: semantic diff of document trees using the Delta engine
//! - **Secure credentials**: persistent, obfuscated credential storage
//! - **High-level API**: `NovidentRepo` for parse-diff-publish workflows
//!
//! # Quick Start
//!
//! ```ignore
//! use novident_project_manager::api::version::*;
//!
//! let creds = credentials::GitCredentials::new("Author", "author@novident.dev")
//!     .with_ssh_key("/home/user/.ssh/id_ed25519");
//!
//! // Clone a remote project
//! let repo = repo_manager::NovidentRepo::clone(
//!     "git@github.com:user/my-novel.git",
//!     "/home/user/novels/my-novel",
//!     &creds,
//! )?;
//!
//! // Parse the .nov project
//! let project = repo.parse_project()?;
//!
//! // Make edits...
//!
//! // See what changed
//! let status = repo.status()?;
//!
//! // Publish
//! repo.commit_and_push("Chapter 5 edits", "main", &creds)?;
//! ```

pub mod branch;
pub mod conflict;
pub mod content_diff;
pub mod credentials;
pub mod git_service;
pub mod git_types;
pub mod repo_manager;

// Re-export commonly used types
pub use branch::{BranchInfo, BranchManager};
pub use conflict::{ConflictInfo, ConflictManager, ConflictResolution};
pub use content_diff::{ContentChange, TreeDiff, diff_json_documents, diff_trees};
pub use credentials::{AuthMethod, CredentialStore, GitCredentials};
pub use git_service::{GitResult, GitService, GitServiceError, MergeResult, StatusEntry};
pub use repo_manager::{CommitDiff, FileDiff, NovidentProject, NovidentRepo, NovidentWorkflow};
