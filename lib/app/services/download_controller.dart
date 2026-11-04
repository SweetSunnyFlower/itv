import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_model.dart';

class DownloadController extends GetxController {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.plain,
  ));

  final _box = GetStorage();
  static const _storageKey = 'download_tasks';

  final tasks = <String, DownloadTask>{}.obs;
  final expandedGroups = <String>{}.obs;
  final _cancelTokens = <String, CancelToken>{};
  String _downloadDir = '';
  final _dirReady = Completer<void>();

  static const _maxConcurrent = 2;
  final _activeCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initDir();
    _loadTasks();
  }

  Future<void> _initDir() async {
    final dir = await getApplicationDocumentsDirectory();
    _downloadDir = '${dir.path}/downloads';
    await Directory(_downloadDir).create(recursive: true);
    debugPrint('[Download] dir ready: $_downloadDir');
    _dirReady.complete();
  }

  void _loadTasks() {
    final data = _box.read<List>(_storageKey);
    if (data != null) {
      for (final item in data) {
        final task = DownloadTask.fromJson(Map<String, dynamic>.from(item));
        if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging) {
          task.status = DownloadStatus.paused;
        }
        tasks[task.id] = task;
      }
    }
  }

  void _saveTasks() {
    _box.write(_storageKey, tasks.values.map((t) => t.toJson()).toList());
  }

  Future<void> addTask({
    required int vodId,
    required String vodName,
    required String vodPic,
    required String episodeName,
    required String url,
    required String siteUrl,
  }) async {
    final id = '${vodId}_${episodeName.hashCode}';
    if (tasks.containsKey(id)) {
      final existing = tasks[id]!;
      if (existing.status == DownloadStatus.completed) return;
      if (existing.status == DownloadStatus.downloading) return;
      resumeTask(id);
      return;
    }

    final task = DownloadTask(
      id: id,
      vodId: vodId,
      vodName: vodName,
      vodPic: vodPic,
      episodeName: episodeName,
      url: url,
      siteUrl: siteUrl,
    );
    tasks[id] = task;
    _saveTasks();
    _tryStartNext();
  }

  void _tryStartNext() {
    if (_activeCount.value >= _maxConcurrent) return;
    final pending = tasks.values.where((t) => t.status == DownloadStatus.pending).toList();
    if (pending.isEmpty) return;
    _startDownload(pending.first.id);
  }

  Future<void> _startDownload(String taskId) async {
    final task = tasks[taskId];
    if (task == null) return;

    // 先标记状态和计数，防止 await 让出执行权后被重复启动
    task.status = DownloadStatus.downloading;
    task.error = null;
    tasks.refresh();
    _saveTasks();
    _activeCount.value++;

    // 等待目录初始化完成
    await _dirReady.future;

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      debugPrint('[Download] start: ${task.episodeName} url=${task.url}');
      final url = task.url.toLowerCase();
      if (url.contains('.m3u8')) {
        await _downloadM3u8(task, cancelToken);
      } else {
        await _downloadDirect(task, cancelToken);
      }

      if (!cancelToken.isCancelled) {
        // 验证文件大小
        final file = File(task.savePath);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('[Download] done: ${task.episodeName} size=${(size / 1024 / 1024).toStringAsFixed(1)}MB');
          if (size < 1024) {
            throw Exception('下载文件过小(${size}B)，可能不是有效视频');
          }
        }
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        tasks.refresh();
        _saveTasks();
      }
    } catch (e) {
      debugPrint('[Download] error: ${task.episodeName} $e');
      if (!cancelToken.isCancelled) {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
        tasks.refresh();
        _saveTasks();
      }
    } finally {
      _cancelTokens.remove(taskId);
      _activeCount.value--;
      _tryStartNext();
    }
  }

  /// 直接下载 mp4 等文件
  Future<void> _downloadDirect(DownloadTask task, CancelToken cancelToken) async {
    final savePath = '$_downloadDir/${task.id}.mp4';
    await _dio.download(
      task.url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          task.progress = received / total;
          tasks.refresh();
        }
      },
    );
    task.savePath = savePath;
  }

  /// 下载 m3u8 视频
  Future<void> _downloadM3u8(DownloadTask task, CancelToken cancelToken) async {
    // 1. 获取 m3u8 内容
    String m3u8Url = task.url;
    final response = await _dio.get(m3u8Url, cancelToken: cancelToken);
    String content = response.data.toString();
    debugPrint('[Download] m3u8 content(${content.length}chars): ${content.substring(0, content.length.clamp(0, 300))}');

    // 2. 处理 master playlist（多码率索引），取最高码率的子 m3u8
    if (content.contains('#EXT-X-STREAM-INF')) {
      debugPrint('[Download] detected master playlist, resolving child m3u8...');
      m3u8Url = _resolveMasterPlaylist(m3u8Url, content);
      debugPrint('[Download] child m3u8: $m3u8Url');
      final childResponse = await _dio.get(m3u8Url, cancelToken: cancelToken);
      content = childResponse.data.toString();
    }

    // 3. 解析 ts 分片 URL
    final segments = _parseM3u8Segments(m3u8Url, content);
    debugPrint('[Download] parsed ${segments.length} segments');
    if (segments.isEmpty) throw Exception('无法解析m3u8分片');

    task.totalSegments = segments.length;
    task.downloadedSegments = 0;
    tasks.refresh();

    // 4. 创建临时目录
    final tempDir = '$_downloadDir/temp_${task.id}';
    await Directory(tempDir).create(recursive: true);

    // 5. 并发下载所有分片（10路并发）
    const maxConcurrentSegs = 10;
    var nextIndex = 0;

    Future<void> downloadSeg(int segIndex) async {
      final segUrl = segments[segIndex];
      final segPath = '$tempDir/seg_$segIndex.ts';

      final segFile = File(segPath);
      if (await segFile.exists() && await segFile.length() > 0) {
        task.downloadedSegments++;
        task.progress = task.downloadedSegments / task.totalSegments * 0.95;
        tasks.refresh();
        return;
      }

      for (var retry = 0; retry < 3; retry++) {
        if (cancelToken.isCancelled) return;
        try {
          await _dio.download(segUrl, segPath, cancelToken: cancelToken);
          break;
        } catch (e) {
          if (retry == 2) rethrow;
        }
      }

      task.downloadedSegments++;
      task.progress = task.downloadedSegments / task.totalSegments * 0.95;
      tasks.refresh();
      if (task.downloadedSegments % 20 == 0) _saveTasks();
    }

    // 启动并发池
    Future<void> worker() async {
      while (true) {
        if (cancelToken.isCancelled) return;
        final idx = nextIndex++;
        if (idx >= segments.length) return;
        await downloadSeg(idx);
      }
    }

    final workers = List.generate(
      maxConcurrentSegs.clamp(1, segments.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    if (cancelToken.isCancelled) return;

    // 6. 合并分片
    debugPrint('[Download] merging ${segments.length} segments...');
    task.status = DownloadStatus.merging;
    tasks.refresh();

    final savePath = '$_downloadDir/${task.id}.ts';
    final outFile = File(savePath);
    final sink = outFile.openWrite();
    for (var i = 0; i < segments.length; i++) {
      final segFile = File('$tempDir/seg_$i.ts');
      if (await segFile.exists()) {
        sink.add(await segFile.readAsBytes());
      }
    }
    await sink.flush();
    await sink.close();

    task.progress = 1.0;
    task.savePath = savePath;

    final fileSize = await outFile.length();
    debugPrint('[Download] merged file: ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB');

    // 7. 清理临时文件
    try {
      await Directory(tempDir).delete(recursive: true);
    } catch (_) {}
  }

  /// 从 master playlist 中解析出最高码率的子 m3u8 URL
  String _resolveMasterPlaylist(String masterUrl, String content) {
    final baseUrl = masterUrl.substring(0, masterUrl.lastIndexOf('/') + 1);
    final lines = content.split('\n');
    String? bestUrl;
    int bestBandwidth = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        // 解析 BANDWIDTH
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        final bandwidth = bwMatch != null ? int.tryParse(bwMatch.group(1)!) ?? 0 : 0;

        // 下一行是子 m3u8 URL
        if (i + 1 < lines.length) {
          final childLine = lines[i + 1].trim();
          if (childLine.isNotEmpty && !childLine.startsWith('#')) {
            final childUrl = _resolveUrl(masterUrl, baseUrl, childLine);
            if (bandwidth >= bestBandwidth) {
              bestBandwidth = bandwidth;
              bestUrl = childUrl;
            }
          }
        }
      }
    }

    if (bestUrl == null) throw Exception('无法解析master playlist');
    return bestUrl;
  }

  /// 解析 m3u8 内容，提取 ts 分片完整 URL
  List<String> _parseM3u8Segments(String m3u8Url, String content) {
    final baseUrl = m3u8Url.substring(0, m3u8Url.lastIndexOf('/') + 1);
    final lines = content.split('\n');
    final segments = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      // 过滤掉子 m3u8（不是 .ts 分片）
      if (trimmed.contains('.m3u8')) continue;

      segments.add(_resolveUrl(m3u8Url, baseUrl, trimmed));
    }

    return segments;
  }

  /// 将相对/绝对路径转为完整 URL
  String _resolveUrl(String contextUrl, String baseUrl, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    } else if (path.startsWith('/')) {
      final uri = Uri.parse(contextUrl);
      return '${uri.scheme}://${uri.host}$path';
    } else {
      return '$baseUrl$path';
    }
  }

  void pauseTask(String taskId) {
    final task = tasks[taskId];
    if (task == null) return;
    _cancelTokens[taskId]?.cancel();
    _cancelTokens.remove(taskId);
    task.status = DownloadStatus.paused;
    tasks.refresh();
    _saveTasks();
  }

  void resumeTask(String taskId) {
    final task = tasks[taskId];
    if (task == null) return;
    task.status = DownloadStatus.pending;
    tasks.refresh();
    _saveTasks();
    _tryStartNext();
  }

  Future<void> deleteTask(String taskId) async {
    _cancelTokens[taskId]?.cancel();
    _cancelTokens.remove(taskId);
    final task = tasks[taskId];
    if (task != null) {
      if (task.savePath.isNotEmpty) {
        try { await File(task.savePath).delete(); } catch (_) {}
      }
      try {
        await Directory('$_downloadDir/temp_${task.id}').delete(recursive: true);
      } catch (_) {}
    }
    tasks.remove(taskId);
    _saveTasks();
  }

  DownloadStatus? getTaskStatus(int vodId, String episodeName) {
    final id = '${vodId}_${episodeName.hashCode}';
    return tasks[id]?.status;
  }

  String? getLocalPath(int vodId, String episodeName) {
    final id = '${vodId}_${episodeName.hashCode}';
    final task = tasks[id];
    if (task != null && task.status == DownloadStatus.completed && task.savePath.isNotEmpty) {
      return task.savePath;
    }
    return null;
  }

  Map<String, List<DownloadTask>> get groupedTasks {
    final map = <String, List<DownloadTask>>{};
    for (final task in tasks.values) {
      final key = '${task.vodId}_${task.siteUrl}';
      map.putIfAbsent(key, () => []).add(task);
    }
    return map;
  }

  @override
  void onClose() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    super.onClose();
  }
}
