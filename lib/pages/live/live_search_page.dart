import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/models/live_channel.dart';
import 'live_search_controller.dart';
import 'live_player_page.dart';

class LiveSearchPage extends StatelessWidget {
  const LiveSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(LiveSearchController());
    final textCtrl = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 38,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: textCtrl,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: '搜索直播频道...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              prefixIcon: Icon(Icons.search, color: Colors.white24, size: 20),
            ),
            onSubmitted: (text) => ctrl.search(text),
          ),
        ),
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFE50914)),
                SizedBox(height: 16),
                Text('正在加载直播源...', style: TextStyle(color: Colors.white24, fontSize: 14)),
              ],
            ),
          );
        }

        if (ctrl.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ctrl.keyword.isEmpty ? Icons.search : Icons.live_tv_outlined,
                  color: Colors.white12,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  ctrl.keyword.isEmpty ? '搜索你想看的频道' : '未找到相关频道',
                  style: const TextStyle(color: Colors.white24, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: ctrl.results.length,
          itemBuilder: (context, index) {
            final channel = ctrl.results[index];
            return _SearchResultItem(
              channel: channel,
              onTap: () => Get.to(() => LivePlayerPage(channel: channel)),
            );
          },
        );
      }),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final LiveChannel channel;
  final VoidCallback onTap;

  const _SearchResultItem({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 56,
                height: 56,
                color: Colors.white.withValues(alpha: 0.08),
                child: channel.logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: channel.logo,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.live_tv,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.live_tv,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 分组标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          channel.group,
                          style: const TextStyle(color: Color(0xFFE50914), fontSize: 10),
                        ),
                      ),
                      // 国家
                      if (channel.country.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          channel.country,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 箭头
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }
}
