/// Scope of a compilation format.
///
/// This enum is managed automatically by Novident; the user never picks one
/// directly.
enum FormatScope {
  /// Format shipped with the app (built-in).
  novident,

  /// Format created by the user and available everywhere.
  global,

  /// Format created by the user but limited to a single project.
  project,

  /// Reserved for future use; should not be used today.
  unknown,

  /// Reserved for the default layout.
  noScope,
}
