import 'dart:async';

import 'package:flutter/services.dart';

import '../models.dart';

class YtDlpBridge {
  const YtDlpBridge();

  static const _methods = MethodChannel('download_video_app/media');
  static const _shares = EventChannel('download_video_app/share');

  Stream<String> get sharedUrls => _shares
      .receiveBroadcastStream()
      .where((event) => event is String && event.trim().isNotEmpty)
      .cast<String>();

  Future<MediaInfo> inspect(String url) async {
    final result = await _methods.invokeMapMethod<Object?, Object?>(
      'inspectMedia',
      {'url': url},
    );
    if (result == null) {
      throw StateError('The media extractor returned no metadata.');
    }
    return MediaInfo.fromMap(result);
  }

  Future<String> enqueue({
    required String url,
    required String title,
    required String formatSelector,
    required String formatLabel,
    required bool wifiOnly,
    required bool useAria2,
    required bool playlist,
    String? audioFormat,
  }) async {
    final id = await _methods.invokeMethod<String>('enqueueMedia', {
      'url': url,
      'title': title,
      'formatSelector': formatSelector,
      'formatLabel': formatLabel,
      'wifiOnly': wifiOnly,
      'useAria2': useAria2,
      'playlist': playlist,
      'audioFormat': audioFormat,
    });
    if (id == null || id.isEmpty) {
      throw StateError('The media download could not be queued.');
    }
    return id;
  }

  Future<List<Map<Object?, Object?>>> jobStates(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final result = await _methods.invokeListMethod<Object?>('mediaJobStates', {
      'ids': ids,
    });
    if (result == null) return const [];
    return result.whereType<Map>().map((e) => e.cast<Object?, Object?>()).toList();
  }

  Future<bool> cancel(String id) async =>
      await _methods.invokeMethod<bool>('cancelMedia', {'id': id}) ?? false;

  Future<bool> openPath(String path) async =>
      await _methods.invokeMethod<bool>('openPath', {'path': path}) ?? false;

  Future<bool> sharePath(String path) async =>
      await _methods.invokeMethod<bool>('sharePath', {'path': path}) ?? false;

  Future<String> updateEngine() async =>
      await _methods.invokeMethod<String>('updateMediaEngine') ?? 'No update result';
}
