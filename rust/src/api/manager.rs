//! The `ProjectManager` — the opaque engine facade Dart talks to.
//!
//! Schema-agnostic: it owns the project path and the resident search index, and
//! delegates to the `io`/`validate`/`search`/`snapshot`/`version` engines. Dart
//! owns the `.nov` schema and parses the JSON this facade returns.
//!
//! Two API layers:
//!   - **Semantic** methods (one per file role / collection item / node file) that
//!     hide the internal paths. These are the primary API.
//!   - **Raw** `read_file`/`write_file`/`delete_file`/`list_files` primitives for
//!     edge cases.

use std::path::{Path, PathBuf};
use std::sync::Mutex;

use flutter_rust_bridge::frb;
use serde_json::Value;

use crate::api::error::ProjectError;
use crate::api::io;
use crate::api::search::{
    SearchIndex, SearchIndexState, SearchMode, SearchOptions, search_quick, search_structural,
};
use crate::api::snapshot::SnapshotManager;
use crate::api::text::delta::Delta;
use crate::api::validate::{Contract, validate_project};
use crate::api::version::conflict::ConflictResolution;
use crate::api::version::credentials::GitCredentials;
use crate::api::version::git_service::MergeResult;
use crate::api::version::git_types::{
    ConflictResolutionDto, GitBranchInfo, GitCommitInfo, GitMergeResult, GitStatusEntry,
};
use crate::api::version::repo_manager::NovidentRepo;

/// The standard internal `.gitignore`.
const GITIGNORE: &str = r#"# Novident .gitignore — Internal Repository
# Exclude editor lock files, OS files, and temporary artifacts

# Editor lock files
*.lock
*.lck

# OS generated files
.DS_Store
Thumbs.db
desktop.ini

# Temporary files
*.tmp
*.swp
*.swo
*~
~$*

# Backup files
*.bak
*.backup

# Snapshots are tracked separately via the Novident snapshot system
snapshots/*.zip
"#;

/// Opens an existing `.nov` project and returns its manager.
#[frb(sync)]
pub fn open_project(path: String) -> Result<ProjectManager, ProjectError> {
    let root = PathBuf::from(path);
    let index = io::read_file(&root, "indexation/search.index.json")
        .and_then(|s| serde_json::from_str::<SearchIndex>(&s).ok())
        .unwrap_or_default();
    let search = SearchIndexState::from_index(&index);
    Ok(ProjectManager {
        path: root,
        search: Mutex::new(search),
        lock: Mutex::new(()),
    })
}

/// Creates the empty directory skeleton of a `.nov` project (no file content —
/// Dart writes that).
#[frb(sync)]
pub fn create_project_skeleton(path: String) -> Result<(), ProjectError> {
    let root = PathBuf::from(path);
    let contract = Contract::load(1)
        .ok_or_else(|| ProjectError::internal("no bundled contract for schema version 1"))?;
    for dir in &contract.required_dirs {
        io::ensure_dir(&root, dir).map_err(ProjectError::io)?;
    }
    Ok(())
}

/// Writes the standard internal `.gitignore`.
#[frb(sync)]
pub fn write_gitignore(path: String) -> Result<(), ProjectError> {
    let root = PathBuf::from(path);
    io::write_file(&root, ".gitignore", GITIGNORE).map_err(ProjectError::io)
}

/// The opaque engine facade.
#[frb(opaque)]
pub struct ProjectManager {
    path: PathBuf,
    search: Mutex<SearchIndexState>,
    lock: Mutex<()>,
}

#[frb(opaque)]
impl ProjectManager {
    /// Project root path.
    pub fn path(&self) -> String {
        self.path.to_string_lossy().to_string()
    }

    /// No-op (kept for symmetry; Dart drops the handle to release resources).
    pub fn close(&self) {}

    // -- raw verbatim I/O (primitives) -----------------------------------------

    pub fn read_file(&self, relative_path: String) -> Option<String> {
        io::read_file(&self.path, &relative_path)
    }

    pub fn write_file(&self, relative_path: String, contents: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, &relative_path, &contents).map_err(ProjectError::io)
    }

    pub fn delete_file(&self, relative_path: String) -> Result<(), ProjectError> {
        io::delete_file(&self.path, &relative_path).map_err(ProjectError::io)
    }

    pub fn list_files(&self, dir: String) -> Vec<String> {
        io::list_files(&self.path, &dir)
    }

    // -- schema files (semantic; one method per role) --------------------------

    pub fn read_metadata(&self) -> Option<String> {
        io::read_file(&self.path, "files/metadata.json")
    }

    pub fn write_metadata(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "files/metadata.json", &json).map_err(ProjectError::io)
    }

    pub fn read_backup(&self) -> Option<String> {
        io::read_file(&self.path, "files/backup.json")
    }

    pub fn write_backup(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "files/backup.json", &json).map_err(ProjectError::io)
    }

    pub fn read_binder(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/binder.index.json")
    }

    pub fn write_binder(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "indexation/binder.index.json", &json).map_err(ProjectError::io)
    }

    pub fn read_sections(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/sections.index.json")
    }

    pub fn write_sections(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "indexation/sections.index.json", &json)
            .map_err(ProjectError::io)
    }

    pub fn read_icon(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/icon.index.json")
    }

    pub fn write_icon(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "indexation/icon.index.json", &json).map_err(ProjectError::io)
    }

    pub fn read_corkboard(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/corkboard.index.json")
    }

    pub fn write_corkboard(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "indexation/corkboard.index.json", &json)
            .map_err(ProjectError::io)
    }

    pub fn read_target(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/target.index.json")
    }

    pub fn write_target(&self, json: String) -> Result<(), ProjectError> {
        io::write_file(&self.path, "indexation/target.index.json", &json).map_err(ProjectError::io)
    }

    /// The persisted search index (read-only; rebuilt via `reindex_search`).
    pub fn read_search(&self) -> Option<String> {
        io::read_file(&self.path, "indexation/search.index.json")
    }

    // -- collections (semantic; one file per item, keyed by id) ----------------

    pub fn list_layouts(&self) -> Vec<String> {
        list_json_ids(&self.path, "layouts")
    }

    pub fn read_layout(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(&self.path, &format!("layouts/{id}.json")))
    }

    pub fn write_layout(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("layouts/{id}.json"), &json).map_err(ProjectError::io)
    }

    pub fn delete_layout(&self, id: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::delete_file(&self.path, &format!("layouts/{id}.json")).map_err(ProjectError::io)
    }

    pub fn list_formats(&self) -> Vec<String> {
        list_json_ids(&self.path, "compiler/formats")
    }

    pub fn read_format(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(
            &self.path,
            &format!("compiler/formats/{id}.json"),
        ))
    }

    pub fn write_format(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("compiler/formats/{id}.json"), &json)
            .map_err(ProjectError::io)
    }

    pub fn delete_format(&self, id: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::delete_file(&self.path, &format!("compiler/formats/{id}.json"))
            .map_err(ProjectError::io)
    }

    pub fn list_exports(&self) -> Vec<String> {
        list_json_ids(&self.path, "compiler/exports")
    }

    pub fn read_export(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(
            &self.path,
            &format!("compiler/exports/{id}.json"),
        ))
    }

    pub fn write_export(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("compiler/exports/{id}.json"), &json)
            .map_err(ProjectError::io)
    }

    pub fn delete_export(&self, id: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::delete_file(&self.path, &format!("compiler/exports/{id}.json"))
            .map_err(ProjectError::io)
    }

    /// Lists writing sessions (history) by date file stem.
    pub fn list_sessions(&self) -> Vec<String> {
        list_json_ids(&self.path, "history")
    }

    pub fn read_session(&self, date: String) -> Result<Option<String>, ProjectError> {
        let date = safe_component(date)?;
        Ok(io::read_file(&self.path, &format!("history/{date}.json")))
    }

    pub fn write_session(&self, date: String, json: String) -> Result<(), ProjectError> {
        let date = safe_component(date)?;
        io::write_file(&self.path, &format!("history/{date}.json"), &json).map_err(ProjectError::io)
    }

    pub fn delete_session(&self, date: String) -> Result<(), ProjectError> {
        let date = safe_component(date)?;
        io::delete_file(&self.path, &format!("history/{date}.json")).map_err(ProjectError::io)
    }

    // -- node-scoped files (semantic; keyed by node id) ------------------------

    pub fn read_node_content(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(
            &self.path,
            &format!("files/{id}/content.json"),
        ))
    }

    pub fn write_node_content(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("files/{id}/content.json"), &json)
            .map_err(ProjectError::io)
    }

    pub fn read_node_comments(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(
            &self.path,
            &format!("files/{id}/comments.json"),
        ))
    }

    pub fn write_node_comments(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("files/{id}/comments.json"), &json)
            .map_err(ProjectError::io)
    }

    pub fn read_node_notes(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(&self.path, &format!("files/{id}/notes.txt")))
    }

    pub fn write_node_notes(&self, id: String, text: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("files/{id}/notes.txt"), &text)
            .map_err(ProjectError::io)
    }

    pub fn read_node_synopsis(&self, id: String) -> Result<Option<String>, ProjectError> {
        let id = safe_component(id)?;
        Ok(io::read_file(
            &self.path,
            &format!("files/{id}/synopsis.json"),
        ))
    }

    pub fn write_node_synopsis(&self, id: String, json: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::write_file(&self.path, &format!("files/{id}/synopsis.json"), &json)
            .map_err(ProjectError::io)
    }

    /// Removes the physical `files/<id>/` directory. The binder is updated by
    /// Dart (via `write_binder`) after this call.
    pub fn delete_node_files(&self, id: String) -> Result<(), ProjectError> {
        let id = safe_component(id)?;
        io::remove_dir(&self.path, &format!("files/{id}")).map_err(ProjectError::io)
    }

    // -- structural validation ------------------------------------------------

    /// Runs structural validation and returns a JSON array of issues.
    pub fn validate(&self) -> String {
        let issues = validate_project(&self.path, 1);
        serde_json::to_string(&issues).unwrap_or_default()
    }

    // -- search ---------------------------------------------------------------

    /// Rebuilds the search index by reading the binder structurally and persisting
    /// `search.index.json`. Returns the index status (JSON).
    pub fn reindex_search(&self) -> Result<String, ProjectError> {
        let nodes = collect_binder_nodes(&self.path);

        let index = {
            let mut search = self.search.lock().unwrap_or_else(|p| p.into_inner());
            search.reindex_full(&self.path, &nodes);
            search.to_index()
        };

        let json = serde_json::to_string_pretty(&index).map_err(ProjectError::internal)?;
        io::write_file(&self.path, "indexation/search.index.json", &json)
            .map_err(ProjectError::io)?;

        let status = {
            let search = self.search.lock().unwrap_or_else(|p| p.into_inner());
            search.status()
        };
        Ok(serde_json::to_string(&status).unwrap_or_default())
    }

    /// Searches (`mode` = `"quick"` or `"full"`), returning a JSON array of matches.
    pub fn search(
        &self,
        query: String,
        options_json: String,
        mode: String,
    ) -> Result<String, ProjectError> {
        let options: SearchOptions = serde_json::from_str(&options_json)
            .map_err(|e| ProjectError::validation(format!("invalid search options: {e}")))?;
        let mode = match mode.as_str() {
            "quick" => SearchMode::Quick,
            "full" => SearchMode::Full,
            other => {
                return Err(ProjectError::validation(format!(
                    "unknown search mode: {other}"
                )));
            }
        };

        match mode {
            SearchMode::Quick => {
                let search = self.search.lock().unwrap_or_else(|p| p.into_inner());
                let scope = options.scope_ids.clone();
                let iter = search.documents.iter().filter(|(id, _)| {
                    scope
                        .as_ref()
                        .map_or(true, |s| s.iter().any(|sid| sid == id.as_str()))
                });
                let matches =
                    search_quick(iter, &query, &options).map_err(ProjectError::validation)?;
                Ok(serde_json::to_string(&matches).unwrap_or_default())
            }
            SearchMode::Full => {
                let node_ids: Vec<String> = {
                    let search = self.search.lock().unwrap_or_else(|p| p.into_inner());
                    let scope = options.scope_ids.clone();
                    search
                        .documents
                        .keys()
                        .filter(|id| {
                            scope
                                .as_ref()
                                .map_or(true, |s| s.iter().any(|sid| sid == id.as_str()))
                        })
                        .cloned()
                        .collect()
                };
                let mut results = Vec::new();
                for id in node_ids {
                    let content_path = self.path.join("files").join(&id).join("content.json");
                    let Some(content) = std::fs::read_to_string(&content_path).ok() else {
                        continue;
                    };
                    let mut matches = search_structural(&id, &content, &query, &options)
                        .map_err(ProjectError::validation)?;
                    results.append(&mut matches);
                    if let Some(max) = options.max_results
                        && results.len() >= max
                    {
                        results.truncate(max);
                        break;
                    }
                }
                Ok(serde_json::to_string(&results).unwrap_or_default())
            }
        }
    }

    /// Current search-index status (JSON).
    pub fn search_status(&self) -> String {
        let search = self.search.lock().unwrap_or_else(|p| p.into_inner());
        serde_json::to_string(&search.status()).unwrap_or_default()
    }

    // -- diff ----------------------------------------------------------------

    /// Diffs two Quill deltas (JSON op arrays) and returns the result delta (JSON).
    pub fn diff_delta(
        &self,
        before_json: String,
        after_json: String,
    ) -> Result<String, ProjectError> {
        let before: Value = serde_json::from_str(&before_json)
            .map_err(|e| ProjectError::validation(format!("invalid before delta: {e}")))?;
        let after: Value = serde_json::from_str(&after_json)
            .map_err(|e| ProjectError::validation(format!("invalid after delta: {e}")))?;
        let result = Delta::from_json(&before).diff(&Delta::from_json(&after));
        Ok(result.to_json().to_string())
    }

    // -- git -----------------------------------------------------------------

    pub fn git_status(&self) -> Result<String, ProjectError> {
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let entries = repo
            .status()
            .map_err(|e| ProjectError::git(format!("git status: {e}")))?;
        let dto: Vec<GitStatusEntry> = entries
            .into_iter()
            .map(|e| GitStatusEntry {
                path: e.path,
                status: e.status,
                is_new: e.is_new,
                is_modified: e.is_modified,
                is_deleted: e.is_deleted,
                is_conflicted: e.is_conflicted,
            })
            .collect();
        Ok(serde_json::to_string(&dto).unwrap_or_default())
    }

    pub fn git_log(&self, max_count: i32) -> Result<String, ProjectError> {
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let entries = repo
            .git_service()
            .log(max_count.max(0) as usize)
            .map_err(|e| ProjectError::git(format!("git log: {e}")))?;
        let dto: Vec<GitCommitInfo> = entries
            .into_iter()
            .map(|e| GitCommitInfo {
                oid: e.oid,
                summary: e.summary,
                message: e.message,
                author: e.author,
                time: e.time,
            })
            .collect();
        Ok(serde_json::to_string(&dto).unwrap_or_default())
    }

    pub fn git_branches(&self) -> Result<String, ProjectError> {
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let branches = repo
            .branches()
            .list_all()
            .map_err(|e| ProjectError::git(format!("git branches: {e}")))?;
        let dto: Vec<GitBranchInfo> = branches
            .into_iter()
            .map(|b| GitBranchInfo {
                name: b.name,
                is_head: b.is_head,
                is_local: b.is_local,
                is_remote: b.is_remote,
                upstream_name: b.upstream_name,
                commit_oid: b.commit_oid,
                commit_summary: b.commit_summary,
            })
            .collect();
        Ok(serde_json::to_string(&dto).unwrap_or_default())
    }

    /// Stages all changes and commits with the given author (`GitCredentials` JSON).
    pub fn git_commit(&self, message: String, author_json: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let author: GitCredentials = serde_json::from_str(&author_json)
            .map_err(|e| ProjectError::validation(format!("invalid author: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.git_service()
            .add_all()
            .map_err(|e| ProjectError::git(format!("git add: {e}")))?;
        let oid = repo
            .git_service()
            .commit(&message, &author)
            .map_err(|e| ProjectError::git(format!("git commit: {e}")))?;
        Ok(serde_json::json!({ "oid": oid.to_string() }).to_string())
    }

    /// Checks out a branch, tag, or commit.
    pub fn git_checkout(&self, target: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.git_service()
            .checkout(&target)
            .map_err(|e| ProjectError::git(format!("git checkout: {e}")))?;
        Ok("{}".to_string())
    }

    /// Pushes a branch to `origin`.
    pub fn git_push(
        &self,
        branch: String,
        credentials_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let creds: GitCredentials = serde_json::from_str(&credentials_json)
            .map_err(|e| ProjectError::validation(format!("invalid credentials: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.git_service()
            .push("origin", &branch, &creds, false)
            .map_err(|e| ProjectError::git(format!("git push: {e}")))?;
        Ok("{}".to_string())
    }

    /// Pulls a branch from `origin`, returning the merge result (JSON).
    pub fn git_pull(
        &self,
        branch: String,
        credentials_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let creds: GitCredentials = serde_json::from_str(&credentials_json)
            .map_err(|e| ProjectError::validation(format!("invalid credentials: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let merge = repo
            .git_service()
            .pull("origin", &branch, &creds)
            .map_err(|e| ProjectError::git(format!("git pull: {e}")))?;
        Ok(serde_json::to_string(&map_merge_result(merge)).unwrap_or_default())
    }

    /// Resolves a single conflicted file (`resolution_json` = `ConflictResolutionDto` JSON).
    pub fn git_resolve_conflict(
        &self,
        path: String,
        resolution_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let dto: ConflictResolutionDto = serde_json::from_str(&resolution_json)
            .map_err(|e| ProjectError::validation(format!("invalid resolution: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.conflicts()
            .resolve(&path, map_resolution(dto))
            .map_err(|e| ProjectError::git(format!("resolve conflict: {e}")))?;
        if !repo.conflicts().is_in_conflict() {
            repo.conflicts()
                .finish_resolution()
                .map_err(|e| ProjectError::git(format!("finish resolution: {e}")))?;
        }
        Ok("{}".to_string())
    }

    /// Aborts the current merge.
    pub fn git_abort_merge(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.conflicts()
            .abort_merge()
            .map_err(|e| ProjectError::git(format!("abort merge: {e}")))?;
        Ok("{}".to_string())
    }

    // -- git: branches --------------------------------------------------------

    /// Creates a branch from HEAD.
    pub fn git_branch_create(&self, name: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.branches()
            .create(&name)
            .map_err(|e| ProjectError::git(format!("git branch create: {e}")))?;
        Ok("{}".to_string())
    }

    /// Creates a branch from a specific commit oid.
    pub fn git_branch_create_from_commit(
        &self,
        name: String,
        commit_oid: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let oid = commit_oid
            .parse::<git2::Oid>()
            .map_err(|e| ProjectError::validation(format!("invalid oid: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.branches()
            .create_from_commit(&name, oid)
            .map_err(|e| ProjectError::git(format!("git branch create: {e}")))?;
        Ok("{}".to_string())
    }

    /// Switches to the branch named [name].
    pub fn git_branch_switch(&self, name: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.branches()
            .switch(&name)
            .map_err(|e| ProjectError::git(format!("git branch switch: {e}")))?;
        Ok("{}".to_string())
    }

    /// Merges the branch named [name] into the current branch (JSON `MergeResult`).
    pub fn git_branch_merge(&self, name: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let merge = repo
            .branches()
            .merge(&name)
            .map_err(|e| ProjectError::git(format!("git branch merge: {e}")))?;
        Ok(serde_json::to_string(&map_merge_result(merge)).unwrap_or_default())
    }

    /// Deletes the branch named [name]; [force] drops unmerged branches.
    pub fn git_branch_delete(&self, name: String, force: bool) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.branches()
            .delete(&name, force)
            .map_err(|e| ProjectError::git(format!("git branch delete: {e}")))?;
        Ok("{}".to_string())
    }

    /// Returns the current branch name (JSON `{ "name": … }`).
    pub fn git_current_branch(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let name = repo
            .branches()
            .current_branch_name()
            .map_err(|e| ProjectError::git(format!("git current branch: {e}")))?;
        Ok(serde_json::json!({ "name": name }).to_string())
    }

    /// Fetches from the remote (default `origin`) using [credentials_json].
    pub fn git_fetch(
        &self,
        remote_name: String,
        credentials_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let creds: GitCredentials = serde_json::from_str(&credentials_json)
            .map_err(|e| ProjectError::validation(format!("invalid credentials: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.git_service()
            .fetch(&remote_name, &creds)
            .map_err(|e| ProjectError::git(format!("git fetch: {e}")))?;
        Ok("{}".to_string())
    }

    /// Initializes the internal git repository of the project (no-op when it
    /// already exists).
    pub fn git_init(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        if self.path.join(".git").exists() {
            return Ok("{}".to_string());
        }
        NovidentRepo::init(&self.path)
            .map_err(|e| ProjectError::git(format!("git init: {e}")))?;
        Ok("{}".to_string())
    }

    // -- git: remotes ---------------------------------------------------------

    /// Sets (adds or replaces) the URL of the remote named [name].
    pub fn git_set_remote(&self, name: String, url: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.git_service()
            .set_remote(&name, &url)
            .map_err(|e| ProjectError::git(format!("git set remote: {e}")))?;
        Ok("{}".to_string())
    }

    /// Returns the URL of the remote named [name] (JSON `{ "url": … | null }`).
    pub fn git_remote_url(&self, name: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let url = repo.git_service().remote_url(&name);
        Ok(serde_json::json!({ "url": url }).to_string())
    }

    /// Lists the configured remotes with their URLs (JSON array).
    pub fn git_remotes(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let remotes = repo
            .git_service()
            .inner()
            .remotes()
            .map_err(|e| ProjectError::git(format!("git remotes: {e}")))?;
        let mut payload = Vec::new();
        for name in remotes.iter().flatten() {
            payload.push(serde_json::json!({
                "name": name,
                "url": repo.git_service().remote_url(name),
            }));
        }
        Ok(serde_json::to_string(&payload).unwrap_or_default())
    }

    // -- git: conflicts -------------------------------------------------------

    /// Detects every merge conflict (JSON array of conflict info).
    pub fn git_conflict_detect(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let conflicts = repo
            .conflicts()
            .detect_conflicts()
            .map_err(|e| ProjectError::git(format!("git conflicts: {e}")))?;
        let payload: Vec<serde_json::Value> = conflicts
            .iter()
            .map(|c| {
                serde_json::json!({
                    "path": c.path,
                    "ours_content": c.ours_content,
                    "theirs_content": c.theirs_content,
                    "ancestor_content": c.ancestor_content,
                    "ours_deleted": c.ours_deleted,
                    "theirs_deleted": c.theirs_deleted,
                })
            })
            .collect();
        Ok(serde_json::to_string(&payload).unwrap_or_default())
    }

    /// Resolves every conflicted file with the same resolution (`resolution_json`).
    pub fn git_conflict_resolve_all(
        &self,
        resolution_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let dto: ConflictResolutionDto = serde_json::from_str(&resolution_json)
            .map_err(|e| ProjectError::validation(format!("invalid resolution: {e}")))?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.conflicts()
            .resolve_all(map_resolution(dto))
            .map_err(|e| ProjectError::git(format!("git resolve all: {e}")))?;
        Ok("{}".to_string())
    }

    /// Finishes the conflict resolution (clears the conflict state).
    pub fn git_conflict_finish(&self) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        repo.conflicts()
            .finish_resolution()
            .map_err(|e| ProjectError::git(format!("git conflict finish: {e}")))?;
        Ok("{}".to_string())
    }

    // -- git: content / commit diff ------------------------------------------

    /// Diffs two JSON-serialized document trees (structural `TreeDiff` JSON),
    /// or `null` when the payloads cannot be read as documents.
    pub fn git_diff_json_documents(
        &self,
        old_json: String,
        new_json: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let parse = |json: &str| -> Result<serde_json::Map<String, Value>, ProjectError> {
            let value: Value = serde_json::from_str(json)
                .map_err(|e| ProjectError::validation(format!("invalid json: {e}")))?;
            value
                .as_object()
                .cloned()
                .ok_or_else(|| ProjectError::validation("expected a JSON object"))
        };
        let old = parse(&old_json)?;
        let new = parse(&new_json)?;
        let diff = crate::api::version::content_diff::diff_json_documents(&old, &new);
        match diff {
            Some(tree) => Ok(serde_json::to_string(&tree).unwrap_or_default()),
            None => Ok("null".to_string()),
        }
    }

    /// Diffs two document nodes by uuid (`TreeDiff` JSON or `null`).
    pub fn git_diff_documents(
        &self,
        old_uuid: String,
        new_uuid: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let diff = repo
            .diff_documents(&old_uuid, &new_uuid)
            .map_err(|e| ProjectError::git(format!("git diff documents: {e}")))?;
        Ok(match diff {
            Some(tree) => serde_json::to_string(&tree).unwrap_or_default(),
            None => "null".to_string(),
        })
    }

    /// Returns the diff introduced by the last commit of [branch] (or `null`).
    pub fn git_last_commit_diff(&self, branch: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let diff = repo
            .get_last_commit_diff(&branch)
            .map_err(|e| ProjectError::git(format!("git last commit diff: {e}")))?;
        Ok(map_commit_diff(diff))
    }

    /// Returns the diff between two commits (old oid, new oid) or `null`.
    pub fn git_diff_between_commits(
        &self,
        old_oid: String,
        new_oid: String,
    ) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let parse_oid = |oid: &str| -> Result<git2::Oid, ProjectError> {
            oid.parse::<git2::Oid>()
                .map_err(|e| ProjectError::validation(format!("invalid oid: {e}")))
        };
        let old = parse_oid(&old_oid)?;
        let new = parse_oid(&new_oid)?;
        let repo = NovidentRepo::open(&self.path)
            .map_err(|e| ProjectError::git(format!("git repository not available: {e}")))?;
        let diff = repo
            .get_diff_between_commits(old, new)
            .map_err(|e| ProjectError::git(format!("git diff between commits: {e}")))?;
        Ok(map_commit_diff(diff))
    }

    // -- snapshots ------------------------------------------------------------

    /// Creates a zip snapshot and returns its metadata (JSON).
    pub fn snapshot_create(&self, version: i32) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let manager = SnapshotManager::new(&self.path);
        let info = manager.create(version).map_err(ProjectError::io)?;
        Ok(serde_json::to_string(&info).unwrap_or_default())
    }

    /// Deletes a stored snapshot by id.
    pub fn snapshot_delete(&self, snapshot_id: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let manager = SnapshotManager::new(&self.path);
        manager.delete(&snapshot_id).map_err(ProjectError::io)?;
        Ok("{}".to_string())
    }

    /// Lists stored snapshots (JSON array, newest first).
    pub fn snapshot_list(&self) -> Result<String, ProjectError> {
        let manager = SnapshotManager::new(&self.path);
        let snapshots = manager.list().map_err(ProjectError::io)?;
        Ok(serde_json::to_string(&snapshots).unwrap_or_default())
    }

    /// Restores a snapshot over the project (overwrites files).
    pub fn snapshot_restore(&self, snapshot_id: String) -> Result<String, ProjectError> {
        let _guard = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        let manager = SnapshotManager::new(&self.path);
        manager.restore(&snapshot_id).map_err(ProjectError::io)?;
        Ok("{}".to_string())
    }
}

/// The set of JSON file stems (file names minus `.json`) in a directory, sorted.
fn list_json_ids(root: &Path, dir: &str) -> Vec<String> {
    io::list_files(root, dir)
        .into_iter()
        .filter(|f| f.ends_with(".json"))
        .map(|f| f.trim_end_matches(".json").to_string())
        .collect()
}

/// Rejects path components that could escape the project root (`..`, `/`, `\`).
fn safe_component(value: String) -> Result<String, ProjectError> {
    if value.is_empty() || value.contains('/') || value.contains('\\') || value.contains("..") {
        return Err(ProjectError::validation(format!(
            "unsafe path component: {value:?}"
        )));
    }
    Ok(value)
}

/// Collects `(id, name)` for every node in the binder tree (structural read).
fn collect_binder_nodes(root: &Path) -> Vec<(String, String)> {
    let Some(raw) = io::read_file(root, "indexation/binder.index.json") else {
        return Vec::new();
    };
    let Ok(binder) = serde_json::from_str::<Value>(&raw) else {
        return Vec::new();
    };
    let mut nodes = Vec::new();
    if let Some(tree) = binder.get("tree").and_then(|t| t.as_array()) {
        for node in tree {
            collect_node_recursive(node, &mut nodes);
        }
    }
    nodes
}

fn collect_node_recursive(node: &Value, out: &mut Vec<(String, String)>) {
    if let Some(id) = node.get("id").and_then(|v| v.as_str()) {
        let name = node.get("name").and_then(|v| v.as_str()).unwrap_or("");
        out.push((id.to_string(), name.to_string()));
    }
    if let Some(children) = node.get("children").and_then(|c| c.as_array()) {
        for child in children {
            collect_node_recursive(child, out);
        }
    }
}

/// Maps the engine's `MergeResult` to the serializable DTO.
fn map_merge_result(merge: MergeResult) -> GitMergeResult {
    match merge {
        MergeResult::UpToDate => GitMergeResult::UpToDate,
        MergeResult::FastForward => GitMergeResult::FastForward,
        MergeResult::Merged => GitMergeResult::Merged,
        MergeResult::Conflicts(paths) => GitMergeResult::Conflicts(paths),
    }
}

/// Maps the wire conflict-resolution DTO to the engine enum.
fn map_resolution(resolution: ConflictResolutionDto) -> ConflictResolution {
    match resolution {
        ConflictResolutionDto::AcceptOurs => ConflictResolution::AcceptOurs,
        ConflictResolutionDto::AcceptTheirs => ConflictResolution::AcceptTheirs,
        ConflictResolutionDto::Custom(content) => ConflictResolution::Custom(content),
    }
}

/// Serializes an optional `CommitDiff` to JSON (`null` when absent).
fn map_commit_diff(diff: Option<crate::api::version::repo_manager::CommitDiff>) -> String {
    let Some(diff) = diff else {
        return "null".to_string();
    };
    let file_diffs: Vec<serde_json::Value> = diff
        .file_diffs
        .iter()
        .map(|f| {
            let content = f
                .content_diff
                .as_ref()
                .and_then(|t| serde_json::to_value(t).ok());
            serde_json::json!({
                "path": f.path,
                "status": f.status,
                "content_diff": content,
            })
        })
        .collect();
    serde_json::json!({
        "commit_oid": diff.commit_oid,
        "commit_message": diff.commit_message,
        "commit_author": diff.commit_author,
        "commit_time": diff.commit_time,
        "file_diffs": file_diffs,
    })
    .to_string()
}
