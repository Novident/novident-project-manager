import 'package:novident_document_format/novident_document_format.dart';

import 'project_status_response.dart';

/// A structural rule that validates an opened project (its binder [Folder]
/// root) before it is imported or exported.
mixin ProjectRule {
  /// Validates [root]; returns the response with the failure reason when the
  /// project does not follow the expected structure.
  ProjectStatusResponse isValid(Folder root);
}
