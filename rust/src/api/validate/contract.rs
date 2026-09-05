//! Loads the versioned structural contract (`schema/schema-v1.yaml`).
//!
//! The contract is the only piece of schema Rust retains. It declares which
//! files/directories must exist, which collections exist, which integrity
//! checks run, and identifier conventions — without entering field-level
//! schema (owned by Dart).

use serde::Deserialize;

/// The structural contract for one `.nov` format version.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct Contract {
    pub version: u32,
    #[serde(default)]
    pub required_dirs: Vec<String>,
    #[serde(default)]
    pub required_files: Vec<String>,
    #[serde(default)]
    pub optional_files: Vec<String>,
    #[serde(default)]
    pub collections: Vec<Collection>,
    #[serde(default)]
    pub checks: Vec<String>,
    #[serde(default)]
    pub conventions: Conventions,
}

/// A directory of one-file-per-item files, keyed by `key`.
#[derive(Debug, Clone, Default, Deserialize)]
pub struct Collection {
    pub dir: String,
    pub key: String,
}

/// Identifier conventions (regexes + canonical values).
#[derive(Debug, Clone, Default, Deserialize)]
pub struct Conventions {
    #[serde(default)]
    pub id_pattern: Option<String>,
    #[serde(default)]
    pub comment_id_pattern: Option<String>,
    #[serde(default)]
    pub section_sentinel: Option<String>,
    #[serde(default)]
    pub folder_types: Vec<String>,
}

impl Contract {
    /// Bundled v1 contract (the only version shipped so far).
    const V1: &'static str = include_str!("../../../schema/schema-v1.yaml");

    /// Loads the contract for `version`, if one is bundled.
    pub fn load(version: u32) -> Option<Contract> {
        match version {
            1 => serde_yaml::from_str(Self::V1).ok(),
            _ => None,
        }
    }

    /// The section sentinel (default `"structured-based"`).
    pub fn sentinel(&self) -> &str {
        self.conventions
            .section_sentinel
            .as_deref()
            .unwrap_or("structured-based")
    }
}
