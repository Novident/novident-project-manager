# Security

`novident_project_manager` opens and edits `.nov` projects — directories that
may come from other machines, from the network, or from backups. Treat every
project as untrusted input until validated.

## Threat model

| Asset | Attacker goal | Controls |
|---|---|---|
| `.nov` project files | Malformed/poisoned JSON to crash or confuse | Tolerant `fromJson`, structural validation (`schema-v1.yaml`), schema version guard |
| Newer schema files | Downgrade/corruption | `SchemaMigrator` rejects `schema_version > current` (`SchemaTooNewException`) before any write |
| Path traversal (`..`, absolute) | Escape the project directory | Rust `safe_component` + engine path handling rejects traversal on semantic paths |
| Attached/binary files (`files/external/`) | Payload delivery | Stored only as project resources; the app must scan with the platform's own tools before opening |
| Git remotes | Credential theft / malicious history | Credentials passed per call; We never persist credentials |
| Replay of backups/snapshots | Restore overwrites work | `restoreSnapshot` is explicit and overwrites; document that a manual backup is the recovery path |

## What this package does NOT do

- It is **not** a sandbox for opening external content (images, PDFs,
  imported editor documents). Open those with the OS/browser stack of the host
  app.
- It does **not** encrypt project content at rest.
- Dart and Rust does **not** save any git credentials passed to the git related methods.

## Security rules for maintainers

1. Never saves in the project structure the credentials, git tokens, or full file contents of external
   files at debug level.
2. New engine entry points that accept user-controlled strings must keep the
   `safe_component`/path checks; add a regression test for traversal.
3. New Dart `fromJson`s must stay tolerant (no unbounded recursion, no casts
   that crash on missing keys); large nested documents are the norm.
4. Keep dependencies current and pinned as `^` with the owner's approval
   (`AGENTS.md` non-negotiable 14).
5. Do not run untrusted `.nov` content through code generators or shell.

## Reporting a vulnerability

Do **not** open a public issue for vulnerabilities. Report privately to the
maintainers (see `CONTRIBUTING.md` for contacts/process) or report to novidentteam@gmail.com with:

- affected version(s) and a minimal repro (`.nov` fixture if possible),
- impact scenario and suggested severity.
