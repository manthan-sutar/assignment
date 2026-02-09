import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/reel_entity.dart';

/// Downloads and caches reel audio in the background (Instagram-style).
/// Prefetches a window around the current index so playback starts instantly.
class ReelAudioCache {
  ReelAudioCache({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  Directory? _cacheDir;
  static const _prefetchAhead = 3;
  static const _maxConcurrent = 2;
  int _activeDownloads = 0;
  final List<String> _downloadQueue = [];

  Future<Directory> _getCacheDir() async {
    _cacheDir ??= await getTemporaryDirectory();
    final dir = Directory('${_cacheDir!.path}/reel_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _keyFromUrl(String url) {
    final safe = base64UrlEncode(utf8.encode(url))
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll('=', '');
    return safe.length > 80 ? safe.substring(0, 80) : safe;
  }

  /// Returns cached file path if available, otherwise the original [url].
  Future<String> getSource(String url) async {
    if (url.isEmpty) return url;
    try {
      final dir = await _getCacheDir();
      final key = _keyFromUrl(url);
      final file = File('${dir.path}/$key');
      if (await file.exists()) return file.uri.toString();
    } catch (e) {
      debugPrint('ReelAudioCache getSource error: $e');
    }
    return url;
  }

  /// Prefetches audio for reels around [currentIndex]. Call when feed loads or index changes.
  void prefetchAround(int currentIndex, List<ReelEntity> reels) {
    if (reels.isEmpty) return;
    final urls = <String>{};
    for (var i = currentIndex;
        i < reels.length && i < currentIndex + _prefetchAhead + 1;
        i++) {
      final url = reels[i].audioUrl;
      if (url.isNotEmpty) urls.add(url);
    }
    for (var i = currentIndex - 1; i >= 0 && i >= currentIndex - 2; i--) {
      final url = reels[i].audioUrl;
      if (url.isNotEmpty) urls.add(url);
    }
    for (final url in urls) _enqueueDownload(url);
  }

  void _enqueueDownload(String url) {
    if (_downloadQueue.contains(url)) return;
    _downloadQueue.add(url);
    _drainQueue();
  }

  Future<void> _drainQueue() async {
    while (_activeDownloads < _maxConcurrent && _downloadQueue.isNotEmpty) {
      final url = _downloadQueue.removeAt(0);
      _activeDownloads++;
      _download(url).whenComplete(() {
        _activeDownloads--;
        _drainQueue();
      });
    }
  }

  Future<void> _download(String url) async {
    try {
      final dir = await _getCacheDir();
      final key = _keyFromUrl(url);
      final file = File('${dir.path}/$key');
      if (await file.exists()) return;
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data!.isNotEmpty) {
        await file.writeAsBytes(response.data!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ReelAudioCache download error: $e');
    }
  }
}
