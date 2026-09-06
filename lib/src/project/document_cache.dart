import 'dart:async';

import 'package:novident_editor_document/novident_editor_document.dart';

import 'content_codec.dart';
import 'lru_cache.dart';

/// I/O boundary for document content (`content.json`).
abstract class DocumentIo {
  Future<String?> readContent(String nodeId);
  Future<void> writeContent(String nodeId, String json);
}

/// On-demand, LRU-bounded document content cache with **debounced writes**.
///
/// Nothing is loaded eagerly: a document's `content.json` is read (and decoded)
/// only when first accessed via [load]. Loaded documents are cached as typed
/// `Document`s, evicted least-recently-used first when over capacity.
///
/// [save] does **not** write immediately; it stages the change in memory and
/// schedules a single write after [saveDelay] (a global, configurable delay
/// shared by every instance). A rapid burst of edits coalesces into one write.
/// Use [flush]/[flushAll] to force an immediate write.
class DocumentCache {
  DocumentCache({required DocumentIo io, int capacity = 50})
      : _io = io,
        _cache = LruCache<String, Document>(capacity: capacity);

  /// Global debounce delay before a changed document is flushed to disk.
  /// Shared by all [DocumentCache] instances; change it once to tune the app.
  static Duration saveDelay = const Duration(milliseconds: 300);

  final DocumentIo _io;
  final LruCache<String, Document> _cache;
  final Map<String, Timer> _pending = <String, Timer>{};

  /// Loads (and decodes) the document content for [nodeId] on demand.
  Future<Document> load(String nodeId) async {
    final cached = _cache.get(nodeId);
    if (cached != null) return cached;

    final contentJson = await _io.readContent(nodeId);
    if (contentJson == null) {
      throw StateError('document content not found: $nodeId');
    }
    final document = ContentCodec.decode(contentJson);
    _cache.put(nodeId, document);
    return document;
  }

  /// Stages [document] for [nodeId] in memory and schedules a debounced write.
  ///
  /// Repeated calls for the same node within [saveDelay] coalesce into one write.
  void save(String nodeId, Document document) {
    _cache.put(nodeId, document);
    _pending[nodeId]?.cancel();
    _pending[nodeId] = Timer(saveDelay, () => _flush(nodeId));
  }

  /// Writes any pending change for [nodeId] to disk immediately.
  Future<void> flush(String nodeId) async {
    _pending.remove(nodeId)?.cancel();
    await _write(nodeId);
  }

  /// Writes every pending change to disk immediately.
  Future<void> flushAll() async {
    for (final nodeId in _pending.keys.toList()) {
      await flush(nodeId);
    }
  }

  /// Drops a single document from the cache (cancelling any pending write).
  void invalidate(String nodeId) {
    _pending.remove(nodeId)?.cancel();
    _cache.remove(nodeId);
  }

  /// Drops every cached document and cancels every pending write.
  void clear() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _cache.clear();
  }

  Future<void> _flush(String nodeId) async {
    _pending.remove(nodeId);
    await _write(nodeId);
  }

  Future<void> _write(String nodeId) async {
    final document = _cache.get(nodeId);
    if (document == null) return;
    await _io.writeContent(nodeId, ContentCodec.encode(document));
  }

  int get length => _cache.length;

  bool get hasPendingWrites => _pending.isNotEmpty;

  void dispose() {
    final timers = _pending.values.toList();

    for (int index = 0; index < timers.length; index++) {
      timers[index].cancel();
    }

    timers.clear();
    _cache.clear();
    _pending.clear();
  }
}
