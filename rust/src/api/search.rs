//! Search engine: plain-text extraction (from raw JSON) + quick/structural search.
//!
//! The engine is schema-agnostic for the project (Dart owns that); it only
//! understands the stable *content* layout under `files/<node>/` well enough to
//! extract plain text for indexing and structural search. Offsets are measured
//! in Unicode scalar values (`char`), consistent with the Delta engine.

use std::collections::{HashMap, VecDeque};
use std::path::Path;
use std::time::Instant;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::api::util::now_iso8601;

// ---------------------------------------------------------------------------
// Search wire types (moved from the old `events/search.rs`)
// ---------------------------------------------------------------------------

/// Options controlling how a search query is matched.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchOptions {
    /// Match case exactly (default: case-insensitive).
    #[serde(default)]
    pub case_sensitive: bool,
    /// Treat `query` as a regular expression (default: literal substring).
    #[serde(default)]
    pub regexp: bool,
    /// Match whole words only (default: substring).
    #[serde(default)]
    pub whole_word: bool,
    /// Limit to an explicit set of node ids (Dart resolves folders into ids).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scope_ids: Option<Vec<String>>,
    /// Cap on total matches returned (default: no cap).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_results: Option<usize>,
}

/// Search mode: which source is searched and how results are shaped.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum SearchMode {
    /// Reads the in-memory plain-text index (may be intentionally stale).
    #[default]
    Quick,
    /// Resolves each match to a structural block (path + block type).
    Full,
}

/// A quick-search match (document-level, offset in one plain-text field).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickMatch {
    pub node_id: String,
    /// Which field matched: `title`, `text`, `synopsis`, `notes`, `comments`.
    pub field: String,
    pub offset: usize,
    pub length: usize,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub preview: Option<String>,
}

/// A full-search match, resolved to the block that contains it.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructuralMatch {
    pub node_id: String,
    /// Structural path of the block (list of child indices from the `page` root).
    pub path: Vec<usize>,
    /// Block type (`paragraph`, `heading`, `bulleted_list`, …).
    pub block_type: String,
    /// Offset within the block's plain text.
    pub offset: usize,
    pub length: usize,
    pub preview: String,
}

/// Status of the in-memory search index.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchIndexStatus {
    pub dirty_count: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_reindex_at: Option<String>,
    /// `true` when the index has pending (dirty) nodes, i.e. may be stale.
    pub stale: bool,
}

// ---------------------------------------------------------------------------
// Persisted index (`indexation/search.index.json`) — moved from the old
// `state/indexation.rs`.
// ---------------------------------------------------------------------------

/// Flat full-text index. Top-level object mixes `schema_version` and node-id
/// keys; `#[serde(flatten)]` captures the documents.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchIndex {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub schema_version: Option<i64>,
    #[serde(flatten)]
    pub documents: HashMap<String, SearchDocument>,
}

/// Extracted plain text for a single node.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SearchDocument {
    #[serde(default)]
    pub title: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub synopsis: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub comments: Option<String>,
}

// ---------------------------------------------------------------------------
// Resident index state
// ---------------------------------------------------------------------------

/// Resident, mutable search index (not serialized; persisted to
/// `indexation/search.index.json` on reindex).
pub struct SearchIndexState {
    /// Node id → extracted plain text.
    pub documents: HashMap<String, SearchDocument>,
    /// Nodes whose text changed and are awaiting reindex (deduplicated).
    pub dirty: VecDeque<String>,
    /// ISO-8601 timestamp of the last full reindex, if any.
    pub last_reindex_at: Option<String>,
    /// Monotonic clock of the last write event (drives future auto-reindex).
    pub last_write_at: Option<Instant>,
}

impl SearchIndexState {
    /// Builds the resident state from the persisted index (empty if none).
    pub fn from_index(index: &SearchIndex) -> Self {
        Self {
            documents: index.documents.clone(),
            dirty: VecDeque::new(),
            last_reindex_at: None,
            last_write_at: None,
        }
    }

    /// Marks a node as dirty (deduplicated). Does **not** reindex.
    pub fn mark_dirty(&mut self, node_id: &str) {
        if !self.dirty.iter().any(|d| d == node_id) {
            self.dirty.push_back(node_id.to_string());
        }
        self.last_write_at = Some(Instant::now());
    }

    /// Whether the index may be stale (has pending dirty nodes).
    pub fn is_stale(&self) -> bool {
        !self.dirty.is_empty()
    }

    /// Snapshot of the index status.
    pub fn status(&self) -> SearchIndexStatus {
        SearchIndexStatus {
            dirty_count: self.dirty.len() as u64,
            last_reindex_at: self.last_reindex_at.clone(),
            stale: self.is_stale(),
        }
    }

    /// Full reindex: rebuilds every document and clears the dirty queue.
    ///
    /// `nodes` is `(node_id, name)` for every node in the project (supplied by
    /// Dart, which owns the binder). Reads each node's files **directly**.
    pub fn reindex_full(&mut self, root: &Path, nodes: &[(String, String)]) {
        let mut documents = HashMap::new();
        for (id, name) in nodes {
            documents.insert(id.clone(), extract_search_document(root, id, name));
        }
        self.documents = documents;
        self.dirty.clear();
        self.last_reindex_at = Some(now_iso8601());
        self.last_write_at = None;
    }

    /// Persisted form of the current documents.
    pub fn to_index(&self) -> SearchIndex {
        SearchIndex {
            schema_version: Some(1),
            documents: self.documents.clone(),
        }
    }
}

// ---------------------------------------------------------------------------
// Plain-text extraction (raw JSON — no typed content structs)
// ---------------------------------------------------------------------------

/// Extracts a node's plain-text search document by reading its files directly.
pub fn extract_search_document(root: &Path, node_id: &str, name: &str) -> SearchDocument {
    let dir = root.join("files").join(node_id);

    let text = read_json(&dir.join("content.json"))
        .map(|v| tree_text(&v))
        .filter(|s| !s.is_empty());

    let synopsis = read_json(&dir.join("synopsis.json"))
        .and_then(|v| v.get("content").cloned())
        .map(|c| tree_text(&c))
        .filter(|s| !s.is_empty());

    let notes = read_text(&dir.join("notes.txt")).filter(|s| !s.is_empty());

    let comments = read_json(&dir.join("comments.json"))
        .map(|v| comments_text(&v))
        .filter(|s| !s.is_empty());

    SearchDocument {
        title: name.to_string(),
        text,
        synopsis,
        notes,
        comments,
    }
}

/// A node's **own** delta plain text (no child recursion).
fn block_text(node: &Value) -> String {
    let mut text = String::new();
    if let Some(delta) = node
        .get("attributes")
        .and_then(|a| a.get("delta"))
        .and_then(|d| d.as_array())
    {
        for op in delta {
            if let Some(insert) = op.get("insert").and_then(|v| v.as_str()) {
                text.push_str(insert);
            }
        }
    }
    text
}

/// Recursive plain text of a block subtree (delta + children).
fn tree_text(node: &Value) -> String {
    let mut text = block_text(node);
    if let Some(children) = node.get("children").and_then(|c| c.as_array()) {
        for child in children {
            text.push_str(&tree_text(child));
        }
    }
    text
}

/// Plain text of all comment bodies, joined by newlines.
fn comments_text(comments: &Value) -> String {
    comments
        .as_object()
        .map(|obj| {
            obj.values()
                .filter_map(|c| c.get("content").and_then(|v| v.as_str()))
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default()
}

// ---------------------------------------------------------------------------
// Quick search
// ---------------------------------------------------------------------------

/// Quick search over a set of `(node_id, SearchDocument)` entries.
pub fn search_quick<'a>(
    documents: impl Iterator<Item = (&'a String, &'a SearchDocument)>,
    query: &str,
    options: &SearchOptions,
) -> Result<Vec<QuickMatch>, String> {
    let mut out = Vec::new();
    for (node_id, doc) in documents {
        let fields: [(&str, &str); 5] = [
            ("title", doc.title.as_str()),
            ("text", doc.text.as_deref().unwrap_or("")),
            ("synopsis", doc.synopsis.as_deref().unwrap_or("")),
            ("notes", doc.notes.as_deref().unwrap_or("")),
            ("comments", doc.comments.as_deref().unwrap_or("")),
        ];
        for (field, text) in fields {
            if text.is_empty() {
                continue;
            }
            for (offset, length) in find_matches(text, query, options)? {
                out.push(QuickMatch {
                    node_id: node_id.clone(),
                    field: field.to_string(),
                    offset,
                    length,
                    preview: Some(preview(text, offset, length)),
                });
                if let Some(max) = options.max_results
                    && out.len() >= max
                {
                    return Ok(out);
                }
            }
        }
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// Structural search
// ---------------------------------------------------------------------------

/// Structural search over a single document's content tree (raw JSON).
pub fn search_structural(
    node_id: &str,
    content_json: &str,
    query: &str,
    options: &SearchOptions,
) -> Result<Vec<StructuralMatch>, String> {
    let content: Value = serde_json::from_str(content_json)
        .map_err(|e| format!("invalid content JSON: {e}"))?;
    let mut out = Vec::new();
    walk(node_id, &content, &mut Vec::new(), query, options, &mut out)?;
    Ok(out)
}

/// Walks every block; a match yields `(path, block_type, offset, length, preview)`
/// with the offset relative to the **block's** plain text.
fn walk(
    node_id: &str,
    node: &Value,
    path: &mut Vec<usize>,
    query: &str,
    options: &SearchOptions,
    out: &mut Vec<StructuralMatch>,
) -> Result<(), String> {
    let text = block_text(node);
    if !text.is_empty() {
        for (offset, length) in find_matches(&text, query, options)? {
            out.push(StructuralMatch {
                node_id: node_id.to_string(),
                path: path.clone(),
                block_type: node.get("type").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                offset,
                length,
                preview: preview(&text, offset, length),
            });
            if let Some(max) = options.max_results
                && out.len() >= max
            {
                return Ok(());
            }
        }
    }
    if let Some(children) = node.get("children").and_then(|c| c.as_array()) {
        for (i, child) in children.iter().enumerate() {
            path.push(i);
            walk(node_id, child, path, query, options, out)?;
            path.pop();
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Matching helpers
// ---------------------------------------------------------------------------

/// Finds all matches of `query` in `haystack`, returning `(char_offset, char_length)`.
fn find_matches(
    haystack: &str,
    query: &str,
    options: &SearchOptions,
) -> Result<Vec<(usize, usize)>, String> {
    if query.is_empty() {
        return Ok(Vec::new());
    }
    let pattern = build_pattern(query, options);
    let re = regex::RegexBuilder::new(&pattern)
        .case_insensitive(!options.case_sensitive)
        .build()
        .map_err(|e| format!("invalid search pattern: {e}"))?;

    let mut matches = Vec::new();
    for m in re.find_iter(haystack) {
        let offset = haystack[..m.start()].chars().count();
        let length = m.as_str().chars().count();
        matches.push((offset, length));
    }
    Ok(matches)
}

/// Builds the regex source: literal (escaped) or raw regexp, optionally
/// wrapped in Unicode word boundaries.
fn build_pattern(query: &str, options: &SearchOptions) -> String {
    let core = if options.regexp {
        query.to_string()
    } else {
        regex::escape(query)
    };
    if options.whole_word {
        format!(r"\b(?:{core})\b")
    } else {
        core
    }
}

/// A short excerpt around a match (char offsets), with ellipses.
fn preview(haystack: &str, offset: usize, length: usize) -> String {
    let chars: Vec<char> = haystack.chars().collect();
    let start = offset.saturating_sub(24);
    let end = (offset + length + 24).min(chars.len());
    let mut s = String::new();
    if start > 0 {
        s.push('…');
    }
    s.extend(&chars[start..end]);
    if end < chars.len() {
        s.push('…');
    }
    s
}

fn read_json(path: &Path) -> Option<Value> {
    serde_json::from_slice(&std::fs::read(path).ok()?).ok()
}

fn read_text(path: &Path) -> Option<String> {
    std::fs::read_to_string(path).ok()
}
