import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/services/collection_controller.dart';
import '../../utils/responsive.dart';
import '../../widgets/tv_focusable.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CollectionController>();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text('我的收藏', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        final favorites = ctrl.favorites;
        if (favorites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, color: Colors.white12, size: 64),
                SizedBox(height: 12),
                Text('还没有收藏内容', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = responsiveGridCount(constraints.maxWidth, mobileCount: 3, tabletCount: 4, desktopCount: 6);
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 0.58,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final item = favorites[index];
                return TVFocusable(
                  onSelect: () => Get.toNamed('/detail', arguments: {'vod_id': item['vod_id']}),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: item['vod_pic'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: const Color(0xFF2A2A2A),
                            child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24)),
                          ),
                        ),
                        // 黑色渐变蒙层
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                                stops: const [0.0, 0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // 状态标签
                        if ((item['vod_remarks'] ?? '').isNotEmpty)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item['vod_remarks'],
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        // 名称和站点在蒙层上
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['vod_name'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                                ),
                              ),
                              const SizedBox(height: 2),
                              if ((item['site_name'] ?? '').isNotEmpty)
                                Text(
                                  item['site_name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }
}
