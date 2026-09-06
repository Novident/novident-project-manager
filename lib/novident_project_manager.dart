/// Public API of `novident_project_manager`.
///
/// Exposes the schema layer (typed models and codecs), the stores and their I/O
/// contracts, the reducer, the schema registry/migration, and the compiler
/// (layout/editor → AST parsers and the AST model).
library;

export 'src/constants/constants.dart';

// AST
export 'src/ast/ast.dart';
export 'src/compiler/compiler.dart';

export 'src/engine/engine.dart';
export 'src/format/format.dart';
export 'src/layout/layout.dart';
export 'src/layout/processor_context.dart';
export 'src/layout/separators/layout_separator.dart';

// API Defaults
export 'src/project/author/author.dart';
export 'src/project/backup/backup.dart';
export 'src/project/comments/comments.dart';
export 'src/project/content/text_count.dart';
export 'src/project/corkboard/corkboard.dart';
export 'src/project/export/export.dart';
export 'src/project/icon/icon.dart';
export 'src/project/section/section.dart';
export 'src/project/section/section_manager.dart';
export 'src/project/section/section_types_configuration.dart';
export 'src/project/session/session.dart';
export 'src/project/session/session_adjust.dart';
export 'src/project/session/session_builder.dart';
export 'src/project/session/session_diff.dart';
export 'src/project/session/session_history.dart';
export 'src/project/target/target.dart';
export 'src/project/target/target_resolver.dart';
export 'src/project/binder_codec.dart';
export 'src/project/binder_store.dart';
export 'src/project/binder_types.dart';
export 'src/project/collection_store.dart';
export 'src/project/content_codec.dart';
export 'src/project/document_cache.dart';
export 'src/project/format_store.dart';
export 'src/project/lru_cache.dart';
export 'src/project/processor_metadata.dart';
export 'src/project/sections_codec.dart';
export 'src/project/project_configurations.dart';
export 'src/project_manager.dart';
export 'src/reducer/binder_actions.dart';
export 'src/reducer/binder_counts.dart';
export 'src/exceptions/reducer_exceptions.dart';
export 'src/schema/migration/schema_migration.dart';
export 'src/schema/registry.dart';

// Placeholders
export 'src/rule/placeholder/placeholder_rule_mixin.dart';
export 'src/rule/placeholder/placeholder_rules.dart';
export 'src/rule/placeholder/type_placeholder_enum.dart';
export 'src/rule/placeholder/rules/rules.dart';
export 'src/rule/placeholder/utils/string_utils.dart';

// Project rules
export 'src/rule/project_rules/project_rules.dart';
export 'src/rule/project_rules/project_status_response.dart';
export 'src/rule/project_rules/project_rule_mixin.dart';

// Extensions
export 'src/extensions/string_extension.dart';
export 'src/extensions/cast_extension.dart';
export 'src/extensions/project_extensions.dart';
export 'src/extensions/format_scope_extension.dart';
export 'src/extensions/project_delta_content_extension.dart';
export 'src/extensions/map_extensions.dart';
export 'src/extensions/list_extension.dart';
