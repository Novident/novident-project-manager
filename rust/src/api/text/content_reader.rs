use crate::api::text::delta::Delta;
use serde_json::Value;

/// ContentReader parses NovidentEditor JSON into a Rust-native document tree.
/// Supports two JSON shapes:
///   1. `{"document": {"type":"page", "children":[...]}}` — full Document wrapper
///   2. `{"type":"page", "children":[...]}` — raw root node
pub struct ContentReader;

/// Top-level container for a NovidentEditor document tree.
#[derive(Debug, Clone)]
pub struct DocumentNode {
    pub root: Node,
}

/// A single node in the document tree. Mirrors NovidentEditor's Node model:
///   - `node_type`: block type ("page", "paragraph", "heading", "image", etc.)
///   - `children`: nested child nodes (e.g. paragraphs inside a page)
///   - `data`: arbitrary key-value attributes (includes the "delta" key for rich text)
#[derive(Debug, Clone)]
pub struct Node {
    pub node_type: String,
    pub children: Option<Vec<Node>>,
    pub data: Option<serde_json::Map<String, Value>>,
}

impl Node {
    /// Extracts the Quill Delta from this node's `data.delta` field, if present.
    pub fn delta(&self) -> Option<Delta> {
        self.data
            .as_ref()
            .and_then(|data| data.get("delta"))
            .map(Delta::from_json)
    }

    /// Recursively searches the tree for a node whose `data` contains a given key-value pair.
    /// Returns the first match in depth-first order.
    pub fn find_by_attribute(&self, key: &str, value: &Value) -> Option<&Node> {
        if self.data.as_ref().and_then(|d| d.get(key)) == Some(value) {
            return Some(self);
        }
        if let Some(children) = &self.children {
            for child in children {
                if let found @ Some(_) = child.find_by_attribute(key, value) {
                    return found;
                }
            }
        }
        None
    }

    /// Collects all leaf text into a single plain-text string.
    /// Walks the tree depth-first, concatenating Delta plain-text from every node.
    pub fn collect_plain_text(&self) -> String {
        let mut text = String::new();
        if let Some(mut delta) = self.delta() {
            text.push_str(&delta.to_plain_text());
        }
        if let Some(children) = &self.children {
            for child in children {
                text.push_str(&child.collect_plain_text());
            }
        }
        text
    }

    /// Recursively walk the tree and return all nodes (including self) in depth-first order.
    pub fn flatten(&self) -> Vec<&Node> {
        let mut nodes = vec![self];
        if let Some(children) = &self.children {
            for child in children {
                nodes.extend(child.flatten());
            }
        }
        nodes
    }
}

impl ContentReader {
    /// Parse a JSON map into a DocumentNode.
    ///
    /// Supports:
    ///   - `{"document": {...}}` — the full NovidentEditor Document wrapper
    ///   - `{"type": "page", ...}`   — a bare root node
    pub fn read(json: &serde_json::Map<String, Value>) -> Option<DocumentNode> {
        // Try the "document" wrapper first
        if let Some(Value::Object(inner)) = json.get("document") {
            return Node::from_json_value(&Value::Object(inner.clone()))
                .map(|root| DocumentNode { root });
        }

        // Otherwise parse as a bare root node
        Node::from_json_value(&Value::Object(json.clone())).map(|root| DocumentNode { root })
    }
}

impl Node {
    /// Deserialize a single node from a JSON value.
    pub fn from_json_value(value: &Value) -> Option<Self> {
        let obj = value.as_object()?;

        let node_type = obj
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let children = obj.get("children").and_then(|v| {
            v.as_array().map(|arr| {
                arr.iter()
                    .filter_map(Node::from_json_value)
                    .collect::<Vec<_>>()
            })
        });

        // The node's data is stored under either "data" or "attributes" key
        let data = obj
            .get("data")
            .or_else(|| obj.get("attributes"))
            .and_then(|v| v.as_object().cloned());

        let mut node = Node {
            node_type,
            children,
            data,
        };

        // If no explicit data key but the object has extra fields beyond type/children/data/attributes,
        // treat those extra fields as the data map (some formats inline attributes)
        if node.data.is_none() {
            let known_keys: std::collections::HashSet<&str> =
                ["type", "children", "data", "attributes"]
                    .iter()
                    .copied()
                    .collect();
            let extra: serde_json::Map<String, Value> = obj
                .iter()
                .filter(|(k, _)| !known_keys.contains(k.as_str()))
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect();
            if !extra.is_empty() {
                node.data = Some(extra);
            }
        }

        Some(node)
    }

    /// Serialize back to a JSON-compatible Value.
    pub fn to_json_value(&self) -> Value {
        let mut map = serde_json::Map::new();
        map.insert("type".into(), Value::String(self.node_type.clone()));

        if let Some(ref children) = self.children {
            let child_vals: Vec<Value> = children.iter().map(|c| c.to_json_value()).collect();
            map.insert("children".into(), Value::Array(child_vals));
        }
        if let Some(ref data) = self.data {
            map.insert("data".into(), Value::Object(data.clone()));
        }

        Value::Object(map)
    }
}
