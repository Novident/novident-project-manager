//! Verbatim file I/O.
//!
//! The engine reads and writes raw bytes/JSON and never interprets the `.nov`
//! schema (Dart owns that). Reading is best-effort (missing/unreadable → `None`);
//! writing is exact (bytes are written as-is, parents created on demand).

pub mod reader;
pub mod writer;

pub use reader::{list_dirs, list_files, read_file, read_text};
pub use writer::{delete_file, ensure_dir, remove_dir, write_file};
