import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/project/target/target.dart';

const TargetIndex base = TargetIndex(
  schemaVersion: 1,
  general: TargetGeneral(typeTarget: 'nanowrimo', target: 50000),
  files: <String, TargetFile>{
    'nodeA': TargetFile(words: 1000, characters: 6000),
  },
);

void main() {
  test('updateGeneral replaces the global goal', () {
    final TargetIndex updated = base.updateGeneral(
      const TargetGeneral(typeTarget: 'custom', target: 90000),
    );
    expect(updated.general.target, 90000);
    expect(updated.files, base.files); // overrides untouched
  });

  test('setOverride adds and replaces without mutating the original', () {
    final TargetIndex added = base.setOverride(
      'nodeB',
      const TargetFile(words: 2000, characters: 12000),
    );
    expect(added.files.keys, containsAll(<String>['nodeA', 'nodeB']));
    expect(base.files.containsKey('nodeB'), isFalse); // immutable

    final TargetIndex replaced = added.setOverride(
      'nodeB',
      const TargetFile(words: 999, characters: 5000),
    );
    expect(replaced.files['nodeB']!.words, 999);
    expect(added.files['nodeB']!.words, 2000); // still the previous value
  });

  test('removeOverride removes only that node', () {
    final TargetIndex removed = base.removeOverride('nodeA');
    expect(removed.files, isEmpty);
    expect(base.files.containsKey('nodeA'), isTrue);
  });

  test('removeOverride of an unset node is a no-op (same instance)', () {
    final TargetIndex removed = base.removeOverride('ghost');
    expect(identical(removed, base), isTrue);
  });

  test('copyWith defaults to the current schema version', () {
    final TargetIndex updated = base.copyWith(general: const TargetGeneral());
    expect(updated.schemaVersion, 1);
  });
}
