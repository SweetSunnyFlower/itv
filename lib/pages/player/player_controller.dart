import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/download_controller.dart';
import '../../app/services/storage_service.dart';

class PlayerController extends GetxController {
  late final Player player;
  late final VideoController videoController;
  final videoKey = GlobalKey();
  final _storage = StorageService();
  final hasError = false.obs;
  final errorMsg = ''.obs;
  final title = ''.obs;
  final currentEpIndex = 0.obs;
  final playbackSpeed = 1.0.obs;

  // 缓冲状态
  final isBuffering = true.obs;
  final bufferPercent = 0.obs;

  // 视频信息
  final videoWidth = 0.obs;
  final videoHeight = 0.obs;
  final videoBitrate = ''.obs;

  // 播放进度
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;

  late String url;
  late String vodName;
  late String vodRemarks;
  late String vodContent;
  late String vodDirector;
  late String vodActor;
  late String currentRoute;
  late List<PlayItem> episodes;
  late int vodId;
  late String siteUrl;
  StreamSubscription? _completedSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;
  Timer? _bitrateTimer;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

  @override
  void onInit() {
    super.onInit();
    url = Get.arguments['url'];
    vodName = Get.arguments['vod_name'] ?? '';
    vodId = Get.arguments['vod_id'] ?? 0;
    siteUrl = Get.arguments['site_url'] ?? '';
    vodRemarks = Get.arguments['vod_remarks'] ?? '';
    vodContent = Get.arguments['vod_content'] ?? '';
    vodDirector = Get.arguments['vod_director'] ?? '';
    vodActor = Get.arguments['vod_actor'] ?? '';
    currentRoute = Get.arguments['route_name'] ?? '';
    currentEpIndex.value = Get.arguments['ep_index'] ?? 0;

    // 反序列化 episodes
    final epList = Get.arguments['episodes'] as List<Map<String, String>>? ?? [];
    episodes = epList.map((e) => PlayItem(name: e['name'] ?? '', url: e['url'] ?? '')).toList();

    // 恢复上次播放进度
    _restoreProgress();

    title.value = Get.arguments['title'] ?? vodName;
    if (episodes.isNotEmpty) {
      final ep = episodes[currentEpIndex.value];
      title.value = '$vodName - ${ep.name}';
      url = _localPathOrUrl(ep);
    }

    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    // 允许加载 m3u8 播放列表中的外部 URL，自动重连
    final nativePlayer = player.platform as NativePlayer;
    nativePlayer.setProperty('demuxer-lavf-o', 'protocol_whitelist=[file,http,https,tcp,tls,crypto]');
    nativePlayer.setProperty('stream-lavf-o', 'reconnect=1');
    nativePlayer.setProperty('load-unsafe-playlists', 'yes');
    nativePlayer.setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
    nativePlayer.setProperty('tls-verify', 'no');
    nativePlayer.setProperty('network-timeout', '30');
    videoController = VideoController(player);

    player.stream.error.listen((error) {
      debugPrint('Player error: $error');
      // 忽略非致命错误
      final msg = error.toString().toLowerCase();
      if (msg.contains('audio device') ||
          msg.contains('ffurl_read') ||
          msg.contains('unsafe') ||
          msg.contains('playlist') ||
          msg.trim().isEmpty) {
        return;
      }
      hasError.value = true;
      errorMsg.value = error;
    });
    // 自动播放下一集
    _completedSub = player.stream.completed.listen((completed) {
      if (completed && episodes.length > 1) {
        final next = currentEpIndex.value + 1;
        if (next < episodes.length) {
          playEpisode(next);
        }
      }
    });
    // 定时记录播放进度
    _positionSub = player.stream.position.listen((pos) {
      _lastPosition = pos;
      _lastDuration = player.state.duration;
      position.value = pos;
      if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
        _saveProgress();
      }
    });
    _durationSub = player.stream.duration.listen((d) => duration.value = d);
    _bufferingSub = player.stream.buffering.listen((b) => isBuffering.value = b);
    _bufferSub = player.stream.buffer.listen((b) {
      final dur = player.state.duration.inMilliseconds;
      if (dur > 0) {
        bufferPercent.value = (b.inMilliseconds * 100 ~/ dur).clamp(0, 100);
      }
    });
    _widthSub = player.stream.width.listen((w) {
      if (w != null) videoWidth.value = w;
    });
    _heightSub = player.stream.height.listen((h) {
      if (h != null) videoHeight.value = h;
    });
    // 定时读取码率
    _bitrateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateBitrate();
    });
    // 恢复进度：等播放器就绪后 seek
    final savedPos = _getSavedPosition();
    player.open(Media(url));
    if (savedPos > Duration.zero) {
      player.stream.duration.firstWhere((d) => d > Duration.zero).then((_) {
        player.seek(savedPos);
      });
    }
  }

  void _restoreProgress() {
    if (vodId == 0) return;
    final progress = _storage.getProgress(vodId, siteUrl);
    if (progress == null) return;
    final savedEp = progress['ep_index'] as int? ?? 0;
    // 仅当从详情页"立即播放"(ep_index==0)进入时才恢复集数，手动选集时不覆盖
    final argEpIndex = Get.arguments['ep_index'] ?? 0;
    if (argEpIndex == 0 && savedEp < episodes.length) {
      currentEpIndex.value = savedEp;
    }
  }

  Duration _getSavedPosition() {
    if (vodId == 0) return Duration.zero;
    final progress = _storage.getProgress(vodId, siteUrl);
    if (progress == null) return Duration.zero;
    final savedEp = progress['ep_index'] as int? ?? 0;
    if (savedEp != currentEpIndex.value) return Duration.zero;
    final posSeconds = progress['position'] as int? ?? 0;
    final durSeconds = progress['duration'] as int? ?? 0;
    // 如果已播放超过95%，认为已看完，不恢复
    if (durSeconds > 0 && posSeconds > durSeconds * 0.95) return Duration.zero;
    return Duration(seconds: posSeconds);
  }

  void _saveProgress() {
    if (vodId == 0) return;
    _storage.saveProgress(vodId, siteUrl, {
      'ep_index': currentEpIndex.value,
      'position': _lastPosition.inSeconds,
      'duration': _lastDuration.inSeconds,
      'ep_name': episodes.isNotEmpty ? episodes[currentEpIndex.value].name : '',
      'vod_name': vodName,
    });
  }

  void playEpisode(int index) {
    if (index < 0 || index >= episodes.length) return;
    _saveProgress();
    currentEpIndex.value = index;
    final ep = episodes[index];
    title.value = '$vodName - ${ep.name}';
    hasError.value = false;
    player.open(Media(_localPathOrUrl(ep)));
  }

  String _localPathOrUrl(PlayItem ep) {
    try {
      final dlCtrl = Get.find<DownloadController>();
      final localPath = dlCtrl.getLocalPath(vodId, ep.name);
      if (localPath != null && File(localPath).existsSync()) return localPath;
    } catch (_) {}
    return ep.url;
  }

  /// 返回当前播放的远程 URL（投屏用，不返回本地路径）
  String getCurrentRemoteUrl() {
    if (episodes.isNotEmpty) {
      return episodes[currentEpIndex.value].url;
    }
    return url;
  }

  /// 截图并保存到相册目录
  Future<String?> takeScreenshot() async {
    try {
      final Uint8List? bytes = await player.screenshot();
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${dir.path}/screenshots');
      if (!screenshotDir.existsSync()) screenshotDir.createSync(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${screenshotDir.path}/screenshot_$timestamp.png');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Screenshot failed: $e');
      return null;
    }
  }

  void _updateBitrate() {
    try {
      final nativePlayer = player.platform as NativePlayer;
      nativePlayer.getProperty('video-bitrate').then((val) {
        final bps = double.tryParse(val) ?? 0;
        if (bps > 0) {
          final kbps = bps / 1000;
          if (kbps >= 1000) {
            videoBitrate.value = '${(kbps / 1000).toStringAsFixed(1)} Mbps';
          } else {
            videoBitrate.value = '${kbps.toStringAsFixed(0)} Kbps';
          }
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  /// 长按加速
  final isLongPressSpeed = false.obs;
  double _speedBeforeLongPress = 1.0;

  void startLongPressSpeed() {
    _speedBeforeLongPress = playbackSpeed.value;
    player.setRate(3.0);
    playbackSpeed.value = 3.0;
    isLongPressSpeed.value = true;
  }

  void stopLongPressSpeed() {
    player.setRate(_speedBeforeLongPress);
    playbackSpeed.value = _speedBeforeLongPress;
    isLongPressSpeed.value = false;
  }

  void setSpeed(double speed) {
    playbackSpeed.value = speed;
    player.setRate(speed);
  }

  @override
  void onClose() {
    _saveProgress();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _bufferSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _bitrateTimer?.cancel();
    player.dispose();
    super.onClose();
  }
}
