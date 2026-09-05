import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/layout/options/section_attributes.dart';

void main() {
  test('SectionAttributes roundtrips with snake_case keys', () {
    final attrs = SectionAttributes.common(
      bold: true,
      fontSize: 16,
      align: 'center',
      fontFamily: 'Georgia',
      lineHeight: 1.5,
    );

    final map = attrs.toMap();
    expect(map.containsKey('fontSize'), isFalse);
    expect(map.containsKey('lineHeight'), isFalse);
    expect(map['font_size'], 16);
    expect(map['line_height'], 1.5);
    expect(map['bold'], true);
    expect(map['align'], 'center');

    final decoded = SectionAttributes.fromMap(map);
    expect(decoded.fontSize, 16);
    expect(decoded.lineHeight, 1.5);
    expect(decoded.bold, true);
    expect(decoded.align, 'center');
    expect(decoded.fontFamily, 'Georgia');
  });

  test('SectionAttributes.fromMap is tolerant of missing fields', () {
    final decoded = SectionAttributes.fromMap(const <String, dynamic>{});
    expect(decoded.fontSize, 12); // default
    expect(decoded.bold, false);
    expect(decoded.align, 'left');
    expect(decoded.lineHeight, 1.0);
  });
}
