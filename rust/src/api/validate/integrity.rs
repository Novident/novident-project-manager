//! Integrity + cross-reference checks, driven by the `Contract`.
//!
//! Each check reads files with `crate::api::io` (verbatim) and inspects them as
//! raw `serde_json::Value` — never as typed schema. Issues are collected, not
//! thrown, so a partially corrupt project still validates the rest.

use std::collections::HashSet;
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::api::io::{list_files, read_file};

use super::contract::Contract;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Severity {
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationIssue {
    pub severity: Severity,
    pub path: String,
    pub code: String,
    pub message: String,
}

impl ValidationIssue {
    fn error(path: impl Into<String>, code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            severity: Severity::Error,
            path: path.into(),
            code: code.into(),
            message: message.into(),
        }
    }

    fn warning(
        path: impl Into<String>,
        code: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            severity: Severity::Warning,
            path: path.into(),
            code: code.into(),
            message: message.into(),
        }
    }
}

/// Validates the project at `root` against the contract for `version`.
///
/// Returns issues without failing (tolerant by design).
pub fn validate_project(root: &Path, version: u32) -> Vec<ValidationIssue> {
    let mut issues = Vec::new();

    let Some(contract) = Contract::load(version) else {
        issues.push(ValidationIssue::error(
            "project",
            "schema_version.unknown",
            format!("unsupported schema version: {version}"),
        ));
        return issues;
    };

    check_layout(root, &contract, &mut issues);
    check_parseability(root, &contract, &mut issues);
    check_binder(root, &contract, &mut issues);
    check_cross_refs(root, &contract, &mut issues);

    issues
}

/// Required/optional directories and files must exist.
fn check_layout(root: &Path, c: &Contract, issues: &mut Vec<ValidationIssue>) {
    for dir in &c.required_dirs {
        if !root.join(dir).is_dir() {
            issues.push(ValidationIssue::error(
                dir,
                "required_dir.missing",
                format!("required directory missing: {dir}"),
            ));
        }
    }
    for file in &c.required_files {
        if !root.join(file).is_file() {
            issues.push(ValidationIssue::error(
                file,
                "required_file.missing",
                format!("required file missing: {file}"),
            ));
        }
    }
    for file in &c.optional_files {
        if !root.join(file).is_file() {
            issues.push(ValidationIssue::warning(
                file,
                "optional_file.missing",
                format!("optional file missing: {file}"),
            ));
        }
    }
}

/// Required files (and collection item files) must be valid JSON.
fn check_parseability(root: &Path, c: &Contract, issues: &mut Vec<ValidationIssue>) {
    for file in &c.required_files {
        if let Some(contents) = read_file(root, file)
            && serde_json::from_str::<Value>(&contents).is_err()
        {
            issues.push(ValidationIssue::error(
                file,
                "json.invalid",
                format!("{file} is not valid JSON"),
            ));
        }
    }
    for col in &c.collections {
        for name in list_files(root, &col.dir) {
            if !name.ends_with(".json") {
                continue;
            }
            let rel = format!("{}/{}", col.dir, name);
            if let Some(contents) = read_file(root, &rel)
                && serde_json::from_str::<Value>(&contents).is_err()
            {
                let message = format!("{rel} is not valid JSON");
                issues.push(ValidationIssue::error(rel, "json.invalid", message));
            }
        }
    }
}

/// Binder integrity: unique ids, no cycles, lookup ↔ tree consistency, node paths.
fn check_binder(root: &Path, c: &Contract, issues: &mut Vec<ValidationIssue>) {
    let Some(raw) = read_file(root, "indexation/binder.index.json") else {
        return; // already reported as missing
    };
    let Ok(binder) = serde_json::from_str::<Value>(&raw) else {
        return; // already reported as invalid
    };

    let tree = binder
        .get("tree")
        .and_then(|t| t.as_array())
        .cloned()
        .unwrap_or_default();

    let mut ids: HashSet<String> = HashSet::new();
    for node in &tree {
        let mut ancestors: HashSet<String> = HashSet::new();
        walk_binder_node(node, "tree", &mut ids, &mut ancestors, issues);
    }

    let lookup = binder
        .get("lookup")
        .and_then(|l| l.as_object())
        .cloned()
        .unwrap_or_default();
    for id in &ids {
        if !lookup.contains_key(id) {
            issues.push(ValidationIssue::warning(
                "indexation/binder.index.json",
                "binder.lookup_missing",
                format!("node {id} has no lookup entry"),
            ));
        }
    }
    for id in lookup.keys() {
        if !ids.contains(id) {
            issues.push(ValidationIssue::warning(
                "indexation/binder.index.json",
                "binder.lookup_orphan",
                format!("lookup entry {id} has no tree node"),
            ));
        }
    }

    let _ = c; // contract reserved for future checks (id regex, folder types)
}

/// Recursively checks a binder node: ids, cycles, path consistency.
fn walk_binder_node(
    node: &Value,
    path: &str,
    ids: &mut HashSet<String>,
    ancestors: &mut HashSet<String>,
    issues: &mut Vec<ValidationIssue>,
) {
    let Some(id) = node.get("id").and_then(|v| v.as_str()) else {
        issues.push(ValidationIssue::error(
            "indexation/binder.index.json",
            "binder.node_no_id",
            format!("node at {path} has no id"),
        ));
        return;
    };

    if !ids.insert(id.to_string()) {
        issues.push(ValidationIssue::error(
            "indexation/binder.index.json",
            "binder.duplicate_id",
            format!("duplicate node id: {id}"),
        ));
    }
    if ancestors.contains(id) {
        issues.push(ValidationIssue::error(
            "indexation/binder.index.json",
            "binder.cycle",
            format!("cycle detected at node {id}"),
        ));
        return;
    }

    ancestors.insert(id.to_string());
    if let Some(children) = node.get("children").and_then(|ch| ch.as_array()) {
        for (i, child) in children.iter().enumerate() {
            walk_binder_node(child, &format!("{path}[{i}]"), ids, ancestors, issues);
        }
    }
    ancestors.remove(id);
}

/// Cross-reference integrity: sections, layouts, formats, exports, metadata.
fn check_cross_refs(root: &Path, c: &Contract, issues: &mut Vec<ValidationIssue>) {
    let sentinel = c.sentinel();

    // Sections (binder.attached_section + layouts.section reference these).
    let sections = load_json(root, "indexation/sections.index.json");
    let section_names: HashSet<String> = sections
        .get("sections")
        .and_then(|s| s.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_default();

    // Binder attached_section references.
    let binder = load_json(root, "indexation/binder.index.json");
    if let Some(tree) = binder.get("tree").and_then(|t| t.as_array()) {
        for node in tree {
            check_attached_sections(node, &section_names, sentinel, issues);
        }
    }

    // Layout ids.
    let layout_ids: HashSet<String> = json_stems(root, "layouts");
    for file in list_files(root, "layouts") {
        if !file.ends_with(".json") {
            continue;
        }
        let rel = format!("layouts/{file}");
        let layout = load_json(root, &rel);
        if let Some(sec) = layout.get("section").and_then(|v| v.as_str())
            && !sec.is_empty()
            && sec != sentinel
            && !section_names.contains(sec)
        {
            issues.push(ValidationIssue::error(
                rel,
                "layout.section_unknown",
                format!("layout references unknown section: {sec}"),
            ));
        }
    }

    // Format ids + their layout references.
    let format_ids: HashSet<String> = json_stems(root, "compiler/formats");
    for file in list_files(root, "compiler/formats") {
        if !file.ends_with(".json") {
            continue;
        }
        let rel = format!("compiler/formats/{file}");
        let format_doc = load_json(root, &rel);
        if let Some(layouts) = format_doc.get("layouts").and_then(|l| l.as_array()) {
            for l in layouts {
                if let Some(id) = l.as_str()
                    && !layout_ids.contains(id)
                {
                    issues.push(ValidationIssue::error(
                        &rel,
                        "format.layout_unknown",
                        format!("format references unknown layout: {id}"),
                    ));
                }
            }
        }
    }

    // Export format references.
    for file in list_files(root, "compiler/exports") {
        if !file.ends_with(".json") {
            continue;
        }
        let rel = format!("compiler/exports/{file}");
        let export = load_json(root, &rel);
        if let Some(fid) = export.get("format_id").and_then(|v| v.as_str())
            && !fid.is_empty()
            && !format_ids.contains(fid)
        {
            issues.push(ValidationIssue::error(
                rel,
                "export.format_unknown",
                format!("export references unknown format: {fid}"),
            ));
        }
    }

    // Metadata default_format_id reference.
    let meta = load_json(root, "files/metadata.json");
    if let Some(fid) = meta
        .pointer("/compile_defaults/default_format_id")
        .and_then(|v| v.as_str())
        && !fid.is_empty()
        && !format_ids.contains(fid)
    {
        issues.push(ValidationIssue::warning(
            "files/metadata.json",
            "metadata.default_format_unknown",
            format!("default_format_id references unknown format: {fid}"),
        ));
    }
}

/// Recursively checks `attached_section` references in a binder subtree.
fn check_attached_sections(
    node: &Value,
    sections: &HashSet<String>,
    sentinel: &str,
    issues: &mut Vec<ValidationIssue>,
) {
    if let Some(sec) = node.get("attached_section").and_then(|v| v.as_str())
        && !sec.is_empty()
        && sec != sentinel
        && !sections.contains(sec)
    {
        issues.push(ValidationIssue::warning(
            "indexation/binder.index.json",
            "binder.attached_section_unknown",
            format!("node references unknown section: {sec}"),
        ));
    }
    if let Some(children) = node.get("children").and_then(|ch| ch.as_array()) {
        for child in children {
            check_attached_sections(child, sections, sentinel, issues);
        }
    }
}

/// The set of JSON file stems (file names minus `.json`) in a directory.
fn json_stems(root: &Path, dir: &str) -> HashSet<String> {
    list_files(root, dir)
        .into_iter()
        .filter(|f| f.ends_with(".json"))
        .map(|f| f.trim_end_matches(".json").to_string())
        .collect()
}

/// Reads and parses a JSON file as raw `Value` (or `Null` if missing/invalid).
fn load_json(root: &Path, rel: &str) -> Value {
    read_file(root, rel)
        .and_then(|s| serde_json::from_str::<Value>(&s).ok())
        .unwrap_or(Value::Null)
}
