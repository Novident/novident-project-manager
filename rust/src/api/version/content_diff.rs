use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::api::text::attributes::{Attributes, diff_attributes};
use crate::api::text::content_reader::{DocumentNode, Node};
use crate::api::text::delta::Delta;

/// Represents a single content-level change between two versions of a document tree.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "change_type")]
pub enum ContentChange {
    /// A new node was added in the new version.
    NodeAdded {
        /// Path to the parent node (list of child indices from root).
        path: Vec<usize>,
        /// Index at which the node was inserted.
        index: usize,
        /// The new node.
        node: SerializableNode,
    },
    /// A node was removed in the new version.
    NodeRemoved {
        /// Path to the removed node's former parent.
        path: Vec<usize>,
        /// Index at which the node was removed.
        index: usize,
        /// Summary of the removed node (type + first text).
        summary: String,
    },
    /// A node's type changed (e.g., paragraph → heading).
    NodeTypeChanged {
        path: Vec<usize>,
        old_type: String,
        new_type: String,
    },
    /// A node's attributes (non-content data) changed.
    AttributesChanged {
        path: Vec<usize>,
        /// The diff of attributes: keys present in new but different or absent in old.
        attribute_diff: Attributes,
    },
    /// The textual content (Delta) of a node changed.
    ContentChanged {
        path: Vec<usize>,
        /// The Delta that transforms old content into new content.
        /// Apply this delta to the old content to get the new content.
        delta_diff: Vec<TextOperationSerde>,
    },
    /// A node was moved from one position to another.
    NodeMoved {
        old_path: Vec<usize>,
        new_path: Vec<usize>,
    },
}

/// A collection of changes between two document trees.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TreeDiff {
    /// The list of all detected changes.
    pub changes: Vec<ContentChange>,
    /// Total number of nodes added.
    pub nodes_added: usize,
    /// Total number of nodes removed.
    pub nodes_removed: usize,
    /// Total number of nodes modified (type, attributes, or content).
    pub nodes_modified: usize,
    /// Total number of nodes moved.
    pub nodes_moved: usize,
    /// Summary for display.
    pub summary: String,
}

impl TreeDiff {
    pub fn new(changes: Vec<ContentChange>) -> Self {
        let nodes_added = changes
            .iter()
            .filter(|c| matches!(c, ContentChange::NodeAdded { .. }))
            .count();
        let nodes_removed = changes
            .iter()
            .filter(|c| matches!(c, ContentChange::NodeRemoved { .. }))
            .count();
        let nodes_modified = changes
            .iter()
            .filter(|c| {
                matches!(
                    c,
                    ContentChange::NodeTypeChanged { .. }
                        | ContentChange::AttributesChanged { .. }
                        | ContentChange::ContentChanged { .. }
                )
            })
            .count();
        let nodes_moved = changes
            .iter()
            .filter(|c| matches!(c, ContentChange::NodeMoved { .. }))
            .count();

        let summary = format!(
            "{} added, {} removed, {} modified, {} moved",
            nodes_added, nodes_removed, nodes_modified, nodes_moved
        );

        Self {
            changes,
            nodes_added,
            nodes_removed,
            nodes_modified,
            nodes_moved,
            summary,
        }
    }

    /// True if there are no changes.
    pub fn is_empty(&self) -> bool {
        self.changes.is_empty()
    }

    /// Filter changes to only those affecting a specific node path prefix.
    pub fn filter_by_prefix(&self, prefix: &[usize]) -> Vec<&ContentChange> {
        self.changes
            .iter()
            .filter(|c| c.path().is_some_and(|p| p.starts_with(prefix)))
            .collect()
    }
}

impl ContentChange {
    /// Returns the primary path associated with this change.
    pub fn path(&self) -> Option<&[usize]> {
        match self {
            ContentChange::NodeAdded { path, .. } => Some(path),
            ContentChange::NodeRemoved { path, .. } => Some(path),
            ContentChange::NodeTypeChanged { path, .. } => Some(path),
            ContentChange::AttributesChanged { path, .. } => Some(path),
            ContentChange::ContentChanged { path, .. } => Some(path),
            ContentChange::NodeMoved { .. } => None, // Ambiguous — has two paths
        }
    }
}

/// A lightweight, serializable representation of a Node for diff output.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SerializableNode {
    pub node_type: String,
    pub text_preview: String,
    pub child_count: usize,
}

/// Lightweight serde representation of a TextOperation for the diff output.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TextOperationSerde {
    Insert {
        insert: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        attributes: Option<Attributes>,
    },
    Retain {
        retain: usize,
        #[serde(skip_serializing_if = "Option::is_none")]
        attributes: Option<Attributes>,
    },
    Delete {
        delete: usize,
    },
}

/// Compute a full diff between two document trees.
///
/// Returns a `TreeDiff` containing all detected changes: nodes added, removed,
/// type changes, attribute changes, content (Delta) changes, and moves.
pub fn diff_trees(old: &DocumentNode, new: &DocumentNode) -> TreeDiff {
    let mut changes = Vec::new();
    diff_nodes(&old.root, &new.root, &mut vec![], &mut changes);

    // Detect moves by correlating added/removed nodes with matching content
    let moves = detect_moves(&changes);

    // Only remove the adds/removes that were matched as moves
    if !moves.is_empty() {
        let move_paths: std::collections::HashSet<_> = moves
            .iter()
            .flat_map(|m| match m {
                ContentChange::NodeMoved { old_path, new_path } => {
                    vec![
                        (old_path.clone(), "removed".to_string()),
                        (new_path.clone(), "added".to_string()),
                    ]
                }
                _ => vec![],
            })
            .collect();

        changes.retain(|c| {
            !matches!(c, ContentChange::NodeAdded { path, .. } if move_paths.contains(&(path.clone(), "added".to_string())))
                && !matches!(c, ContentChange::NodeRemoved { path, .. } if move_paths.contains(&(path.clone(), "removed".to_string())))
        });
    }

    changes.extend(moves);
    TreeDiff::new(changes)
}

/// Recursively diff two nodes and their children.
fn diff_nodes(
    old: &Node,
    new: &Node,
    current_path: &mut Vec<usize>,
    changes: &mut Vec<ContentChange>,
) {
    // 1. Check type change
    if old.node_type != new.node_type {
        changes.push(ContentChange::NodeTypeChanged {
            path: current_path.clone(),
            old_type: old.node_type.clone(),
            new_type: new.node_type.clone(),
        });
    }

    // 2. Check attribute changes (non-delta data)
    if let Some(attr_diff) = diff_node_attributes(old, new) {
        changes.push(ContentChange::AttributesChanged {
            path: current_path.clone(),
            attribute_diff: attr_diff,
        });
    }

    // 3. Check content (Delta) changes
    let old_delta = old.delta();
    let new_delta = new.delta();
    match (old_delta, new_delta) {
        (Some(old_d), Some(new_d)) => {
            let delta_diff = diff_document_content(&old_d, &new_d);
            if !delta_diff.is_empty() {
                changes.push(ContentChange::ContentChanged {
                    path: current_path.clone(),
                    delta_diff: delta_to_serde_ops(&delta_diff),
                });
            }
        }
        (None, Some(_new_d)) => {
            // Content added where there was none
            changes.push(ContentChange::ContentChanged {
                path: current_path.clone(),
                delta_diff: vec![TextOperationSerde::Insert {
                    insert: new.collect_plain_text(),
                    attributes: None,
                }],
            });
        }
        (Some(_old_d), None) => {
            // Content removed
            changes.push(ContentChange::ContentChanged {
                path: current_path.clone(),
                delta_diff: vec![TextOperationSerde::Delete {
                    delete: old.collect_plain_text().len(),
                }],
            });
        }
        (None, None) => {} // No content in either
    }

    // 4. Diff children
    let old_children: Vec<&Node> = old.children.as_ref().map_or(vec![], |c| c.iter().collect());
    let new_children: Vec<&Node> = new.children.as_ref().map_or(vec![], |c| c.iter().collect());

    let max_len = old_children.len().max(new_children.len());

    for i in 0..max_len {
        current_path.push(i);

        match (old_children.get(i), new_children.get(i)) {
            (Some(old_child), Some(new_child)) => {
                // Node exists in both — recurse
                diff_nodes(old_child, new_child, current_path, changes);
            }
            (None, Some(new_child)) => {
                // Node added
                changes.push(ContentChange::NodeAdded {
                    path: current_path.clone(),
                    index: i,
                    node: node_to_serializable(new_child),
                });
            }
            (Some(old_child), None) => {
                // Node removed
                changes.push(ContentChange::NodeRemoved {
                    path: current_path.clone(),
                    index: i,
                    summary: node_summary(old_child),
                });
            }
            (None, None) => unreachable!(),
        }

        current_path.pop();
    }
}

/// Compute a Delta-level diff between two content texts.
/// Uses the existing `Delta::diff` method.
pub fn diff_document_content(old: &Delta, new: &Delta) -> Delta {
    // Delta::diff computes operations that transform `old` into `new`
    old.diff(new)
}

/// Compare non-delta attributes between two nodes.
fn diff_node_attributes(old: &Node, new: &Node) -> Option<Attributes> {
    let old_data = old.data.clone().unwrap_or_default();
    let new_data = new.data.clone().unwrap_or_default();

    // Remove the "delta" key since it's compared separately via Delta::diff
    let mut old_filtered = old_data.clone();
    let mut new_filtered = new_data.clone();
    old_filtered.remove("delta");
    new_filtered.remove("delta");

    diff_attributes(
        if old_filtered.is_empty() {
            None
        } else {
            Some(old_filtered)
        },
        if new_filtered.is_empty() {
            None
        } else {
            Some(new_filtered)
        },
    )
}

/// Detect moved nodes by correlating NodeAdded/NodeRemoved pairs.
fn detect_moves(changes: &[ContentChange]) -> Vec<ContentChange> {
    let mut moves = Vec::new();
    let mut added_summaries: Vec<(Vec<usize>, usize, String)> = Vec::new();
    let mut removed_summaries: Vec<(Vec<usize>, usize, String)> = Vec::new();

    for change in changes {
        match change {
            ContentChange::NodeAdded { path, index, node } => {
                added_summaries.push((
                    path.clone(),
                    *index,
                    format!("{}:{}", node.node_type, node.text_preview),
                ));
            }
            ContentChange::NodeRemoved {
                path,
                index,
                summary,
            } => {
                removed_summaries.push((path.clone(), *index, summary.clone()));
            }
            _ => {}
        }
    }

    // Simple heuristic: if an added node's content matches a removed node's content,
    // treat it as a move. In production, use a more sophisticated matching algorithm.
    let mut used_removed: std::collections::HashSet<usize> = std::collections::HashSet::new();

    for (new_path, _, add_summary) in added_summaries.iter() {
        for (r_idx, (old_path, _, rem_summary)) in removed_summaries.iter().enumerate() {
            if !used_removed.contains(&r_idx) && add_summary == rem_summary {
                moves.push(ContentChange::NodeMoved {
                    old_path: old_path.clone(),
                    new_path: new_path.clone(),
                });
                used_removed.insert(r_idx);
                break;
            }
        }
    }

    moves
}

/// Convert a Node to a summary string for logging/diff display.
fn node_summary(node: &Node) -> String {
    let text_preview = node.collect_plain_text();
    let preview = if text_preview.len() > 80 {
        format!("{}...", &text_preview[..80])
    } else {
        text_preview
    };
    format!("[{}] {}", node.node_type, preview)
}

/// Convert a Node to its serializable representation.
fn node_to_serializable(node: &Node) -> SerializableNode {
    SerializableNode {
        node_type: node.node_type.clone(),
        text_preview: {
            let text = node.collect_plain_text();
            if text.len() > 120 {
                format!("{}...", &text[..120])
            } else {
                text
            }
        },
        child_count: node.children.as_ref().map_or(0, |c| c.len()),
    }
}

/// Convert Delta operations to the serializable DiffOperation format.
fn delta_to_serde_ops(delta: &Delta) -> Vec<TextOperationSerde> {
    delta
        .operations
        .iter()
        .map(|op| match op {
            crate::api::text::delta::TextOperation::Insert { insert, attributes } => {
                TextOperationSerde::Insert {
                    insert: insert.clone(),
                    attributes: attributes.clone(),
                }
            }
            crate::api::text::delta::TextOperation::Retain { retain, attributes } => {
                TextOperationSerde::Retain {
                    retain: *retain,
                    attributes: attributes.clone(),
                }
            }
            crate::api::text::delta::TextOperation::Delete { delete } => {
                TextOperationSerde::Delete { delete: *delete }
            }
        })
        .collect()
}

/// Convenience function: diff two JSON-serialized document trees.
pub fn diff_json_documents(
    old_json: &serde_json::Map<String, Value>,
    new_json: &serde_json::Map<String, Value>,
) -> Option<TreeDiff> {
    let old_doc = crate::api::text::content_reader::ContentReader::read(old_json)?;
    let new_doc = crate::api::text::content_reader::ContentReader::read(new_json)?;
    Some(diff_trees(&old_doc, &new_doc))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::text::content_reader::ContentReader;
    use serde_json::json;

    #[test]
    fn test_diff_identical_trees() {
        let json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "Hello World"}]
                }
            }]
        });

        let doc1 = ContentReader::read(json.as_object().unwrap()).unwrap();
        let doc2 = ContentReader::read(json.as_object().unwrap()).unwrap();

        let diff = diff_trees(&doc1, &doc2);
        assert!(diff.is_empty());
    }

    #[test]
    fn test_diff_content_changed() {
        let old_json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "Hello"}]
                }
            }]
        });
        let new_json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "Hello World"}]
                }
            }]
        });

        let diff =
            diff_json_documents(old_json.as_object().unwrap(), new_json.as_object().unwrap())
                .unwrap();
        assert!(!diff.is_empty());
        assert!(diff.nodes_modified >= 1);
    }

    #[test]
    fn test_diff_node_added() {
        let old_json = json!({
            "type": "page",
            "children": []
        });
        let new_json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "New paragraph"}]
                }
            }]
        });

        let diff =
            diff_json_documents(old_json.as_object().unwrap(), new_json.as_object().unwrap())
                .unwrap();
        assert_eq!(diff.nodes_added, 1);
    }

    #[test]
    fn test_diff_node_removed() {
        let old_json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "To be removed"}]
                }
            }]
        });
        let new_json = json!({
            "type": "page",
            "children": []
        });

        let diff =
            diff_json_documents(old_json.as_object().unwrap(), new_json.as_object().unwrap())
                .unwrap();
        assert_eq!(diff.nodes_removed, 1);
    }

    #[test]
    fn test_diff_node_type_changed() {
        let old_json = json!({
            "type": "page",
            "children": [{
                "type": "paragraph",
                "attributes": {
                    "delta": [{"insert": "Same text"}]
                }
            }]
        });
        let new_json = json!({
            "type": "page",
            "children": [{
                "type": "heading",
                "attributes": {
                    "delta": [{"insert": "Same text"}],
                    "level": 1
                }
            }]
        });

        let diff =
            diff_json_documents(old_json.as_object().unwrap(), new_json.as_object().unwrap())
                .unwrap();
        // Type change + attribute change (level added)
        assert!(diff.nodes_modified >= 1);
    }
}
