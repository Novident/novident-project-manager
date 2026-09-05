import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/format/format.dart';

void main() {
  test('Format.toMap stores layouts as ids + font_family + schema_version', () {
    final map = Format.empty().toMap();

    expect(map['layouts'], isEmpty); // ids, not embedded layouts
    expect(map.containsKey('font_family'), isTrue);
    expect(map.containsKey('family'), isFalse);
    expect(map['schema_version'], 1);
  });

  test('Format.fromMap reads font_family and leaves layouts empty', () {
    final format = Format.empty();
    final decoded = Format.fromMap(format.toMap());

    expect(decoded.id, format.id);
    expect(decoded.name, format.name);
    expect(decoded.fontFamily, format.fontFamily);
    expect(decoded.canChange, format.canChange);
    expect(decoded.layouts, isEmpty); // ids are not embedded; store resolves them
  });
}
