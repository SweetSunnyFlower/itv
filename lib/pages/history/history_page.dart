import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/services/collection_controller.dart';
import '../../app/services/storage_service.dart';
import '../../app/services/api_service.dart';
import '../../widgets/tv_focusable.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _goPlayer(BuildContext context, Map<String, dynamic> item) async {
    final vodId = item['vod_id'] as int? ?? 0;
    final siteUrl = item['site_url'] as String? ?? '';
    final siteName = item['site_name'] as String? ?? '';
    if (vodId == 0 || siteUrl.isEmpty) {
      Get.toNamed('/detail', arguments: {'vod_id': vodId});
      return;
    }

    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
    );

    final navigator = Navigator.of(context);

    try {
      final api = ApiService();
      final vod = await api.getVodDetail(siteUrl, vodId);
      navigator.pop(); // 关闭 loading

      if (vod == null) {
        Get.toNamed('/detail', arguments: {'vod_id': vodId});
        return;
      }

      final routes = vod.playRoutes;
      if (routes.isEmpty) {
        Get.toNamed('/detail', arguments: {'vod_id': vodId});
        return;
      }

      // 选择播放线路：优先 m3u8
      final m3u8Route = routes.keys.toList().firstWhereOrNull(
        (r) => r.toLowerCase().contains('m3u8'),
      );
      final routeName = m3u8Route ?? routes.keys.first;
      final episodes = routes[routeName]!;

      // 从进度中恢复集数
      final storage = StorageService();
      final progress = storage.getProgress(vodId, siteUrl);
      int epIndex = progress?['ep_index'] as int? ?? 0;
      if (epIndex >= episodes.length) epIndex = 0;

      final ep = episodes[epIndex];
      Get.toNamed('/player', arguments: {
        'url': ep.url,
        'title': '${vod.vodName} - ${ep.name}',
        'vod_name': vod.vodName,
        'vod_id': vod.vodId,
        'site_url': siteUrl,
        'site_name': siteName,
        'vod_remarks': vod.vodRemarks,
        'vod_content': vod.vodContent,
        'vod_director': vod.vodDirector,
        'vod_actor': vod.vodActor,
        'route_name': routeName,
        'ep_index': epIndex,
        'episodes': episodes.map((e) => {'name': e.name, 'url': e.url}).toList(),
      });
    } catch (e) {
      navigator.pop();
      Get.toNamed('/detail', arguments: {'vod_id': vodId});
    }
  }

  Future<void> _goShortDrama(BuildContext context, Map<String, dynamic> item) async {
    final vodId = item['vod_id'] as int? ?? 0;
    final siteUrl = item['site_url'] as String? ?? '';
    if (vodId == 0 || siteUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
    );
    final navigator = Navigator.of(context);

    try {
      final api = ApiService();
      final vod = await api.getVodDetail(siteUrl, vodId);
      navigator.pop();
      if (vod == null) return;

      final routes = vod.playRoutes;
      if (routes.isEmpty) return;

      final m3u8Route = routes.keys.toList().firstWhereOrNull(
        (r) => r.toLowerCase().contains('m3u8'),
      );
      final routeName = m3u8Route ?? routes.keys.first;
      final episodes = routes[routeName]!;

      final storage = StorageService();
      final progress = storage.getProgress(vodId, siteUrl);
      int epIndex = progress?['ep_index'] as int? ?? 0;
      if (epIndex >= episodes.length) epIndex = 0;

      Get.toNamed('/short_drama', arguments: {
        'vod_name': vod.vodName,
        'vod_id': vod.vodId,
        'site_url': siteUrl,
        'ep_index': epIndex,
        'episodes': episodes.map((e) => {'name': e.name, 'url': e.url}).toList(),
      });
    } catch (e) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CollectionController>();
    final storage = StorageService();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text('观看历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Obx(() => ctrl.history.isNotEmpty
              ? TextButton(
                  onPressed: ctrl.clearHistory,
                  child: const Text('清空', style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Obx(() {
        final history = ctrl.history;
        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, color: Colors.white12, size: 64),
                SizedBox(height: 12),
                Text('还没有观看记录', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = history[index];
            final vodId = item['vod_id'] as int? ?? 0;
            final siteUrl = item['site_url'] as String? ?? '';
            final progress = storage.getProgress(vodId, siteUrl);
            final position = progress?['position'] as int? ?? 0;
            final duration = progress?['duration'] as int? ?? 0;
            final epName = progress?['ep_name'] as String? ?? '';
            final progressRatio = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

            return TVFocusable(
              onSelect: () => _goPlayer(context, item),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: item['vod_pic'] ?? '',
                          width: 100,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 100, height: 64, color: const Color(0xFF2A2A2A),
                            child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 20)),
                          ),
                        ),
                        if (progressRatio > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              minHeight: 3,
                              backgroundColor: Colors.black38,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['vod_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        if (position > 0)
                          Text(
                            '${epName.isNotEmpty ? '$epName · ' : ''}观看至 ${_formatDuration(position)}${duration > 0 ? ' / ${_formatDuration(duration)}' : ''}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(item['site_name'] ?? '', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                  ),
                  // 短剧按钮
                  TVFocusable(
                    onSelect: () => _goShortDrama(context, item),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.stay_current_portrait, color: Colors.white24, size: 22),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 播放图标
                  const Icon(Icons.play_circle_outline, color: Colors.white24, size: 28),
                ],
              ),
            );
          },
        );
      }),
        ),
      ),
    );
  }
}
