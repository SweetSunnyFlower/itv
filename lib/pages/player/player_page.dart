import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'player_controller.dart';
import '../../app/services/download_controller.dart';
import '../../app/services/dlna_service.dart';
import '../../utils/tv_detector.dart';
import '../../widgets/tv_focusable.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(PlayerController());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF141414),
        body: _buildNormalMode(context, ctrl),
      ),
    );
  }

  Widget _buildNormalMode(BuildContext context, PlayerController ctrl) {
    return Column(
      children: [
        // AppBar
        Container(
          color: Colors.black,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Get.back(),
              ),
              Expanded(
                child: Obx(() => Text(
                  ctrl.title.value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
              ),
              _buildCastButton(context, ctrl),
              _buildSpeedButton(context, ctrl),
              IconButton(
                icon: const Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 20),
                tooltip: '截图',
                onPressed: () async {
                  final path = await ctrl.takeScreenshot();
                  if (path != null) {
                    Get.snackbar('截图成功', '已保存到 $path',
                      backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12),
                      duration: const Duration(seconds: 3));
                  } else {
                    Get.snackbar('截图失败', '无法获取当前画面',
                      backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                  }
                },
              ),
              if (Platform.isAndroid)
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white70, size: 20),
                  tooltip: '画中画',
                  onPressed: () async {
                    final isPipAvailable = await SimplePip.isPipAvailable;
                    if (isPipAvailable) {
                      await SimplePip().enterPipMode();
                    } else {
                      Get.snackbar('不支持', '当前设备不支持画中画',
                        backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                    }
                  },
                ),
            ],
          ),
        ),
        // 视频区域
        Flexible(
          child: LayoutBuilder(
          builder: (context, constraints) {
            final videoHeight = (constraints.maxWidth * 9 / 16).clamp(0.0, constraints.maxHeight);
            return SizedBox(
              width: double.infinity,
              height: videoHeight,
              child: Focus(
                autofocus: isAndroidTV,
                onKeyEvent: (node, event) {
                  if (!isAndroidTV || event is! KeyDownEvent) return KeyEventResult.ignored;
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowLeft) {
                    final pos = ctrl.player.state.position;
                    ctrl.player.seek(pos - const Duration(seconds: 10));
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.arrowRight) {
                    final pos = ctrl.player.state.position;
                    ctrl.player.seek(pos + const Duration(seconds: 10));
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.select ||
                             key == LogicalKeyboardKey.enter ||
                             key == LogicalKeyboardKey.space) {
                    ctrl.player.playOrPause();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onLongPressStart: isAndroidTV ? null : (_) => ctrl.startLongPressSpeed(),
                  onLongPressEnd: isAndroidTV ? null : (_) => ctrl.stopLongPressSpeed(),
                  onLongPressCancel: isAndroidTV ? null : () => ctrl.stopLongPressSpeed(),
                  child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Obx(() {
                        if (ctrl.hasError.value) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white24, size: 36),
                                const SizedBox(height: 8),
                                Text(ctrl.errorMsg.value, style: const TextStyle(color: Colors.white24, fontSize: 11), textAlign: TextAlign.center),
                              ],
                            ),
                          );
                        }
                        return MaterialVideoControlsTheme(
                          normal: MaterialVideoControlsThemeData(
                            seekBarPositionColor: const Color(0xFFE50914),
                            seekBarThumbColor: const Color(0xFFE50914),
                            buttonBarButtonColor: Colors.white,
                            padding: const EdgeInsets.only(bottom: 22),
                            seekBarMargin: const EdgeInsets.symmetric(horizontal: 16),
                            bufferingIndicatorBuilder: (_) => const SizedBox.shrink(),
                            volumeGesture: !isAndroidTV,
                            brightnessGesture: !isAndroidTV,
                            seekOnDoubleTap: !isAndroidTV,
                            seekGesture: !isAndroidTV,
                          ),
                          fullscreen: MaterialVideoControlsThemeData(
                            seekBarPositionColor: const Color(0xFFE50914),
                            seekBarThumbColor: const Color(0xFFE50914),
                            buttonBarButtonColor: Colors.white,
                            padding: const EdgeInsets.only(bottom: 16),
                            seekBarMargin: const EdgeInsets.symmetric(horizontal: 16),
                            bufferingIndicatorBuilder: (_) => const SizedBox.shrink(),
                            volumeGesture: !isAndroidTV,
                            brightnessGesture: !isAndroidTV,
                            seekOnDoubleTap: !isAndroidTV,
                            seekGesture: !isAndroidTV,
                          ),
                          child: Video(
                            controller: ctrl.videoController,
                            controls: MaterialVideoControls,
                          ),
                        );
                      }),
                    ),
                    // 缓冲加载指示器
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Obx(() {
                          if (!ctrl.isBuffering.value) return const SizedBox.shrink();
                          final pct = ctrl.bufferPercent.value;
                          return Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Color(0xFFE50914),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      pct > 0 ? '缓冲 $pct%' : '加载中...',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 长按加速指示器
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Obx(() {
                          if (!ctrl.isLongPressSpeed.value) return const SizedBox.shrink();
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fast_forward, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('3x 快进中', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 视频分辨率/码率
                    Positioned(
                      left: 8,
                      bottom: 32,
                      child: IgnorePointer(
                        child: Obx(() {
                          final w = ctrl.videoWidth.value;
                          final h = ctrl.videoHeight.value;
                          final br = ctrl.videoBitrate.value;
                          if (w == 0 && h == 0 && br.isEmpty) return const SizedBox.shrink();
                          final parts = <String>[];
                          if (w > 0 && h > 0) parts.add('${w}x$h');
                          if (br.isNotEmpty) parts.add(br);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              parts.join(' · '),
                              style: const TextStyle(color: Colors.white38, fontSize: 9),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              ),
            );
          },
        ),
        ),
        // 下方信息和选集
        Expanded(
          child: Container(
            color: const Color(0xFF141414),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 固定区域：标题、信息
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ctrl.vodName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (ctrl.vodRemarks.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(ctrl.vodRemarks, style: const TextStyle(color: Color(0xFFE50914), fontSize: 12))),
                      if (ctrl.vodDirector.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text('导演: ${ctrl.vodDirector}', style: const TextStyle(color: Colors.white30, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (ctrl.vodActor.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text('主演: ${ctrl.vodActor}', style: const TextStyle(color: Colors.white30, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      if (ctrl.vodContent.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_stripHtml(ctrl.vodContent), style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                        ),
                      if (ctrl.episodes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 10),
                          child: Text('选集${ctrl.currentRoute.isNotEmpty ? ' (${ctrl.currentRoute})' : ''}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                // 可滚动区域：剧集网格，占满剩余空间
                if (ctrl.episodes.isNotEmpty)
                  Expanded(
                    child: Obx(() {
                      final currentEp = ctrl.currentEpIndex.value;
                      DownloadController? dlCtrl;
                      try { dlCtrl = Get.find<DownloadController>(); } catch (_) {}
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: ((MediaQuery.of(context).size.width - 32 - 24) / 4) / 34,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: ctrl.episodes.length,
                        itemBuilder: (context, index) {
                          final ep = ctrl.episodes[index];
                          final isPlaying = currentEp == index;
                          final isDownloaded = dlCtrl?.getLocalPath(ctrl.vodId, ep.name) != null;
                          return TVFocusable(
                            onSelect: () => ctrl.playEpisode(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isPlaying ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    ep.name,
                                    style: TextStyle(color: isPlaying ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isDownloaded && !isPlaying)
                                    const Positioned(
                                      right: 3,
                                      top: 0,
                                      child: Icon(Icons.file_download_done, size: 10, color: Color(0xFF4CAF50)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
  }

  Widget _buildCastButton(BuildContext context, PlayerController ctrl) {
    final dlna = Get.put(DlnaService());
    return Obx(() {
      final casting = dlna.isCasting.value;
      return IconButton(
        icon: Icon(
          casting ? Icons.cast_connected : Icons.cast,
          color: casting ? const Color(0xFFE50914) : Colors.white70,
          size: 20,
        ),
        tooltip: '投屏',
        onPressed: () {
          if (casting) {
            dlna.stopCast();
          } else {
            _showCastSheet(context, ctrl, dlna);
          }
        },
      );
    });
  }

  void _showCastSheet(BuildContext context, PlayerController ctrl, DlnaService dlna) {
    dlna.startSearch();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    const Text('选择投屏设备', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        dlna.stopSearch();
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close, color: Colors.white38, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              SizedBox(
                height: 300,
                child: Obx(() {
                  final devices = dlna.devices;
                  if (devices.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                          SizedBox(height: 12),
                          Text('正在搜索设备...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: devices.length,
                    itemBuilder: (ctx, index) {
                      final device = devices[index];
                      final name = device.info.friendlyName;
                      return ListTile(
                        leading: const Icon(Icons.tv, color: Colors.white54),
                        title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        onTap: () async {
                          final url = ctrl.getCurrentRemoteUrl();
                          if (url.startsWith('/')) {
                            Get.snackbar('无法投屏', '本地文件不支持投屏',
                              backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                            return;
                          }
                          Navigator.pop(ctx);
                          dlna.stopSearch();
                          final ok = await dlna.castTo(device, url, ctrl.title.value);
                          if (ok) {
                            Get.snackbar('投屏成功', '正在投射到 $name',
                              backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                          } else {
                            Get.snackbar('投屏失败', '无法连接到 $name',
                              backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                          }
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => dlna.stopSearch());
  }

  static const _speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0];

  Widget _buildSpeedButton(BuildContext context, PlayerController ctrl) {
    return Obx(() {
      final speed = ctrl.playbackSpeed.value;
      final label = speed == 1.0 ? '倍速' : '${speed}x';
      return PopupMenuButton<double>(
        onSelected: ctrl.setSpeed,
        color: const Color(0xFF2A2A2A),
        itemBuilder: (_) => _speeds.map((s) => PopupMenuItem(
          value: s,
          child: Text(
            s == 1.0 ? '正常' : '${s}x',
            style: TextStyle(
              color: s == speed ? const Color(0xFFE50914) : Colors.white70,
              fontSize: 13,
              fontWeight: s == speed ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        )).toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(label, style: TextStyle(color: speed == 1.0 ? Colors.white70 : const Color(0xFFE50914), fontSize: 13)),
        ),
      );
    });
  }
}
