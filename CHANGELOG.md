# Changelog

All notable changes to the `novident_project_manager` project.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] — 2026-09-06

* fix: missing export for `Synopsis` class.

## [1.0.2] — 2026-09-06

* chore(breaking changes): removed `getNodeComment` for `Context` implementations. 
* chore(breaking changes): removed `metadataSection` for `LayoutSectionManager` for future implementation of `<$custom:<filed>>` placeholder. 
* fix(breaking changes): force `getNodeContent`, `getNodeSynopsis` and `getNodeNotes` to return futures and the exact types expected for `Context` implementations.  
* fix: added missing `Synopsis` class that mirrors the `synopsis.json` file format.  
* fix: `ReplacementValues` are not being deserialized as expected from the `.nov` official format and the `fromJson` method from class.  
* fix: license format.
* fix: `PlaceholderRules` now accepts `ReplacementValues` to work as part of the placeholder replacement process through `customReplacements` property.
* feat: added missing `files/styles.json` to the Rust and Dart engines (generic for custom implementations).  
* feat: added static `customNodeToAstCallbacksRegistry` for `ContentParser` class to allow custom nodes to be converted to AST nodes.  

## [1.0.1] — 2026-09-05

* fix: `Context` class try to return unused `UniversalValue` as Object. Replaced directly with generics. 

## [1.0.0] — 2026-09-05

* First release

