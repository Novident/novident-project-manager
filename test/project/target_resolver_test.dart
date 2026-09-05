import 'package:flutter_test/flutter_test.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_project_manager/src/project/target/target.dart';
import 'package:novident_project_manager/src/project/target/target_resolver.dart';

/// root
///  ├── Draft (manuscript)
///  │    ├── d1 (no override)
///  │    └── sub (normal, has override)
///  │         └── d2 (has override)
///  └── Research (research)
///       └── d3 (no override)
Folder buildRoot() {
  final Folder sub = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 3, id: 'd2'), name: 'Deep doc'),
    ],
    details: NodeDetails.byId(level: 2, id: 'sub'),
    name: 'Sub',
  );
  final Folder draft = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 2, id: 'd1'), name: 'One'),
      sub,
    ],
    details: NodeDetails.byId(level: 1, id: 'draft'),
    name: 'Draft',
    folderType: FolderType.manuscript,
  );
  final Folder research = Folder(
    children: <Node>[
      Document(details: NodeDetails.byId(level: 2, id: 'd3'), name: 'Three'),
    ],
    details: NodeDetails.byId(level: 1, id: 'research'),
    name: 'Research',
    folderType: FolderType.research,
  );
  return Folder(
    children: <Node>[draft, research],
    name: 'Project',
    details: NodeDetails.byId(level: 0, id: 'root'),
  );
}

const TargetIndex index = TargetIndex(
  general: TargetGeneral(
    typeTarget: 'nanowrimo',
    target: 50000,
    targetCharacters: 275000,
    deadline: '2026-11-30T23:59:59Z',
  ),
  files: <String, TargetFile>{
    'sub': TargetFile(notify: true, words: 8000, characters: 44000),
    'd2': TargetFile(
      deadline: '2026-09-30T23:59:59Z',
      words: 44500,
      characters: 245000,
    ),
  },
);

void main() {
  final resolver = TargetResolver(index: index, root: buildRoot());

  test('targetOf uses the per-node override when configured', () {
    final NodeTarget d2 = resolver.targetOf('d2')!;
    expect(d2.isOverride, isTrue);
    expect(d2.words, 44500);
    expect(d2.characters, 245000);
    expect(d2.deadline, '2026-09-30T23:59:59Z');
    expect(d2.notify, isFalse);
  });

  test('targetOf falls back to the general target', () {
    final NodeTarget d1 = resolver.targetOf('d1')!;
    expect(d1.isOverride, isFalse);
    expect(d1.words, 50000);
    expect(d1.characters, 275000);
    expect(d1.typeTarget, 'nanowrimo');
    expect(d1.deadline, '2026-11-30T23:59:59Z');
  });

  test('targetOf returns null for a missing node', () {
    expect(resolver.targetOf('ghost'), isNull);
  });

  test('targetsWithinFolder collects overrides of the subtree', () {
    final List<NodeTarget> targets = resolver.targetsWithinFolder('draft');

    final List<String> ids = targets.map((NodeTarget t) => t.nodeId).toList();
    expect(ids, containsAll(<String>['sub', 'd2']));
    expect(ids, isNot(contains('d1'))); // no override → inherits general

    final NodeTarget sub = targets.firstWhere((t) => t.nodeId == 'sub');
    expect(sub.words, 8000);
    expect(sub.notify, isTrue);
  });

  test('targetsWithinFolder on a leaf folder with none is empty', () {
    expect(resolver.targetsWithinFolder('research'), isEmpty);
    expect(resolver.targetsWithinFolder('ghost'), isEmpty);
  });
}
