import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/models/live_channel.dart';
import '../../app/services/m3u_parser_service.dart';
import '../../app/services/storage_service.dart';

class LivePlayerPage extends StatefulWidget {
  final LiveChannel channel;
  final String? m3uUrl;

  const LivePlayerPage({super.key, required this.channel, this.m3uUrl});

  @override
  State<LivePlayerPage> createState() => _LivePlayerPageState();
}

class _LivePlayerPageState extends State<LivePlayerPage> {
  late final Player player;
  late final VideoController videoController;
  final _storage = StorageService();

  final RxBool isPlaying = false.obs;
  final RxBool showControls = true.obs;
  final RxBool isFullscreen = false.obs;
  final RxBool isFavorite = false.obs;

  // 频道列表
  List<LiveChannel> allChannels = [];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    isFavorite.value = _storage.isLiveFavorite(widget.channel.url);
    _initPlayer();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    if (widget.m3uUrl == null) return;

    try {
      allChannels = await LiveSourceService.fetchChannels(widget.m3uUrl!);
      currentIndex = allChannels.indexWhere((c) => c.url == widget.channel.url);
      if (currentIndex < 0) currentIndex = 0;
      setState(() {});
    } catch (e) {
      debugPrint('加载频道列表失败: $e');
    }
  }

  void _initPlayer() {
    player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );

    // Web 平台不支持 NativePlayer.setProperty
    if (!kIsWeb) {
      final nativePlayer = player.platform as NativePlayer;
      nativePlayer.setProperty('demuxer-lavf-o', 'protocol_whitelist=[file,http,https,tcp,tls,crypto]');
      nativePlayer.setProperty('stream-lavf-o', 'reconnect=1');
      nativePlayer.setProperty('load-unsafe-playlists', 'yes');
    }

    videoController = VideoController(player);

    // 播放频道
    player.open(Media(widget.channel.url));

    // 监听播放状态
    player.stream.playing.listen((playing) {
      isPlaying.value = playing;
    });
  }

  void playChannel(LiveChannel channel) {
    player.open(Media(channel.url));
  }

  void _toggleControls() {
    showControls.value = !showControls.value;
  }

  void _togglePlay() {
    player.playOrPause();
  }

  void _playPrevious() {
    if (currentIndex > 0) {
      currentIndex--;
      final channel = allChannels[currentIndex];
      playChannel(channel);
      isFavorite.value = _storage.isLiveFavorite(channel.url);
      setState(() {});
    }
  }

  void _playNext() {
    if (currentIndex < allChannels.length - 1) {
      currentIndex++;
      final channel = allChannels[currentIndex];
      playChannel(channel);
      isFavorite.value = _storage.isLiveFavorite(channel.url);
      setState(() {});
    }
  }

  void _toggleFullscreen() {
    isFullscreen.value = !isFullscreen.value;
    if (isFullscreen.value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _toggleFavorite() {
    final currentChannel = allChannels.isNotEmpty ? allChannels[currentIndex] : widget.channel;
    if (isFavorite.value) {
      _storage.removeLiveFavorite(currentChannel.url);
      isFavorite.value = false;
      Get.snackbar(
        '',
        '已取消收藏',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        colorText: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: 20,
        duration: const Duration(seconds: 1),
        titleText: const SizedBox.shrink(),
      );
    } else {
      _storage.saveLiveFavorite(currentChannel.toJson());
      isFavorite.value = true;
      Get.snackbar(
        '',
        '收藏成功',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        colorText: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderRadius: 20,
        duration: const Duration(seconds: 1),
        titleText: const SizedBox.shrink(),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChannel = allChannels.isNotEmpty ? allChannels[currentIndex] : widget.channel;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 视频播放器
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: videoController),
            ),
          ),

          // 控制层
          Obx(() => GestureDetector(
            onTap: _toggleControls,
            child: AnimatedOpacity(
              opacity: showControls.value ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    // 顶部控制栏
                    _buildTopBar(currentChannel),

                    // 中间控制
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 上一个
                          IconButton(
                            onPressed: currentIndex > 0 ? _playPrevious : null,
                            icon: Icon(
                              Icons.skip_previous,
                              color: currentIndex > 0 ? Colors.white : Colors.white24,
                              size: 36,
                            ),
                          ),

                          // 播放/暂停
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                isPlaying.value ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          // 下一个
                          IconButton(
                            onPressed: currentIndex < allChannels.length - 1 ? _playNext : null,
                            icon: Icon(
                              Icons.skip_next,
                              color: currentIndex < allChannels.length - 1 ? Colors.white : Colors.white24,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 底部信息
                    _buildBottomBar(currentChannel),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTopBar(LiveChannel channel) {
    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    channel.group,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
            // 收藏按钮
            Obx(() => IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                isFavorite.value ? Icons.favorite : Icons.favorite_border,
                color: isFavorite.value ? const Color(0xFFE50914) : Colors.white,
              ),
            )),
            IconButton(
              onPressed: () => _showChannelList(),
              icon: const Icon(Icons.list, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(LiveChannel channel) {
    return SafeArea(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // 频道 Logo
            if (channel.logo.isNotEmpty)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: channel.logo,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) =>
                        Icon(Icons.live_tv, color: Colors.white.withValues(alpha: 0.5), size: 20),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            // LIVE 标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            // 频道序号
            if (allChannels.isNotEmpty)
              Text(
                '${currentIndex + 1}/${allChannels.length}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            const SizedBox(width: 12),
            // 全屏按钮
            IconButton(
              onPressed: _toggleFullscreen,
              icon: Icon(
                isFullscreen.value ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '频道列表',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('关闭', style: TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                // 列表
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: allChannels.length,
                    itemBuilder: (context, index) {
                      final channel = allChannels[index];
                      final isCurrent = index == currentIndex;

                      return Container(
                        color: isCurrent ? const Color(0xFFE50914).withValues(alpha: 0.2) : null,
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: channel.logo.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: channel.logo,
                                      fit: BoxFit.contain,
                                      errorWidget: (context, url, error) =>
                                          Icon(Icons.live_tv, color: Colors.white.withValues(alpha: 0.4)),
                                    ),
                                  )
                                : Icon(Icons.live_tv, color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          title: Text(
                            channel.name,
                            style: TextStyle(
                              color: isCurrent ? const Color(0xFFE50914) : Colors.white,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            channel.group,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.play_circle_filled, color: Color(0xFFE50914))
                              : null,
                          onTap: () {
                            Get.back();
                            if (!isCurrent) {
                              currentIndex = index;
                              playChannel(channel);
                              isFavorite.value = _storage.isLiveFavorite(channel.url);
                              setState(() {});
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
