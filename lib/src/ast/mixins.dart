import 'package:meta/meta.dart';

mixin Mergable {
  Set<Type> get mergeableTypesSupported;
  bool get canMerge;

  @mustCallSuper
  @mustBeOverridden
  void merge(Object entity) {
    assert(
      mergeableTypesSupported.contains(entity.runtimeType),
      '${entity.runtimeType} not supported '
      'in $mergeableTypesSupported '
      'types specified for $runtimeType',
    );
  }
}
