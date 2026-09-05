//! Structural validation of a `.nov` project, driven by the versioned contract
//! in `schema/schema-v1.yaml`.
//!
//! Validation is tolerant: it reports issues without failing, so a partially
//! corrupt project can still be opened and repaired by Dart.

pub mod contract;
pub mod integrity;

pub use contract::Contract;
pub use integrity::{Severity, ValidationIssue, validate_project};
