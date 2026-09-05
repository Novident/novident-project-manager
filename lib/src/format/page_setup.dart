/// Paper setup of a format (the `page_setup` block of `compiler/formats/`).
class PageSetup {
  /// Paper size identifier (for example `letter`, `digital`), free-form.
  final String paperSize;

  /// Page margins.
  final Margins margins;

  /// Running headers/footers, when the format defines any.
  final HeaderFooter? headerFooter;

  /// Builds a page setup.
  const PageSetup({
    this.paperSize = '',
    this.margins = const Margins(),
    this.headerFooter,
  });

  /// Parses a page setup from its on-disk JSON shape (tolerant of missing
  /// fields).
  factory PageSetup.fromJson(Map<String, dynamic> json) => PageSetup(
        paperSize: json['paper_size'] as String? ?? '',
        margins: Margins.fromJson(
            json['margins'] as Map<String, dynamic>? ?? const {}),
        headerFooter: json['header_footer'] is Map<String, dynamic>
            ? HeaderFooter.fromJson(
                json['header_footer'] as Map<String, dynamic>)
            : null,
      );

  /// Serializes the page setup to its on-disk JSON shape; `header_footer` is
  /// only emitted when present.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'paper_size': paperSize,
        'margins': margins.toJson(),
        if (headerFooter != null) 'header_footer': headerFooter!.toJson(),
      };
}

/// Page margins in the format's units.
class Margins {
  /// Top margin.
  final double top;

  /// Bottom margin.
  final double bottom;

  /// Left margin.
  final double left;

  /// Right margin.
  final double right;

  /// Builds margins; every side defaults to zero.
  const Margins({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });

  /// Parses margins from their on-disk JSON shape (tolerant of missing
  /// fields).
  factory Margins.fromJson(Map<String, dynamic> json) => Margins(
        top: (json['top'] as num?)?.toDouble() ?? 0,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
        left: (json['left'] as num?)?.toDouble() ?? 0,
        right: (json['right'] as num?)?.toDouble() ?? 0,
      );

  /// Serializes the margins to their on-disk JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'top': top,
        'bottom': bottom,
        'left': left,
        'right': right,
      };
}

/// Running headers/footers used when compiling. Values are token strings
/// (`<$doctitle>`, `<$n>`, `<$page>`, …).
class HeaderFooter {
  /// Text of the header on the left side, when set.
  final String? headerLeft;

  /// Text of the header in the center, when set.
  final String? headerCenter;

  /// Text of the header on the right side, when set.
  final String? headerRight;

  /// Text of the footer on the left side, when set.
  final String? footerLeft;

  /// Text of the footer in the center, when set.
  final String? footerCenter;

  /// Text of the footer on the right side, when set.
  final String? footerRight;

  /// Builds the running header/footer; every slot defaults to `null`.
  const HeaderFooter({
    this.headerLeft,
    this.headerCenter,
    this.headerRight,
    this.footerLeft,
    this.footerCenter,
    this.footerRight,
  });

  /// Parses the running header/footer from its on-disk JSON shape (absent
  /// slots stay `null`).
  factory HeaderFooter.fromJson(Map<String, dynamic> json) => HeaderFooter(
        headerLeft: json['header_left'] as String?,
        headerCenter: json['header_center'] as String?,
        headerRight: json['header_right'] as String?,
        footerLeft: json['footer_left'] as String?,
        footerCenter: json['footer_center'] as String?,
        footerRight: json['footer_right'] as String?,
      );

  /// Serializes the running header/footer; unset slots are omitted.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (headerLeft != null) 'header_left': headerLeft,
        if (headerCenter != null) 'header_center': headerCenter,
        if (headerRight != null) 'header_right': headerRight,
        if (footerLeft != null) 'footer_left': footerLeft,
        if (footerCenter != null) 'footer_center': footerCenter,
        if (footerRight != null) 'footer_right': footerRight,
      };
}
