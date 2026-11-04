import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'site_controller.dart';
import '../../app/models/site_model.dart';

class SitePage extends StatefulWidget {
  const SitePage({super.key});

  @override
  State<SitePage> createState() => _SitePageState();
}

class _SitePageState extends State<SitePage> {
  int _tapCount = 0;
  DateTime _lastTap = DateTime.now();

  void _onTitleTap(SiteController ctrl) {
    final now = DateTime.now();
    if (now.difference(_lastTap).inSeconds > 2) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      ctrl.toggleAdult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SiteController>();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: GestureDetector(
          onTap: () => _onTitleTap(ctrl),
          child: const Text('切换站点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.defaultDialog(
                title: '恢复默认',
                middleText: '确定恢复为默认站点列表？',
                backgroundColor: const Color(0xFF2A2A2A),
                titleStyle: const TextStyle(color: Colors.white),
                middleTextStyle: const TextStyle(color: Colors.white70),
                confirmTextColor: Colors.white,
                cancelTextColor: Colors.white70,
                buttonColor: const Color(0xFFE50914),
                onConfirm: () { ctrl.resetToDefault(); Get.back(); },
                onCancel: () {},
              );
            },
            child: const Text('重置', style: TextStyle(color: Color(0xFFE50914), fontSize: 13)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE50914),
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, ctrl),
      ),
      body: Obx(() {
        final display = ctrl.displaySites;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: display.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final site = display[index];
            final realIndex = ctrl.sites.indexOf(site);
            final isCurrent = ctrl.currentIndex.value == realIndex;
            return GestureDetector(
              onTap: () {
                ctrl.switchSite(realIndex);
                Get.back();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFFE50914).withValues(alpha: 0.15) : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFFE50914).withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          site.name.isNotEmpty ? site.name[0] : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(site.name, style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontWeight: FontWeight.w500, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(site.url, style: const TextStyle(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      const Icon(Icons.check_circle, color: Color(0xFFE50914), size: 20)
                    else
                      GestureDetector(
                        onTap: () => ctrl.removeSite(realIndex),
                        child: const Icon(Icons.close, color: Colors.white24, size: 18),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _showAddDialog(BuildContext context, SiteController ctrl) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('添加站点', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '站点名称',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'API 地址 (如 https://xxx.com)',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                ctrl.addSite(SiteModel(url: urlCtrl.text.trim(), name: nameCtrl.text.trim()));
                Get.back();
              }
            },
            child: const Text('添加', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }
}
