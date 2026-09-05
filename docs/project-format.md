# The `.nov` project format

Explanation + quick reference of the on-disk format this package owns.

## Layout

A `.nov` **project is a directory** (optionally zipped for transport) with a
git repository inside:

```
files/
  metadata.json              # identity, author, book, preferences, session state, statistics
  backup.json                # compact tree mirror + checksum (generated)
  external/                  # attached files <id>.<ext>
  <node-uuid>/               # per node
    content.json             # rich text: {"document": …} (editor Document)
    synopsis.json            # same content inside an envelope
    comments.json            # { "<id>[-<username>]": { path, date, content } }
    notes.txt                # plain text
indexation/
  binder.index.json          # tree + lookup + external_files (source of truth of hierarchy)
  sections.index.json        # sections + depth outline
  icon.index.json            # icon rules (defaults + per-node overrides)
  corkboard.index.json       # corkboard visual state
  target.index.json          # writing targets (general + per-node)
  search.index.json          # engine-managed full-text index (read-only for Dart)
layouts/l<uuid>.json         # per-section presentation (Dart = source of truth)
compiler/formats/f<uuid>.json # format = layout ids + replacements + page_setup
compiler/exports/e<uuid>.json # export records (output_type, config, format_id)
history/<yyyy-MM-dd>.json     # one writing session per day
snapshots/                    # engine snapshots, zip named date-v<version>
.gitignore  .git/
```

## Content model

`content.json` stores a rich-text block tree in the editor's own format:

```json
{ "document": { "type": "page", "children": [
    { "type": "paragraph", "data": {
        "delta": [ {"insert": "…"}, {"insert": "bold", "attributes": {"bold": true}} ],
        "styleRef": "heading-1" } }
] } }
```

Dart reads/writes it **verbatim** through `ContentCodec` (no transformation).
A comment is double-anchored: an inline `comment` attribute in the delta and a
structural entry in `comments.json`.

## Sections & outline

`sections.index.json` defines the section names plus a depth outline that
resolves `structured-based` nodes by depth:

```json
{ "schema_version": 1,
  "sections": ["structured-based", "chapter", "scene"],
  "outline": { "folder": { "0": "chapter" }, "file": { "0": "scene" } } }
```

## Binder

`binder.index.json` holds the nested `tree`, a flat `lookup` (id → position/
depth/parent) and `external_files`. The lookup is **recomputed** on every
persist (never trusted from disk).

### Notes

* **lookup** is usually used for fast searches to avoiding traverse the entire tree.
* **path** property for internal files refers to where the content is for that node. Every **Node** in the tree supports content reading and writing.
* **path** property for external files, aims to the direct path where the content is. Normally images are stored inside `files/external/` and some special **Node**s can use them to show image viewer, pdf viewer, etc.

```json
{
  "project_id": "<project-id>",
  "project_name": "The Crystal Labyrinth",
  "schema_version": "<current-schema>",
  "version": 1,
  "created_at": "2026-07-15T09:00:00Z",
  "updated_at": "2026-07-23T14:30:00Z",
  "tree": [
    {
      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "name": "Draft",
      "node_type": "folder",
      "folder_type": "manuscript",
      "attached_section": "structured-based",
      "path": "files/b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "children": []
    }
  ],
  "lookup": {
    "<node-id>": {
      "name": "Draft",
      "node_type": "folder",
      "folder_type": "manuscript",
      "parent_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "path": "files/b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "position": [0],
      "depth": 1,
      "child_count": 2
    }
  },
  "external_files": {
    "<unique-file-id>.png": {
      "name": "Labyrinth Map",
      "extension": "png",
      "size_bytes": 0,
      "attached_to": "<node-id>",
      "path": "files/external/<file-uuid>.png"
    },
  }
}

```

## Writing sessions & targets

### Sessions

**Session** is a day: file name `history/<date>.json`, content keyed by node counters (originals at start, finals at end) plus a `total` block with progress against the target (`distance_from_target_*`, 0.0–1.0).

#### Notes

* Commonly **total** is stored independently from the **target**, to allow sessions be compared in different instances.
* We store all the file that changes in the current session into `metadata -> files -> <node-id>`.
* Every session should have an **author** for convenience.

```json
{
  "schema_version": 1,
  "session_id": "3f8e2a1b-9c4d-5678-abcd-ef0123456789",
  "session_date": "2026-07-20T18:30:00Z",
  "author": "Elena Marlowe",
  "metadata": {
    "files": {
      "<node-id>": {
        "original_words": 150,
        "original_characters": 825,
        "words": 187,
        "characters": 1030
      },
    },
    "total": {
      "type_target": "nanowrimo",
      "words": 339,
      "characters": 1870,
      "characters_no_spaces": 1590,
      "distance_from_target_words": 0.1,
      "distance_from_target_characters": 0.1,
      "target": 50000,
      "target_characters": 275000
    }
  }
}
```

### Targets

**Targets** (`target.index.json`) have a global `general` block and optional per-node overrides in `files`; the resolver falls back from node → general.

#### Notes

* **files** property in the refers that all elements inside it, are nodes with a custom target specified independent from the **general** target.
* **type_target** can be configured manually or other apps can override it manually in special dates.

```json
{
  "schema_version": 1,
  "general": {
    "type_target": "nanowrimo",
    "target": 50000,
    "target_characters": 275000,
    "deadline": "2026-11-30T23:59:59Z",
    "genre": "Fantasy",
    "subgenre": "High Fantasy / Coming of Age",
    "audience": "Young Adult to Adult crossover",
    "target_word_count": 90000,
    "current_word_count": 970,
    "language": "en-US"
  },
  "files": {
    "<node-id>": {
      "notify": true,
      "deadline": "2026-09-30T23:59:59Z",
      "words": 50000,
      "characters": 275000
    }
  }
}
```

## Conventions

- Every JSON file the Dart layer owns carries `"schema_version": 1` and is
  migrated on open; newer versions are rejected before opening/writing.
- JSON keys are `snake_case`; two hyphenated keys exist
  `characters_no_spaces` and are mapped in Dart
  codecs.
- **Dart is the source of truth** for Layout/Format serialization; the detailed
  spec lives in `rust/docs/project-format.md`.
- `rust/schema/schema-v1.yaml` is the structural contract Rust validates
  against (required dirs/files, collections, integrity checks).
