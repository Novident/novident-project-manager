//! Serializable git DTOs for the JSON boundary.
//!
//! These mirror the `version/` engine types (`StatusEntry`, `BranchInfo`,
//! `MergeResult`, `ConflictResolution`) in a serde-friendly form so git results
//! can cross the JSON boundary as strings.

use serde::{Deserialize, Serialize};

/// A single working-tree status entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitStatusEntry {
    pub path: String,
    pub status: String,
    pub is_new: bool,
    pub is_modified: bool,
    pub is_deleted: bool,
    pub is_conflicted: bool,
}

/// A commit in the history log.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitCommitInfo {
    pub oid: String,
    pub summary: String,
    pub message: String,
    pub author: String,
    pub time: i64,
}

/// A branch summary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitBranchInfo {
    pub name: String,
    pub is_head: bool,
    pub is_local: bool,
    pub is_remote: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub upstream_name: Option<String>,
    pub commit_oid: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub commit_summary: Option<String>,
}

/// Result of a merge/pull.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "conflicts", rename_all = "snake_case")]
pub enum GitMergeResult {
    UpToDate,
    FastForward,
    Merged,
    Conflicts(Vec<String>),
}

/// How to resolve a merge conflict.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ConflictResolutionDto {
    AcceptOurs,
    AcceptTheirs,
    Custom(String),
}
