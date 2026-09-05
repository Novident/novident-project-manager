//! Error types for the engine facade.
//!
//! The facade returns `Result<T, ProjectError>`; FRB maps the error to a Dart
//! exception carrying a machine-readable `code` and a human `message`.

use std::fmt;

use serde::{Deserialize, Serialize};

/// Machine-readable error categories.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    Validation,
    NotFound,
    Conflict,
    SchemaVersion,
    Git,
    Io,
    Permission,
    Internal,
}

/// A structured project error (maps to a Dart exception via FRB).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectError {
    pub code: ErrorCode,
    pub message: String,
}

impl ProjectError {
    pub fn new(code: ErrorCode, message: impl fmt::Display) -> Self {
        Self {
            code,
            message: message.to_string(),
        }
    }

    pub fn io(message: impl fmt::Display) -> Self {
        Self::new(ErrorCode::Io, message)
    }

    pub fn not_found(message: impl fmt::Display) -> Self {
        Self::new(ErrorCode::NotFound, message)
    }

    pub fn git(message: impl fmt::Display) -> Self {
        Self::new(ErrorCode::Git, message)
    }

    pub fn validation(message: impl fmt::Display) -> Self {
        Self::new(ErrorCode::Validation, message)
    }

    pub fn internal(message: impl fmt::Display) -> Self {
        Self::new(ErrorCode::Internal, message)
    }
}

impl fmt::Display for ProjectError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for ProjectError {}
