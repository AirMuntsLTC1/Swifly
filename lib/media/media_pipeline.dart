import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import 'media_item.dart';

// This file only calls C++ (cpp/media_bridge.cpp). C++ runs the PHP scripts in
// cpp/php/ that do the real work: reading, resizing, thumbnails and the local cache.

typedef _InitNative = Int32 Function(Pointer<Utf8> workDir);
typedef _InitDart = int Function(Pointer<Utf8> workDir);

typedef _RunNative = Int32 Function(Pointer<Utf8> op, Pointer<Utf8> src, Pointer<Utf8> hint,
    Pointer<Utf8> out, Int32 outLen);
typedef _RunDart = int Function(
    Pointer<Utf8> op, Pointer<Utf8> src, Pointer<Utf8> hint, Pointer<Utf8> out, int outLen);

const int _outLen = 8192;

/// Runs in a background isolate so the screen never freezes while PHP works.
int _initNative(String workDir) {
  final lib = DynamicLibrary.open('libswifly_core.so');
  final init = lib.lookupFunction<_InitNative, _InitDart>('swifly_media_init');
  final dir = workDir.toNativeUtf8();
  try {
    return init(dir);
  } finally {
    calloc.free(dir);
  }
}

String _runNative(String op, String src, String hint) {
  try {
    final lib = DynamicLibrary.open('libswifly_core.so');
    final run = lib.lookupFunction<_RunNative, _RunDart>('swifly_media_run');
    final o = op.toNativeUtf8();
    final s = src.toNativeUtf8();
    final h = hint.toNativeUtf8();
    final out = calloc<Uint8>(_outLen).cast<Utf8>();
    try {
      run(o, s, h, out, _outLen);
      return out.toDartString();
    } finally {
      calloc.free(o);
      calloc.free(s);
      calloc.free(h);
      calloc.free(out);
    }
  } catch (e) {
    return jsonEncode({'ok': false, 'error': '$e'});
  }
}

class MediaPipeline {
  MediaPipeline._();
  static final MediaPipeline instance = MediaPipeline._();

  Future<bool>? _ready;
  bool _phpRuntime = false;

  /// True when the PHP runtime is running the scripts. False means the small C++
  /// fallback is used (files are cached, but no resizing and no video thumbnails).
  bool get phpRuntimeActive => _phpRuntime;

  /// Prepares the PHP scripts and the cache folder once. Safe to call many times.
  Future<bool> ensureReady() => _ready ??= _init();

  Future<bool> _init() async {
    if (!Platform.isAndroid) return false;
    try {
      final base = await getApplicationSupportDirectory();
      final work = '${base.path}/swifly_media';
      final result = await Isolate.run(() => _initNative(work));
      _phpRuntime = result == 1;
      return result >= 0;
    } catch (_) {
      return false;
    }
  }

  /// Sends one photo or video through the PHP pipeline and returns the cached result.
  /// The same file is never processed twice (PHP checks its local cache first).
  /// If the native side is missing, the original file is returned unchanged.
  Future<MediaItem> process(
    String srcPath, {
    required MediaKind kind,
    String? hintThumb,
  }) async {
    final fallback = MediaItem(kind: kind, path: srcPath, thumbPath: hintThumb);
    if (!await ensureReady()) return fallback;
    try {
      final raw = await Isolate.run(() => _runNative('process', srcPath, hintThumb ?? ''));
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['ok'] != true) return fallback;
      return MediaItem.fromResult(json, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  /// Removes the oldest cached items when the cache is over its size limit.
  Future<void> trimCache() async {
    if (!await ensureReady()) return;
    try {
      await Isolate.run(() => _runNative('evict', '', ''));
    } catch (_) {}
  }
}
