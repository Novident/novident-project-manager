use std::fs::{self, File};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use zip::ZipArchive;
use zip::write::SimpleFileOptions;

use crate::api::util::now_file_stamp;

/// Metadata for a stored project snapshot (`snapshots/*.zip`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnapshotInfo {
    /// Filename stem (e.g. `2026-08-28_00-24-24-v1`).
    pub id: String,
    /// Full filename with extension (e.g. `2026-08-28_00-24-24-v1.zip`).
    pub filename: String,
    /// File modification time, in Unix epoch seconds.
    pub created_at: i64,
}

/// Project snapshots — zip the `.nov` project to `snapshots/` and restore it.
///
/// Snapshots are separate from git: a full copy of the project (excluding the
/// `.git` directory, `snapshots/` itself, and build artifacts), stored as a
/// single `.zip` under `snapshots/<stamp>-v<version>.zip`. Restore extracts a
/// snapshot over the project root (overwriting files).
pub struct SnapshotManager {
    root: PathBuf,
}

impl SnapshotManager {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// The `snapshots/` directory (created on demand).
    fn snapshots_dir(&self) -> PathBuf {
        self.root.join("snapshots")
    }

    /// Creates a snapshot of the project and returns its metadata.
    pub fn create(&self, version: i32) -> Result<SnapshotInfo, String> {
        let dir = self.snapshots_dir();
        fs::create_dir_all(&dir).map_err(|e| format!("create snapshots/: {e}"))?;

        let id = format!("{}-v{version}", now_file_stamp());
        let filename = format!("{id}.zip");
        let zip_path = dir.join(&filename);

        let file = File::create(&zip_path).map_err(|e| format!("create {filename}: {e}"))?;
        let mut zip = zip::ZipWriter::new(file);
        let options = SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Deflated)
            .unix_permissions(0o644);

        add_dir_to_zip(&mut zip, &self.root, &self.root, options)?;
        zip.finish().map_err(|e| format!("finish zip: {e}"))?;

        let created_at = fs::metadata(&zip_path)
            .and_then(|m| m.modified())
            .map(|t| {
                t.duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_secs() as i64)
                    .unwrap_or(0)
            })
            .unwrap_or(0);

        Ok(SnapshotInfo {
            id,
            filename,
            created_at,
        })
    }

    /// Lists all stored snapshots (newest first).
    pub fn list(&self) -> Result<Vec<SnapshotInfo>, String> {
        let dir = self.snapshots_dir();
        let mut snapshots = Vec::new();
        let entries = match fs::read_dir(&dir) {
            Ok(entries) => entries,
            Err(_) => return Ok(Vec::new()), // no snapshots yet
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("zip") {
                continue;
            }
            let filename = entry.file_name().to_string_lossy().to_string();
            let id = filename.trim_end_matches(".zip").to_string();
            let created_at = fs::metadata(&path)
                .and_then(|m| m.modified())
                .map(|t| {
                    t.duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_secs() as i64)
                        .unwrap_or(0)
                })
                .unwrap_or(0);
            snapshots.push(SnapshotInfo {
                id,
                filename,
                created_at,
            });
        }
        // Newest first.
        snapshots.sort_by_key(|b| std::cmp::Reverse(b.created_at));
        Ok(snapshots)
    }

    /// Deletes a stored snapshot by id.
    ///
    /// Only files that correspond to a listed snapshot are removed; an unknown
    /// id is an error.
    pub fn delete(&self, snapshot_id: &str) -> Result<(), String> {
        let zip_path = self.snapshots_dir().join(format!("{snapshot_id}.zip"));
        if !zip_path.is_file() {
            return Err(format!("snapshot not found: {snapshot_id}"));
        }
        fs::remove_file(&zip_path).map_err(|e| format!("delete {snapshot_id}.zip: {e}"))
    }

    /// Restores a snapshot over the project root (overwriting files).
    pub fn restore(&self, snapshot_id: &str) -> Result<(), String> {
        let zip_path = self.snapshots_dir().join(format!("{snapshot_id}.zip"));
        let file = File::open(&zip_path).map_err(|e| format!("open {snapshot_id}.zip: {e}"))?;
        let mut archive = ZipArchive::new(file).map_err(|e| format!("read zip: {e}"))?;

        for i in 0..archive.len() {
            let mut entry = archive.by_index(i).map_err(|e| format!("entry {i}: {e}"))?;
            let name = entry.name().to_string();
            // Zip-slip guard: reject any path that escapes the root.
            let out_path = self.root.join(&name);
            if !out_path.starts_with(&self.root) {
                return Err(format!("unsafe path in snapshot: {name}"));
            }
            if entry.is_dir() {
                fs::create_dir_all(&out_path).map_err(|e| format!("create dir {name}: {e}"))?;
            } else {
                if let Some(parent) = out_path.parent() {
                    fs::create_dir_all(parent).map_err(|e| format!("create parent {name}: {e}"))?;
                }
                let mut out = File::create(&out_path).map_err(|e| format!("create {name}: {e}"))?;
                std::io::copy(&mut entry, &mut out).map_err(|e| format!("write {name}: {e}"))?;
            }
        }
        Ok(())
    }
}

/// Recursively adds `dir` (relative to `base`) to `zip`, skipping excluded paths.
fn add_dir_to_zip<W: std::io::Write + std::io::Seek>(
    zip: &mut zip::ZipWriter<W>,
    base: &Path,
    dir: &Path,
    options: SimpleFileOptions,
) -> Result<(), String> {
    for entry in fs::read_dir(dir).map_err(|e| format!("read dir: {e}"))? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();

        if is_excluded(&name) {
            continue;
        }

        let rel = path
            .strip_prefix(base)
            .map_err(|e| format!("relative path: {e}"))?
            .to_string_lossy()
            .replace('\\', "/");

        if path.is_dir() {
            zip.add_directory(rel, options)
                .map_err(|e| format!("add dir: {e}"))?;
            add_dir_to_zip(zip, base, &path, options)?;
        } else {
            zip.start_file(rel, options)
                .map_err(|e| format!("add file: {e}"))?;
            let mut file = File::open(&path).map_err(|e| format!("open {name}: {e}"))?;
            std::io::copy(&mut file, zip).map_err(|e| format!("compress {name}: {e}"))?;
        }
    }
    Ok(())
}

/// Paths never included in a snapshot.
fn is_excluded(name: &str) -> bool {
    matches!(name, ".git" | "snapshots")
}
