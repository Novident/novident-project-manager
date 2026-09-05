
import 'package:novident_editor_delta_simplify/novident_editor_delta_simplify.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import '../../layout/processor_context.dart';

/// This is the base ruler for all the placeholders
mixin PlaceholderRule {
  /// The placeholder pattern (usually passed using [ProjectDefaults.placeholder])
  Pattern get pattern;

  /// Determines if we really need to apply or set a replace condition to our Delta
  bool checkIfNeedApply(Delta delta);

  /// Apply the change directly to the Delta
  Delta apply(Delta delta, Context context);

  /// Set a [ReplaceCondition] condition [to] a QueryDelta to be builded later
  ///
  /// Usually improves the perfomance of the replace operations
  QueryDelta setConditionRule(QueryDelta query, Context context);
}
