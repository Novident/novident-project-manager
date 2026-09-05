import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart' show immutable;
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/format/replacement_values.dart';

import '../constants/constants.dart';
import '../layout/layout.dart';
import '../schema/registry.dart';
import 'format_scope.dart';
import 'page_setup.dart';

export 'page_setup.dart';
export 'format_scope.dart';
export 'replacement_values.dart';

/// A compilation format (`compiler/formats/<id>.json`).
///
/// A format groups the [Layout]s that style each section together with
/// replacements, paper setup and a scope. On disk, `layouts` are stored as
/// **ids** — the store resolves them on demand (see `FormatStore`).
@immutable
class Format extends Equatable {
  /// Unique identifier of the format (the file name key).
  final String id;

  /// Id of the project the format was copied from. It is only set when the
  /// format is saved as a global format, so consumers can trace the origin.
  final String? origin;

  /// Font family used by the compilation. When it equals the special
  /// `by-layout` value, the font family is decided by each [Layout] instead.
  final String fontFamily;

  /// Human-readable name of the format.
  final String name;

  /// Token replacements applied while compiling (`<$projecttitle>`, …).
  final ReplacementsValues replacements;

  /// Scope of the format (built-in, global or project).
  final FormatScope scope;

  /// Layouts grouped by this format (serialized as ids; resolved by the store).
  final List<Layout> layouts;

  /// Whether the user is allowed to edit this format (built-in formats are
  /// usually not editable).
  final bool canChange;

  /// Paper setup of the format, when the format declares one.
  final PageSetup? pageSetup;

  /// Builds a format with explicit values for every field.
  const Format({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.layouts,
    required this.canChange,
    required this.replacements,
    required this.scope,
    this.origin,
    this.pageSetup,
  });

  /// Creates an empty, project-scoped format with a generated id and no
  /// layouts, replacements or page setup.
  Format.empty({
    this.canChange = true,
    this.name = '',
    FormatScope? scope,
  })  : id = NodeDetails.createNodeId(),
        replacements = ReplacementsValues(replacements: <Replacement>{}),
        scope = scope ?? FormatScope.project,
        fontFamily = NovidentProjectDefaults.kDefaultFormatFontFamily,
        layouts = const <Layout>[],
        origin = null,
        pageSetup = null;

  /// Returns a copy with the given fields replaced.
  ///
  /// When [forgetOrigin] is true the copy has `origin = null` regardless of
  /// [origin]; otherwise [origin] falls back to the current value.
  Format copyWith({
    String? origin,
    String? id,
    String? name,
    String? fontFamily,
    FormatScope? scope,
    bool? canChange,
    ReplacementsValues? replacements,
    List<Layout>? layouts,
    PageSetup? pageSetup,
    bool forgetOrigin = false,
  }) {
    return Format(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      origin: forgetOrigin ? null : origin ?? this.origin,
      name: name ?? this.name,
      canChange: canChange ?? this.canChange,
      replacements: replacements ?? this.replacements,
      fontFamily: fontFamily ?? this.fontFamily,
      layouts: layouts ?? this.layouts,
      pageSetup: pageSetup ?? this.pageSetup,
    );
  }

  /// Serializes the format to the on-disk JSON map.
  ///
  /// `layouts` are written as the ids of their [Layout]s; `page_setup` is only
  /// emitted when present.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schema_version': kCurrentSchemaVersion,
      'id': id,
      'origin': origin,
      'name': name,
      'can_change': canChange,
      'replacements': replacements.toJson(),
      'scope': scope.name,
      'font_family': fontFamily,
      'layouts': layouts.map((Layout x) => x.id).toList(),
      if (pageSetup != null) 'page_setup': pageSetup!.toJson(),
    };
  }

  /// Parses a format from its on-disk JSON map.
  ///
  /// Layouts are not embedded in the file: they are read as ids and resolved
  /// on demand by the store, so the parsed format starts with an empty
  /// `layouts` list.
  factory Format.fromMap(Map<String, dynamic> map) {
    return Format(
      id: map['id'] as String? ?? '',
      scope: _formatScopeFrom(map['scope']),
      name: map['name'] as String,
      origin: map['origin'] as String?,
      fontFamily: map['font_family'] as String? ??
          NovidentProjectDefaults.kDefaultFormatFontFamily,
      replacements: ReplacementsValues.fromJson(
          map['replacements'] as Map<String, dynamic>? ?? const {}),
      canChange: map['can_change'] as bool? ?? false,
      pageSetup: map['page_setup'] is Map<String, dynamic>
          ? PageSetup.fromJson(map['page_setup'] as Map<String, dynamic>)
          : null,
      layouts: <Layout>[],
    );
  }

  /// Reads the scope from its serialized form: a name string (canonical) or a
  /// legacy enum index.
  static FormatScope _formatScopeFrom(Object? value) {
    if (value is String) {
      for (final FormatScope scope in FormatScope.values) {
        if (scope.name == value) return scope;
      }
      return FormatScope.noScope;
    }
    if (value is int && value >= 0 && value < FormatScope.values.length) {
      return FormatScope.values[value];
    }
    return FormatScope.noScope;
  }

  /// Serializes the format to a JSON string.
  String toJson() => json.encode(toMap());

  /// Parses a format from its JSON string.
  factory Format.fromJson(String source) =>
      Format.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Format(id: $id, '
      'canChange: $canChange, '
      'replacements: $replacements, '
      'name: $name, '
      'font-family: $fontFamily, '
      'layouts: ${layouts.length}'
      ')';

  /// Returns the first layout that satisfies [predicate], or `null` when none
  /// does.
  Layout? getLayoutWhere({required ConditionalPredicate<Layout> predicate}) {
    return layouts.firstWhereOrNull(predicate);
  }

  @override
  List<Object?> get props => <Object?>[
        name,
        id,
        layouts,
        replacements,
        fontFamily,
        canChange,
        scope,
        origin,
      ];

  /// Creates a deep copy of the format: a new id, every layout cloned with a
  /// new id, `(copy)` appended to the name and [scope] as given.
  Future<Format> duplicate(FormatScope scope, [bool? canChange]) async {
    final List<Layout> tempLayouts = <Layout>[];
    for (Layout layout in layouts) {
      tempLayouts.add(layout.copyWith(id: NodeDetails.createNodeId()));
    }
    return copyWith(
      canChange: canChange ?? true,
      name: '$name (copy)',
      layouts: tempLayouts,
      origin: origin,
      fontFamily: fontFamily,
      replacements: replacements,
      id: NodeDetails.createNodeId(),
      scope: scope,
    );
  }

  /// Whether none of the grouped layouts is assigned to a section.
  bool notAssignedSectionToLayouts() {
    return layouts
        .where(
          (Layout element) => element.assignedSection.isNotEmpty,
        )
        .isEmpty;
  }
}
