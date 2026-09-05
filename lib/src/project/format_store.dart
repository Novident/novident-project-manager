import 'dart:convert';

import 'package:novident_project_manager/src/format/format.dart';
import 'package:novident_project_manager/src/layout/layout.dart';

/// I/O boundary for the compiler store (formats + layouts).
abstract class CompilerIo {
  Future<List<String>> listFormats();
  Future<String?> readFormat(String id);
  Future<void> writeFormat(String id, String json);
  Future<void> deleteFormat(String id);

  Future<List<String>> listLayouts();
  Future<String?> readLayout(String id);
  Future<void> writeLayout(String id, String json);
  Future<void> deleteLayout(String id);
}

/// Lazy host (not a cache) of all compilation formats and their layouts.
///
/// Nothing is loaded eagerly: a [Format] and the [Layout]s it references are
/// read from [CompilerIo] and related only when first requested via
/// [loadFormat]. Once loaded they remain in memory for the store's lifetime
/// (no eviction).
///
/// The relation is by id — a format references layout ids on disk, each layout
/// lives in its own file — so layouts are always resolved before the format
/// that references them.
class FormatStore {
  FormatStore({required this.io});

  final CompilerIo io;
  final Map<String, Format> _formats = <String, Format>{};
  final Map<String, Layout> _layouts = <String, Layout>{};

  Future<List<String>> listFormats() => io.listFormats();

  Future<List<String>> listLayouts() => io.listLayouts();

  /// Loads (and relates) a format with its layouts, on demand.
  Future<Format> loadFormat(String id) async {
    final cached = _formats[id];
    if (cached != null) return cached;

    final json = await io.readFormat(id);
    if (json == null) {
      throw StateError('format not found: $id');
    }
    final map = jsonDecode(json) as Map<String, dynamic>;
    final layoutIds =
        (map['layouts'] as List?)?.cast<String>() ?? const <String>[];

    // Relate layouts (layouts first), then assemble.
    final layouts = <Layout>[];
    for (final layoutId in layoutIds) {
      layouts.add(await loadLayout(layoutId));
    }

    final format = Format.fromMap(map).copyWith(layouts: layouts);
    _formats[id] = format;
    return format;
  }

  /// Loads a single layout on demand.
  Future<Layout> loadLayout(String id) async {
    final cached = _layouts[id];
    if (cached != null) return cached;

    final json = await io.readLayout(id);
    if (json == null) {
      throw StateError('layout not found: $id');
    }
    final layout = Layout.fromJson(json);
    _layouts[id] = layout;
    return layout;
  }

  /// Bulk-loads every layout first, then every format (relation-ready).
  Future<void> loadAll() async {
    for (final id in await io.listLayouts()) {
      await loadLayout(id);
    }
    for (final id in await io.listFormats()) {
      await loadFormat(id);
    }
  }

  /// Persists a format and its layouts, updating the in-memory store.
  Future<void> saveFormat(Format format) async {
    await io.writeFormat(format.id, format.toJson());
    for (final layout in format.layouts) {
      await io.writeLayout(layout.id, layout.toJson());
    }
    _formats[format.id] = format;
    for (final layout in format.layouts) {
      _layouts[layout.id] = layout;
    }
  }

  /// Persists a single layout, updating the in-memory store.
  Future<void> saveLayout(Layout layout) async {
    await io.writeLayout(layout.id, layout.toJson());
    _layouts[layout.id] = layout;
  }

  Future<void> deleteFormat(String id) async {
    await io.deleteFormat(id);
    _formats.remove(id);
  }

  Future<void> deleteLayout(String id) async {
    await io.deleteLayout(id);
    _layouts.remove(id);
  }

  void clear() {
    _formats.clear();
    _layouts.clear();
  }
}
