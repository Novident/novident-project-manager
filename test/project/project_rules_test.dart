import 'package:flutter_test/flutter_test.dart';
import 'package:novident_nodes/novident_nodes.dart';
import 'package:novident_document_format/novident_document_format.dart';
import 'package:novident_project_manager/src/exceptions/bad_project_state_exception.dart';
import 'package:novident_project_manager/src/rule/project_rules/project_rules.dart';

import 'generators/basic_project.dart';

void main() {
  late Folder root;
  setUp(() {
    root = generateBasicProject();
  });

  test('should pass manuscript check', () {
    expect(
      ProjectRules.checkProjectState(root),
      isTrue,
    );
  });

  test('should fail manuscript check', () {
    root.removeAt(0, shouldNotify: false);

    expect(
      () => ProjectRules.checkProjectState(root),
      throwsA(
        isA<BadProjectStateException>(),
      ),
    );
  });

  test('should pass trash check', () {
    expect(
      ProjectRules.checkProjectState(root),
      isTrue,
    );
  });

  test('should fail trash check', () {
    root.removeLast(shouldNotify: false);
    expect(
      () => ProjectRules.checkProjectState(root),
      throwsA(
        isA<BadProjectStateException>(),
      ),
    );
  });

  test('should pass trash duplicate check', () {
    expect(
      ProjectRules.checkProjectState(root),
      isTrue,
    );
  });

  test('should fail trash duplicate check and pass later', () {
    root.add(
      Folder(
        children: [],
        name: 'Trash2',
        details: NodeDetails.zero(),
        folderType: FolderType.trash,
      ),
    );
    expect(
      () => ProjectRules.checkProjectState(root),
      throwsA(
        isA<BadProjectStateException>(),
      ),
    );
    root.removeLast();

    expect(
      ProjectRules.checkProjectState(root),
      isTrue,
    );
  });

  test('should fail research check', () {
    root.removeWhere(
        (node) => node is Folder && node.type == FolderType.research);
    expect(
      () => ProjectRules.checkProjectState(root),
      throwsA(
        isA<BadProjectStateException>(),
      ),
    );
  });
}
