import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/services/storage_service.dart';

class SearchHistoryPage extends StatelessWidget {
  const SearchHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final history = storage.getSearchHistory();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text('搜索历史', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () => _showClearDialog(storage),
              child: const Text('清空', style: TextStyle(color: Colors.white54)),
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: Colors.white12, size: 64),
                  SizedBox(height: 12),
                  Text('暂无搜索历史', style: TextStyle(color: Colors.white24)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final keyword = history[index];
                return InkWell(
                  onTap: () {
                    // 跳转到搜索页面并自动搜索
                    Get.back(result: keyword);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            keyword,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                        Icon(Icons.north_west, color: Colors.white.withValues(alpha: 0.3), size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showClearDialog(StorageService storage) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('清空历史', style: TextStyle(color: Colors.white)),
        content: const Text('确定要清空所有搜索历史吗？', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              storage.clearSearchHistory();
              Get.back();
              Get.snackbar(
                '',
                '已清空搜索历史',
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
