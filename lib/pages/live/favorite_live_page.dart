import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/models/live_channel.dart';
import '../../app/services/storage_service.dart';
import 'live_player_page.dart';

class FavoriteLivePage extends StatelessWidget {
  const FavoriteLivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final favorites = storage.getLiveFavorites();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text('收藏的直播', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, color: Colors.white12, size: 64),
                  SizedBox(height: 12),
                  Text('暂无收藏的直播', style: TextStyle(color: Colors.white24)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final channel = LiveChannel.fromJson(favorites[index]);
                return _buildChannelCard(channel, storage);
              },
            ),
    );
  }

  Widget _buildChannelCard(LiveChannel channel, StorageService storage) {
    return GestureDetector(
      onTap: () => Get.to(() => LivePlayerPage(channel: channel)),
      onLongPress: () => _showDeleteDialog(channel, storage),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: channel.logo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        child: CachedNetworkImage(
                          imageUrl: channel.logo,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE50914)),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.live_tv,
                            size: 28,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.live_tv,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
              ),
            ),
            // 名称
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                channel.name,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(LiveChannel channel, StorageService storage) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('取消收藏', style: TextStyle(color: Colors.white)),
        content: Text('确定要取消收藏 "${channel.name}" 吗？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              storage.removeLiveFavorite(channel.url);
              Get.back();
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
            },
            child: const Text('确定', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }
}
