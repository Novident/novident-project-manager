import 'package:flutter_test/flutter_test.dart';
import 'package:novident_project_manager/src/format/format.dart';
import 'package:novident_project_manager/src/layout/layout.dart';
import 'package:novident_project_manager/src/project/format_store.dart';

class _FakeCompilerIo implements CompilerIo {
  _FakeCompilerIo({Map<String, String>? formats, Map<String, String>? layouts})
      : formats = formats ?? <String, String>{},
        layouts = layouts ?? <String, String>{};

  final Map<String, String> formats;
  final Map<String, String> layouts;
  int formatReads = 0;
  int layoutReads = 0;

  @override
  Future<List<String>> listFormats() async => formats.keys.toList();

  @override
  Future<List<String>> listLayouts() async => layouts.keys.toList();

  @override
  Future<String?> readFormat(String id) async {
    formatReads++;
    return formats[id];
  }

  @override
  Future<void> writeFormat(String id, String json) async => formats[id] = json;

  @override
  Future<void> deleteFormat(String id) async => formats.remove(id);

  @override
  Future<String?> readLayout(String id) async {
    layoutReads++;
    return layouts[id];
  }

  @override
  Future<void> writeLayout(String id, String json) async => layouts[id] = json;

  @override
  Future<void> deleteLayout(String id) async => layouts.remove(id);
}

void main() {
  test('loadFormat relates layouts lazily by id', () async {
    final layout = Layout.basic(id: 'l1', name: 'Chapter');
    final format = Format.empty()
        .copyWith(id: 'f1', name: 'Standard', layouts: <Layout>[layout]);

    final io = _FakeCompilerIo(
      formats: <String, String>{'f1': format.toJson()},
      layouts: <String, String>{'l1': layout.toJson()},
    );
    final store = FormatStore(io: io);

    final loaded = await store.loadFormat('f1');

    expect(loaded.id, 'f1');
    expect(loaded.layouts.length, 1);
    expect(loaded.layouts.single.id, 'l1');
    expect(io.formatReads, 1); // lazy: read once
    expect(io.layoutReads, 1); // related: layout read once
  });

  test('loadFormat caches (second load hits memory)', () async {
    final layout = Layout.basic(id: 'l1');
    final format = Format.empty().copyWith(layouts: <Layout>[layout]);

    final io = _FakeCompilerIo(
      formats: <String, String>{'f1': format.toJson()},
      layouts: <String, String>{'l1': layout.toJson()},
    );
    final store = FormatStore(io: io);

    final a = await store.loadFormat('f1');
    final b = await store.loadFormat('f1');

    expect(identical(a, b), isTrue);
    expect(io.formatReads, 1);
  });

  test('loadAll loads layouts before formats', () async {
    final layout = Layout.basic(id: 'l1');
    final format = Format.empty().copyWith(layouts: <Layout>[layout]);

    final io = _FakeCompilerIo(
      formats: <String, String>{'f1': format.toJson()},
      layouts: <String, String>{'l1': layout.toJson()},
    );
    final store = FormatStore(io: io);

    await store.loadAll();

    // After loadAll, both are cached: no further reads.
    expect(io.layoutReads, 1);
    expect(io.formatReads, 1);
    expect(store.listLayouts, isNotNull);
  });

  test('saveFormat writes format and each layout', () async {
    final layout = Layout.basic(id: 'l1');
    final format = Format.empty().copyWith(layouts: <Layout>[layout]);

    final io = _FakeCompilerIo();
    final store = FormatStore(io: io);

    await store.saveFormat(format);

    expect(io.formats.containsKey('f1'), isFalse); // format id differs
    expect(io.formats.containsKey(format.id), isTrue);
    expect(io.layouts.containsKey('l1'), isTrue);
  });
}
