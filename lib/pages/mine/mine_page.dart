import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../favorites/favorites_page.dart';
import '../history/history_page.dart';
import '../live/favorite_live_page.dart';
import '../search/search_history_page.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Column(
        children: [
          // 顶部标题栏
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 8),
            child: const Row(
              children: [
                Text(
                  '我的',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          // 内容
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  children: [
                    _buildMenuItem(
                      icon: Icons.favorite_outline,
                      title: '我的收藏',
                      onTap: () => Get.to(() => const FavoritesPage()),
                    ),
                    _buildMenuItem(
                      icon: Icons.live_tv_outlined,
                      title: '收藏的直播',
                      onTap: () => Get.to(() => const FavoriteLivePage()),
                    ),
                    _buildMenuItem(
                      icon: Icons.history,
                      title: '搜索历史',
                      onTap: () async {
                        final result = await Get.to(() => const SearchHistoryPage());
                        if (result != null && result is String) {
                          Get.toNamed('/search', arguments: result);
                        }
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.access_time,
                      title: '观看历史',
                      onTap: () => Get.to(() => const HistoryPage()),
                    ),
                    _buildMenuItem(
                      icon: Icons.download_outlined,
                      title: '我的下载',
                      onTap: () => Get.toNamed('/download'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
