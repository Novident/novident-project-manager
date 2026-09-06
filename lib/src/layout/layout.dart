import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:novident_nodes/novident_nodes.dart';

import '../../novident_project_manager.dart';

export 'options/new_page_options.dart';
export 'options/layout_manager.dart';
export 'options/layout_sections.dart';
export 'options/layout_indents.dart';
export 'options/section_separators_options.dart';
export 'options/section_attributes.dart';
export 'options/title_options.dart';
export 'separators/layout_separator.dart';
export 'enums.dart';
export 'processor_context.dart';

/// Layouts provide centralized control over document presentation by defining
/// formatting rules for different content sections (title, metadata, synopsis, etc.).
/// When applied to documents, these layouts automatically enforce consistent styling
/// without manual formatting effort.
///
/// Key features:
/// - Preconfigured section visibility and styling
/// - Automatic Delta generation for Quill-based editors
/// - Serialization/deserialization support
/// - Immutable design with copy-with functionality
/// - Section-specific formatting overrides
@immutable
final class Layout extends Equatable {
  /// Unique identifier for the layout
  final String id;

  /// Human-readable layout name
  final String name;

  /// ID of the associated section (empty if unassigned)
  final String assignedSection;

  /// Central manager for section configurations
  final LayoutSectionManager layoutManager;

  /// Title display and formatting options
  late final TitleOptions titleOptions;

  /// Page break and spacing controls
  late final NewPageOptions newPageOptions;

  /// Section separation rules
  late final SeparatorOptions separatorSections;

  /// Indentation and spacing settings
  late final LayoutSettingsIndent settings;

  /// Creates a Layout with customizable sections and formatting
  ///
  /// [id]: Unique identifier (auto-generated if not provided)
  /// [name]: Layout display name
  /// [layoutManager]: Section configuration manager
  /// [assignedSection]: Associated section ID
  /// [separatorSections]: Section separation rules (defaults to common)
  /// [titleOptions]: Title formatting (defaults to common)
  /// [newPageOptions]: Page break rules (defaults to common)
  /// [settings]: Indentation settings (defaults to common)
  Layout({
    required this.id,
    required this.name,
    required this.layoutManager,
    this.assignedSection = '',
    SeparatorOptions? separatorSections,
    TitleOptions? titleOptions,
    NewPageOptions? newPageOptions,
    LayoutSettingsIndent? settings,
  }) {
    this.settings = settings ?? LayoutSettingsIndent.common();
    this.separatorSections = separatorSections ?? SeparatorOptions.common();
    this.titleOptions = titleOptions ?? TitleOptions.common();
    this.newPageOptions = newPageOptions ?? NewPageOptions.common();
  }

  /// Factory constructor for creating layouts with granular control
  ///
  /// Provides simplified parameterization for common use cases:
  /// - [shareThisAttributesToAll]: Applies same attributes to all sections
  /// - [titleAlign]/[fontSize]: Title-specific formatting
  /// - [show...] parameters: Section visibility toggles
  /// - [textLineSpacing]: Body text spacing
  /// - Attribute overrides for individual sections
  factory Layout.basic({
    String? id,
    String? name,
    String? assigned,
    String? titleAlign,
    double? fontSize,
    bool? boldTitle,
    bool? underlineTitle,
    bool showTitle = false,
    bool showMetadata = false,
    bool showSynopsis = false,
    bool showNotes = false,
    bool showText = false,
    double? titleLineSpacing,
    double? textLineSpacing,
    TitleOptions? titleOptions,
    NewPageOptions? newPageOptions,
    SeparatorOptions? separatorOptions,
    LayoutSettingsIndent? settings,
    SectionAttributes? shareThisAttributesToAll,
    SectionAttributes? titleAttr,
    SectionAttributes? metaAttr,
    SectionAttributes? textAttr,
    SectionAttributes? synopsisAttr,
    SectionAttributes? notesAttr,
  }) =>
      Layout(
        id: id ?? NodeDetails.createNodeId(),
        titleOptions: titleOptions,
        separatorSections: separatorOptions,
        settings: settings,
        newPageOptions: newPageOptions,
        assignedSection: assigned ?? '',
        name: name ?? NovidentProjectDefaults.kDefaultUnnamedLayout,
        layoutManager: LayoutSectionManager(
          titleSection: LayoutSection(
            show: showTitle,
            title: 'Section title',
            attributes: shareThisAttributesToAll != null
                ? shareThisAttributesToAll.copyWith(
                    align: titleAlign,
                    lineHeight: titleLineSpacing,
                    bold: boldTitle ?? false,
                    underline: underlineTitle ?? false,
                    fontSize: fontSize ?? 16,
                  )
                : titleAttr ??
                    SectionAttributes.common(
                      lineHeight: titleLineSpacing,
                      align: titleAlign ?? 'left',
                      bold: boldTitle ?? false,
                      underline: underlineTitle ?? false,
                      automaticIndent: false,
                      fontSize: fontSize ?? 16,
                    ),
          ),
          synopsisSection: LayoutSection(
            show: showSynopsis,
            title: 'Synopsis',
            attributes: shareThisAttributesToAll ??
                synopsisAttr ??
                SectionAttributes.common(
                  align: 'left',
                  fontSize: 12,
                  automaticIndent: false,
                  bold: false,
                ),
          ),
          notesSection: LayoutSection(
            show: showNotes,
            title: 'Notes',
            attributes: shareThisAttributesToAll ??
                notesAttr ??
                SectionAttributes.common(
                  align: 'left',
                  fontSize: 12,
                  automaticIndent: false,
                  bold: false,
                ),
          ),
          textSection: LayoutSection(
            show: showText,
            overrideTextSection: false,
            overrideAlign: false,
            title: '',
            attributes: shareThisAttributesToAll != null
                ? shareThisAttributesToAll.copyWith(
                    lineHeight: textLineSpacing ?? 1.0,
                    fontSize: 12,
                    align: 'left',
                  )
                : textAttr ??
                    SectionAttributes.common(
                      lineHeight: textLineSpacing ?? 1.0,
                      align: 'left',
                      fontSize: 12,
                      automaticIndent: false,
                    ),
          ),
        ),
      );

  Layout copyWith({
    String? id,
    String? name,
    String? assignedSection,
    LayoutSectionManager? layoutManager,
    LayoutSettingsIndent? settings,
    TitleOptions? titleOptions,
    SeparatorOptions? separatorSections,
    NewPageOptions? newPageOptions,
  }) {
    return Layout(
      id: id ?? this.id,
      newPageOptions: newPageOptions ?? this.newPageOptions,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      assignedSection: assignedSection ?? this.assignedSection,
      layoutManager: layoutManager ?? this.layoutManager,
      titleOptions: titleOptions ?? this.titleOptions,
      separatorSections: separatorSections ?? this.separatorSections,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schema_version': kCurrentSchemaVersion,
      'id': id,
      'name': name,
      'section': assignedSection,
      'layout_manager': layoutManager.toMap(),
      'title_options': titleOptions.toMap(),
      'new_page_options': newPageOptions.toMap(),
      'separator_options': separatorSections.toMap(),
      'settings': settings.toMap(),
    };
  }

  factory Layout.fromMap(Map<String, dynamic> map) {
    return Layout(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      assignedSection: map['section'] as String? ?? '',
      settings: map['settings'] is Map<String, dynamic>
          ? LayoutSettingsIndent.fromMap(
              map['settings'] as Map<String, dynamic>)
          : LayoutSettingsIndent.common(),
      newPageOptions: map['new_page_options'] is Map<String, dynamic>
          ? NewPageOptions.fromMap(
              map['new_page_options'] as Map<String, dynamic>)
          : NewPageOptions.common(),
      layoutManager: map['layout_manager'] is Map<String, dynamic>
          ? LayoutSectionManager.fromMap(
              map['layout_manager'] as Map<String, dynamic>)
          : LayoutSectionManager.fromMap(const <String, dynamic>{}),
      titleOptions: map['title_options'] is Map<String, dynamic>
          ? TitleOptions.fromMap(map['title_options'] as Map<String, dynamic>)
          : TitleOptions.common(),
      separatorSections: map['separator_options'] is Map<String, dynamic>
          ? SeparatorOptions.fromMap(
              map['separator_options'] as Map<String, dynamic>)
          : SeparatorOptions.common(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Layout.fromJson(String source) =>
      Layout.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Generates the formatted AST `DocumentPage` for a binder [file].
  ///
  /// This is a thin delegate to the external [LayoutCompiler]; the conversion
  /// logic lives there so data-class changes do not rewrite it.
  Future<DocumentPage?> applyLayout(
    Node file,
    Context context, {
    String? fontFamily,
    PlaceholderRules? placeholderRules,
  }) =>
      LayoutCompiler.compileLayout(
        this,
        file,
        context,
        fontFamily: fontFamily,
        placeholderRules: placeholderRules,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        assignedSection,
        layoutManager,
        titleOptions,
        newPageOptions,
        separatorSections,
        settings,
      ];
}
