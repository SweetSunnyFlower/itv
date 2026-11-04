import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/download_controller.dart';
import '../../app/services/storage_service.dart';
import '../../utils/tv_detector.dart';
import '../../widgets/tv_focusable.dart';

class ShortDramaPage extends StatefulWidget {
  const ShortDramaPage({super.key});

  @override
  State<ShortDramaPage> createState() => _ShortDramaPageState();
}

class _ShortDramaPageState extends State<ShortDramaPage> {
  // 播放器池：1 当前 + 4 预加载
  static const _poolSize = 5;
  static const _preloadAhead = 4;

  final List<Player> _players = [];
  final List<VideoController> _vcs = [];
  // 每个池槽位加载的集数索引，-1 表示空
  final List<int> _slotEpIndex = List.filled(_poolSize, -1);

  late final PageController pageController;
  final _storage = StorageService();

  late String vodName;
  late int vodId;
  late String siteUrl;
  late List<PlayItem> episodes;
  int currentIndex = 0;
  bool showOverlay = true;
  bool isBuffering = true;
  int bufferPercent = 0;
  double playbackSpeed = 1.0;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  List<StreamSubscription> _subs = [];
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

  static const _speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

  /// 查找加载了指定集数的槽位
  int? _findSlot(int epIndex) {
    for (int i = 0; i < _poolSize; i++) {
      if (_slotEpIndex[i] == epIndex) return i;
    }
    return null;
  }

  /// 当前播放的槽位
  int get _currentSlot => _findSlot(currentIndex)!;
  Player get _currentPlayer => _players[_currentSlot];

  /// 找到一个可回收的槽位（离当前集最远的、且不在 [currentIndex, currentIndex+_preloadAhead] 范围内的）
  int _findRecyclableSlot(int newCurrentIndex) {
    int bestSlot = 0;
    int bestDist = -1;
    for (int i = 0; i < _poolSize; i++) {
      final ep = _slotEpIndex[i];
      if (ep == -1) return i; // 空槽直接用
      // 不回收正在播放和即将播放的集
      if (ep >= newCurrentIndex && ep <= newCurrentIndex + _preloadAhead) continue;
      final dist = (ep - newCurrentIndex).abs();
      if (dist > bestDist) {
        bestDist = dist;
        bestSlot = i;
      }
    }
    return bestSlot;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final args = Get.arguments as Map<String, dynamic>;
    vodName = args['vod_name'] ?? '';
    vodId = args['vod_id'] ?? 0;
    siteUrl = args['site_url'] ?? '';
    currentIndex = args['ep_index'] ?? 0;

    final epList = args['episodes'] as List<Map<String, String>>? ?? [];
    episodes = epList.map((e) => PlayItem(name: e['name'] ?? '', url: e['url'] ?? '')).toList();

    _restoreProgress();

    // 创建播放器池
    for (int i = 0; i < _poolSize; i++) {
      final p = _createPlayer();
      _players.add(p);
      _vcs.add(VideoController(p));
    }

    pageController = PageController(initialPage: currentIndex);

    // 加载当前集到第一个槽位
    _loadToSlot(0, currentIndex, play: true);

    // 恢复进度
    final savedPos = _getSavedPosition();
    if (savedPos > Duration.zero) {
      _players[0].stream.duration.firstWhere((d) => d > Duration.zero).then((_) {
        _players[0].seek(savedPos);
      });
    }

    // 预加载后续集数
    _preloadAround(currentIndex);

    // 监听当前播放器
    _subscribePlayer(_currentSlot);
  }

  Player _createPlayer() {
    final p = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    final np = p.platform as NativePlayer;
    np.setProperty('demuxer-lavf-o', 'protocol_whitelist=[file,http,https,tcp,tls,crypto]');
    np.setProperty('stream-lavf-o', 'reconnect=1');
    np.setProperty('load-unsafe-playlists', 'yes');
    np.setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
    np.setProperty('tls-verify', 'no');
    np.setProperty('network-timeout', '30');
    return p;
  }

  /// 加载指定集数到指定槽位
  void _loadToSlot(int slot, int epIndex, {bool play = false}) {
    if (epIndex < 0 || epIndex >= episodes.length) return;
    final url = _localPathOrUrl(episodes[epIndex]);
    _slotEpIndex[slot] = epIndex;
    if (play) {
      _players[slot].setVolume(100);
      _players[slot].open(Media(url));
    } else {
      _players[slot].setVolume(0);
      _players[slot].open(Media(url), play: false);
    }
  }

  /// 预加载当前集后面的 _preloadAhead 集
  void _preloadAround(int center) {
    for (int offset = 1; offset <= _preloadAhead; offset++) {
      final epIdx = center + offset;
      if (epIdx >= episodes.length) break;
      // 已经加载过则跳过
      if (_findSlot(epIdx) != null) continue;
      final slot = _findRecyclableSlot(center);
      _loadToSlot(slot, epIdx, play: false);
    }
  }

  void _subscribePlayer(int slot) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs = [];

    final p = _players[slot];

    // 立即获取当前状态
    setState(() {
      position = p.state.position;
      duration = p.state.duration;
    });

    _subs.add(p.stream.position.listen((pos) {
      _lastPosition = pos;
      _lastDuration = p.state.duration;
      if (mounted) setState(() => position = pos);
      if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0) _saveProgress();
    }));
    _subs.add(p.stream.duration.listen((d) {
      if (mounted && d > Duration.zero) setState(() => duration = d);
    }));
    _subs.add(p.stream.buffering.listen((b) {
      if (mounted) setState(() => isBuffering = b);
    }));
    _subs.add(p.stream.buffer.listen((b) {
      final dur = p.state.duration.inMilliseconds;
      if (dur > 0 && mounted) {
        setState(() => bufferPercent = (b.inMilliseconds * 100 ~/ dur).clamp(0, 100));
      }
    }));
    _subs.add(p.stream.completed.listen((completed) {
      if (completed && currentIndex < episodes.length - 1) {
        _goToEpisode(currentIndex + 1);
      }
    }));
  }

  void _restoreProgress() {
    if (vodId == 0) return;
    final progress = _storage.getProgress(vodId, siteUrl);
    if (progress == null) return;
    final savedEp = progress['ep_index'] as int? ?? 0;
    final argEpIndex = Get.arguments['ep_index'] ?? 0;
    if (argEpIndex == 0 && savedEp < episodes.length) {
      currentIndex = savedEp;
    }
  }

  Duration _getSavedPosition() {
    if (vodId == 0) return Duration.zero;
    final progress = _storage.getProgress(vodId, siteUrl);
    if (progress == null) return Duration.zero;
    final savedEp = progress['ep_index'] as int? ?? 0;
    if (savedEp != currentIndex) return Duration.zero;
    final posSeconds = progress['position'] as int? ?? 0;
    final durSeconds = progress['duration'] as int? ?? 0;
    if (durSeconds > 0 && posSeconds > durSeconds * 0.95) return Duration.zero;
    return Duration(seconds: posSeconds);
  }

  void _saveProgress() {
    if (vodId == 0) return;
    _storage.saveProgress(vodId, siteUrl, {
      'ep_index': currentIndex,
      'position': _lastPosition.inSeconds,
      'duration': _lastDuration.inSeconds,
      'ep_name': episodes.isNotEmpty ? episodes[currentIndex].name : '',
      'vod_name': vodName,
    });
  }

  String _localPathOrUrl(PlayItem ep) {
    try {
      final dlCtrl = Get.find<DownloadController>();
      final localPath = dlCtrl.getLocalPath(vodId, ep.name);
      if (localPath != null && File(localPath).existsSync()) return localPath;
    } catch (_) {}
    return ep.url;
  }

  void _onPageChanged(int index) {
    if (index == currentIndex) return;
    _saveProgress();

    final nextSlot = _findSlot(index);
    if (nextSlot != null) {
      // 目标集已预加载 — 直接播放，丝滑切换
      _players[nextSlot].setVolume(100);
      _players[nextSlot].play();
      // 停止旧播放器
      _players[_currentSlot].pause();
    } else {
      // 目标集未预加载（跳集或向上滑太远）— 回收一个槽位加载
      final slot = _findRecyclableSlot(index);
      _loadToSlot(slot, index, play: true);
    }

    // 重置 UI 状态
    isBuffering = true;
    bufferPercent = 0;
    setState(() => currentIndex = index);

    // 重新订阅新的当前播放器（会更新 position 和 duration）
    _subscribePlayer(_currentSlot);

    // 预加载新窗口内的集数
    _preloadAround(index);

    if (playbackSpeed != 1.0) {
      _currentPlayer.setRate(playbackSpeed);
    }
  }

  void _goToEpisode(int index) {
    if (index < 0 || index >= episodes.length) return;
    pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _saveProgress();
    for (final s in _subs) {
      s.cancel();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final p in _players) {
      p.dispose();
    }
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: isAndroidTV,
          onKeyEvent: (node, event) {
            if (!isAndroidTV || event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowUp) {
              if (currentIndex > 0) _goToEpisode(currentIndex - 1);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowDown) {
              if (currentIndex < episodes.length - 1) _goToEpisode(currentIndex + 1);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowLeft) {
              final target = position - const Duration(seconds: 10);
              _currentPlayer.seek(target < Duration.zero ? Duration.zero : target);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowRight) {
              _currentPlayer.seek(position + const Duration(seconds: 10));
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.select ||
                       key == LogicalKeyboardKey.enter ||
                       key == LogicalKeyboardKey.space) {
              _currentPlayer.playOrPause();
              setState(() {});
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
          children: [
            // 视频 PageView（上下滑动切集）
            PageView.builder(
              controller: pageController,
              scrollDirection: Axis.vertical,
              itemCount: episodes.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final slot = _findSlot(index);
                if (slot != null) {
                  // 已加载（当前或预加载）— 显示视频
                  return Video(
                    controller: _vcs[slot],
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  );
                }
                // 未加载 — 占位
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          episodes[index].name,
                          style: const TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 缓冲指示器
            if (isBuffering)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black38,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE50914)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              bufferPercent > 0 ? '缓冲 $bufferPercent%' : '加载中...',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 点击区域
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => showOverlay = !showOverlay),
                onDoubleTapDown: isAndroidTV ? null : (details) {
                  final w = MediaQuery.of(context).size.width;
                  final x = details.localPosition.dx;
                  if (x < w / 3) {
                    final target = position - const Duration(seconds: 10);
                    _currentPlayer.seek(target < Duration.zero ? Duration.zero : target);
                  } else if (x > w * 2 / 3) {
                    _currentPlayer.seek(position + const Duration(seconds: 10));
                  } else {
                    _currentPlayer.playOrPause();
                  }
                },
                onDoubleTap: isAndroidTV ? null : () {},
                child: const SizedBox.expand(),
              ),
            ),
            // 顶部 overlay
            if (showOverlay)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        onPressed: () => Get.back(),
                      ),
                      Expanded(
                        child: Text(
                          '$vodName - ${episodes[currentIndex].name}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildSpeedButton(),
                    ],
                  ),
                ),
              ),
            // 右侧操作
            if (showOverlay)
              Positioned(
                right: 8,
                bottom: MediaQuery.of(context).padding.bottom + 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sideButton(Icons.playlist_play, '选集', () => _showEpisodeSheet()),
                    const SizedBox(height: 20),
                    _sideButton(
                      _currentPlayer.state.playing ? Icons.pause : Icons.play_arrow,
                      _currentPlayer.state.playing ? '暂停' : '播放',
                      () {
                        _currentPlayer.playOrPause();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            // 底部进度条
            Positioned(
              left: 0, right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showOverlay && episodes.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${currentIndex + 1} / ${episodes.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 2,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Color(0xFFE50914),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Color(0xFFE50914),
                        overlayColor: Color(0x44E50914),
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                            : 0,
                        min: 0,
                        max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                        onChanged: (v) => _currentPlayer.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                  ),
                  if (showOverlay)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 右侧滑动提示
            if (showOverlay && episodes.length > 1)
              Positioned(
                right: 4,
                top: 0, bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentIndex > 0)
                        const Icon(Icons.keyboard_arrow_up, color: Colors.white24, size: 18),
                      const Text('滑动\n切集', style: TextStyle(color: Colors.white24, fontSize: 9, height: 1.4), textAlign: TextAlign.center),
                      if (currentIndex < episodes.length - 1)
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white24, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _sideButton(IconData icon, String label, VoidCallback onTap) {
    return TVFocusable(
      onSelect: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSpeedButton() {
    final label = playbackSpeed == 1.0 ? '倍速' : '${playbackSpeed}x';
    return PopupMenuButton<double>(
      onSelected: (s) {
        setState(() => playbackSpeed = s);
        _currentPlayer.setRate(s);
      },
      color: const Color(0xFF2A2A2A),
      itemBuilder: (_) => _speeds.map((s) => PopupMenuItem(
        value: s,
        child: Text(
          s == 1.0 ? '正常' : '${s}x',
          style: TextStyle(
            color: s == playbackSpeed ? const Color(0xFFE50914) : Colors.white70,
            fontSize: 13,
            fontWeight: s == playbackSpeed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      )).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label, style: TextStyle(color: playbackSpeed == 1.0 ? Colors.white70 : const Color(0xFFE50914), fontSize: 13)),
      ),
    );
  }

  void _showEpisodeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.75,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    const Text('选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('共${episodes.length}集', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const Spacer(),
                    TVFocusable(
                      onSelect: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Colors.white38, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: episodes.length,
                  itemBuilder: (_, index) {
                    final ep = episodes[index];
                    final isPlaying = currentIndex == index;
                    return TVFocusable(
                      onSelect: () {
                        Navigator.pop(ctx);
                        _goToEpisode(index);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPlaying ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ep.name,
                          style: TextStyle(
                            color: isPlaying ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
