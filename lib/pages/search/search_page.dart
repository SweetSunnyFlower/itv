import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'search_controller.dart' as app;
import '../../widgets/tv_focusable.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(app.SearchController());
    final textCtrl = TextEditingController();

    // 如果从搜索历史页面传入了关键词，自动搜索
    final args = Get.arguments;
    if (args != null && args is String && args.isNotEmpty) {
      textCtrl.text = args;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.search(args);
      });
    }

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
              hintText: '搜索影片、电视剧、综艺...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              prefixIcon: Icon(Icons.search, color: Colors.white24, size: 20),
            ),
            onSubmitted: (text) => ctrl.search(text),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Obx(() {
        if (ctrl.isLoading.value && ctrl.results.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }
        if (ctrl.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ctrl.keyword.isEmpty ? Icons.search : Icons.movie_filter_outlined,
                  color: Colors.white12,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  ctrl.keyword.isEmpty ? '搜索你想看的内容' : '未找到相关影片',
                  style: const TextStyle(color: Colors.white24, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 200) {
              ctrl.loadMore();
            }
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: ctrl.results.length,
            itemBuilder: (context, index) {
              final vod = ctrl.results[index];
              return _SearchResultItem(
                vod: vod,
                onTap: () => Get.toNamed('/detail', arguments: {'vod_id': vod.vodId}),
              );
            },
          ),
        );
      }),
        ),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final dynamic vod;
  final VoidCallback onTap;

  const _SearchResultItem({required this.vod, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      onSelect: onTap,
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 海报
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              child: CachedNetworkImage(
                imageUrl: vod.vodPic,
                width: 70,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24)),
                ),
                errorWidget: (_, _, _) => Container(
                  color: const Color(0xFF2A2A2A),
                  child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24)),
                ),
              ),
            ),
            // 信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vod.vodName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (vod.vodRemarks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              vod.vodRemarks,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (vod.typeName.isNotEmpty)
                      Text(
                        vod.typeName,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: Colors.white24, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '点击播放',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 箭头
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
