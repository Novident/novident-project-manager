import '../format/format_scope.dart';

extension FormatScopeExtension on FormatScope {
  bool get isGlobal => this == FormatScope.global;
  bool get isDefault => this == FormatScope.novident;
  bool get isProject => this == FormatScope.project;
  bool get noScope => this == FormatScope.noScope;
}
