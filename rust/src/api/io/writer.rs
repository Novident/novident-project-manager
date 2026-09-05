//! Verbatim file writes. The engine writes exactly the bytes Dart hands over;
//! it never re-serializes a schema file it did not author.

use std::fs;
use std::io;
use std::path::Path;

/// Writes `contents` to `root/relative`, creating parent directories.
pub fn write_file(root: &Path, relative: &str, contents: &str) -> io::Result<()> {
    let path = root.join(relative);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, contents)
}

/// Deletes `root/relative`, ignoring a missing target (idempotent).
pub fn delete_file(root: &Path, relative: &str) -> io::Result<()> {
    match fs::remove_file(root.join(relative)) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}

/// Ensures `root/relative` exists as a directory.
pub fn ensure_dir(root: &Path, relative: &str) -> io::Result<()> {
    fs::create_dir_all(root.join(relative))
}

/// Recursively removes `root/relative`, ignoring a missing target (idempotent).
pub fn remove_dir(root: &Path, relative: &str) -> io::Result<()> {
    match fs::remove_dir_all(root.join(relative)) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}
