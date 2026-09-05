import 'package:novident_project_manager/src/engine/engine_client.dart';

import 'binder_store.dart';
import 'collection_store.dart';
import 'document_cache.dart';
import 'format_store.dart';

/// Adapter: a `CollectionIo` over the exports collection of the engine.
class EngineExportsIo implements CollectionIo {
  EngineExportsIo(this._engine);

  final EngineClient _engine;

  @override
  Future<List<String>> listKeys() => _engine.listExports();

  @override
  Future<String?> readItem(String key) => _engine.readExport(key);

  @override
  Future<void> writeItem(String key, String json) =>
      _engine.writeExport(key, json);

  @override
  Future<void> deleteItem(String key) => _engine.deleteExport(key);
}

/// Adapter: a `CollectionIo` over the sessions/history collection of the engine.
class EngineSessionsIo implements CollectionIo {
  EngineSessionsIo(this._engine);

  final EngineClient _engine;

  @override
  Future<List<String>> listKeys() => _engine.listSessions();

  @override
  Future<String?> readItem(String key) => _engine.readSession(key);

  @override
  Future<void> writeItem(String key, String json) =>
      _engine.writeSession(key, json);

  @override
  Future<void> deleteItem(String key) => _engine.deleteSession(key);
}

/// Adapter: `BinderIo` over the FRB-typed `EngineClient`.
class EngineBinderIo implements BinderIo {
  EngineBinderIo(this._engine);

  final EngineClient _engine;

  @override
  Future<String?> readBinder() => _engine.readBinder();

  @override
  Future<void> writeBinder(String json) => _engine.writeBinder(json);
}

/// Adapter: `DocumentIo` over the FRB-typed `EngineClient`.
class EngineDocumentIo implements DocumentIo {
  EngineDocumentIo(this._engine);

  final EngineClient _engine;

  @override
  Future<String?> readContent(String nodeId) => _engine.readNodeContent(nodeId);

  @override
  Future<void> writeContent(String nodeId, String json) =>
      _engine.writeNodeContent(nodeId, json);
}

/// Adapter: `CompilerIo` over the FRB-typed `EngineClient`.
class EngineCompilerIo implements CompilerIo {
  EngineCompilerIo(this._engine);

  final EngineClient _engine;

  @override
  Future<List<String>> listFormats() => _engine.listFormats();

  @override
  Future<String?> readFormat(String id) => _engine.readFormat(id);

  @override
  Future<void> writeFormat(String id, String json) =>
      _engine.writeFormat(id, json);

  @override
  Future<void> deleteFormat(String id) => _engine.deleteFormat(id);

  @override
  Future<List<String>> listLayouts() => _engine.listLayouts();

  @override
  Future<String?> readLayout(String id) => _engine.readLayout(id);

  @override
  Future<void> writeLayout(String id, String json) =>
      _engine.writeLayout(id, json);

  @override
  Future<void> deleteLayout(String id) => _engine.deleteLayout(id);
}
