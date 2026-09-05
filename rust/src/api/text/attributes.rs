use serde_json::{Map, Value};
use std::collections::HashSet;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

pub struct DeltaAttributesKeys;

impl DeltaAttributesKeys {
    pub const BOLD: &'static str = "bold";
    pub const ITALIC: &'static str = "italic";
    pub const UNDERLINE: &'static str = "underline";
    pub const STRIKETHROUGH: &'static str = "strikethrough";
    pub const TEXT_COLOR: &'static str = "font_color";
    pub const BACKGROUND_COLOR: &'static str = "bg_color";
    pub const FIND_BACKGROUND_COLOR: &'static str = "find_bg_color";
    pub const CODE: &'static str = "code";
    pub const HREF: &'static str = "href";
    pub const FONT_FAMILY: &'static str = "font_family";
    pub const FONT_SIZE: &'static str = "font_size";
    pub const AUTO_COMPLETE: &'static str = "auto_complete";
    pub const TRANSPARENT: &'static str = "transparent";

    /// The attributes supported sliced.
    pub const SUPPORT_SLICED: &'static [&'static str] = &[
        Self::BOLD,
        Self::ITALIC,
        Self::UNDERLINE,
        Self::STRIKETHROUGH,
        Self::TEXT_COLOR,
        Self::BACKGROUND_COLOR,
        Self::CODE,
    ];

    /// The attributes is partially supported sliced.
    ///
    /// For the code and href attributes, the slice attributes function will only work if the index is in the range of the code or href.
    pub const PARTIAL_SLICED: &'static [&'static str] = &[Self::CODE, Self::HREF];

    // The values supported toggled even if the selection is collapsed.
    pub const SUPPORT_TOGGLED: &'static [&'static str] = &[
        Self::BOLD,
        Self::ITALIC,
        Self::UNDERLINE,
        Self::STRIKETHROUGH,
        Self::CODE,
        Self::FONT_FAMILY,
        Self::TEXT_COLOR,
        Self::BACKGROUND_COLOR,
    ];
}

/// Attributes is used to describe the Node's information.
pub type Attributes = Map<String, Value>;

pub fn is_attributes_equal(a: &Option<Attributes>, b: &Option<Attributes>) -> bool {
    // Option and serde_json::Map already implement PartialEq, so we can compare them directly
    a == b
}

pub fn compose_attributes(
    base: Option<Attributes>,
    other: Option<Attributes>,
    keep_null: bool,
) -> Option<Attributes> {
    let mut attributes = base.unwrap_or_default();
    let other_attrs = other.unwrap_or_default();

    // ...base, ...other
    for (k, v) in other_attrs {
        attributes.insert(k, v);
    }

    if !keep_null {
        attributes.retain(|_, value| !value.is_null());
    }

    if attributes.is_empty() {
        None
    } else {
        Some(attributes)
    }
}

pub fn invert_attributes(from: Option<Attributes>, to: Option<Attributes>) -> Attributes {
    let from = from.unwrap_or_default();
    let to = to.unwrap_or_default();
    let mut attributes = Attributes::new();

    // key in from but not in to, or value is different
    for (key, value) in &from {
        let to_has_key = to.contains_key(key);
        let to_value = to.get(key);

        if (!to_has_key && !value.is_null()) || to_value != Some(value) {
            attributes.insert(key.clone(), value.clone());
        }
    }

    // key in to but not in from, or value is different
    for (key, value) in &to {
        if !from.contains_key(key) && !value.is_null() {
            attributes.insert(key.clone(), Value::Null);
        }
    }

    attributes
}

pub fn diff_attributes(from: Option<Attributes>, to: Option<Attributes>) -> Option<Attributes> {
    let from = from.unwrap_or_default();
    let to = to.unwrap_or_default();
    let mut attributes = Attributes::new();

    // Consolidate the keys of both maps
    let mut all_keys = HashSet::new();
    for key in from.keys() {
        all_keys.insert(key);
    }
    for key in to.keys() {
        all_keys.insert(key);
    }

    for key in all_keys {
        let from_value = from.get(key);
        let to_value = to.get(key);

        if from_value != to_value {
            if let Some(val) = to_value {
                attributes.insert(key.clone(), val.clone());
            } else {
                attributes.insert(key.clone(), Value::Null);
            }
        }
    }

    if attributes.is_empty() {
        None
    } else {
        Some(attributes)
    }
}

/// Helper function to dynamically hash the `serde_json::Value`
fn hash_value<H: Hasher>(value: &Value, state: &mut H) {
    match value {
        Value::Null => 0_u8.hash(state),
        Value::Bool(b) => {
            1_u8.hash(state);
            b.hash(state);
        }
        Value::Number(n) => {
            2_u8.hash(state);
            n.to_string().hash(state); // Convert the numbers to String to hash them safely
        }
        Value::String(s) => {
            3_u8.hash(state);
            s.hash(state);
        }
        Value::Array(arr) => {
            4_u8.hash(state);
            for v in arr {
                hash_value(v, state);
            }
        }
        Value::Object(obj) => {
            5_u8.hash(state);
            // Equivalent to hashAllUnordered for internal maps
            let mut hash_sum: u64 = 0;
            for (k, v) in obj {
                let mut entry_hasher = DefaultHasher::new();
                k.hash(&mut entry_hasher);
                hash_value(v, &mut entry_hasher);
                hash_sum = hash_sum.wrapping_add(entry_hasher.finish());
            }
            hash_sum.hash(state);
        }
    }
}

/// Implementation of hashAttributes emulating the behavior of `Object.hashAllUnordered`
pub fn hash_attributes(base: &Attributes) -> u64 {
    let mut hash_sum: u64 = 0;

    // We iterate computing the individual hash of each key/value pair
    // and sum them (wrapping_add) so the final order does not affect the resulting hash
    for (key, value) in base {
        let mut entry_hasher = DefaultHasher::new();
        key.hash(&mut entry_hasher);
        hash_value(value, &mut entry_hasher);

        hash_sum = hash_sum.wrapping_add(entry_hasher.finish());
    }

    hash_sum
}
