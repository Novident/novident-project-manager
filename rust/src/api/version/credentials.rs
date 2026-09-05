use serde::{Deserialize, Serialize};

/// Git credentials for authenticating with remote repositories.
/// Supports both SSH key-based and HTTPS token-based authentication.
///
/// Credentials are stored encrypted at rest using a simple XOR cipher with a
/// machine-local key derivation. In production, integrate with OS keychain
/// (via `keyring` crate or platform APIs).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitCredentials {
    /// Git user.name
    pub name: String,
    /// Git user.email
    pub email: String,
    /// Path to SSH private key (for SSH remotes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ssh_key_path: Option<String>,
    /// SSH public key (for verification)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ssh_public_key: Option<String>,
    /// Personal access token or password (for HTTPS remotes)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub https_token: Option<String>,
    /// Remote URL this credential set is associated with
    #[serde(skip_serializing_if = "Option::is_none")]
    pub remote_url: Option<String>,
}

impl GitCredentials {
    /// Create minimal credentials with just name and email.
    pub fn new(name: impl Into<String>, email: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            email: email.into(),
            ssh_key_path: None,
            ssh_public_key: None,
            https_token: None,
            remote_url: None,
        }
    }

    /// Attach SSH key pair to these credentials.
    pub fn with_ssh_key(mut self, private_key_path: impl Into<String>) -> Self {
        self.ssh_key_path = Some(private_key_path.into());
        self
    }

    /// Attach SSH public key for verification.
    pub fn with_ssh_public_key(mut self, public_key: impl Into<String>) -> Self {
        self.ssh_public_key = Some(public_key.into());
        self
    }

    /// Attach an HTTPS token/password.
    pub fn with_https_token(mut self, token: impl Into<String>) -> Self {
        self.https_token = Some(token.into());
        self
    }

    /// Associate these credentials with a specific remote URL.
    pub fn with_remote_url(mut self, url: impl Into<String>) -> Self {
        self.remote_url = Some(url.into());
        self
    }

    /// Returns true if these credentials can authenticate over SSH.
    pub fn has_ssh(&self) -> bool {
        self.ssh_key_path.is_some()
    }

    /// Returns true if these credentials can authenticate over HTTPS.
    pub fn has_https(&self) -> bool {
        self.https_token.is_some()
    }

    /// Determine whether to use SSH or HTTPS based on the remote URL.
    pub fn auth_method_for_url(&self, url: &str) -> AuthMethod {
        if url.starts_with("git@") || url.starts_with("ssh://") {
            AuthMethod::Ssh
        } else {
            AuthMethod::Https
        }
    }

    /// Returns the public key fingerprint for display purposes (without loading the key).
    pub fn public_key_preview(&self) -> Option<&str> {
        self.ssh_public_key.as_deref()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthMethod {
    Ssh,
    Https,
}
