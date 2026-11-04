import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/models/live_channel.dart';
import '../../utils/responsive.dart';
import '../../widgets/tv_focusable.dart';
import 'live_controller.dart';
import 'live_player_page.dart';
import 'live_search_page.dart';

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LiveController>(
      init: LiveController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFF141414),
          body: Obx(() {
            if (controller.isLoadingCategories.value) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
            }

            if (controller.errorMessage.value.isNotEmpty && controller.categories.isEmpty) {
              return _buildErrorWidget(controller);
            }

            return Column(
              children: [
                // 顶部标题栏
                Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 8, bottom: 8),
                  child: Row(
                    children: [
                      const Text(
                        'TV',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => Get.to(() => const LiveSearchPage()),
                      ),
                    ],
                  ),
                ),
                // 内容
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sidebarWidth = getDeviceType(constraints.maxWidth) == DeviceType.mobile ? 90.0 : 120.0;
                      return Row(
                        children: [
                          // 左侧分类列表
                          FocusTraversalGroup(
                            child: _buildCategoryList(controller, sidebarWidth),
                          ),
                          // 右侧频道列表
                          Expanded(
                            child: FocusTraversalGroup(
                              child: _buildChannelSection(controller, constraints.maxWidth - sidebarWidth),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildErrorWidget(LiveController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white12, size: 64),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              controller.errorMessage.value,
              style: const TextStyle(color: Colors.white24),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: controller.loadCategories,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(LiveController controller, double sidebarWidth) {
    return Container(
      width: sidebarWidth,
      color: Colors.white.withValues(alpha: 0.03),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];
          final isSelected = controller.selectedCategory.value?.m3uUrl == category.m3uUrl;

          return InkWell(
            onTap: () => controller.selectCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.2) : null,
                border: isSelected
                    ? Border(left: BorderSide(color: const Color(0xFFE50914), width: 3))
                    : null,
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE50914) : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelSection(LiveController controller, double availableWidth) {
    if (controller.isLoadingChannels.value) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }

    if (controller.errorMessage.value.isNotEmpty) {
      return _buildErrorWidget(controller);
    }

    if (controller.groupedChannels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_outlined, color: Colors.white12, size: 64),
            SizedBox(height: 12),
            Text('没有找到频道', style: TextStyle(color: Colors.white24)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 分组标签
        _buildGroupTabs(controller),

        // 频道列表
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE50914),
            onRefresh: () async {
              if (controller.selectedCategory.value != null) {
                await controller.loadChannels(controller.selectedCategory.value!.m3uUrl);
              }
            },
            child: _buildChannelList(controller, availableWidth),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTabs(LiveController controller) {
    final groups = controller.groupedChannels.keys.toList();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final isSelected = group == controller.selectedGroup.value;
          final count = controller.groupedChannels[group]?.length ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              label: Text('$group ($count)', style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              onSelected: (_) => controller.selectGroup(group),
              selectedColor: const Color(0xFFE50914),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelList(LiveController controller, double availableWidth) {
    final channels = controller.groupedChannels[controller.selectedGroup.value] ?? [];
    final columns = responsiveGridCount(
      availableWidth,
      mobileCount: 3,
      tabletCount: 4,
      desktopCount: 5,
    );

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelCard(channel, controller);
      },
    );
  }

  Widget _buildChannelCard(LiveChannel channel, LiveController controller) {
    return TVFocusable(
      onSelect: () {
        final m3uUrl = controller.selectedCategory.value?.m3uUrl;
        Get.to(() => LivePlayerPage(channel: channel, m3uUrl: m3uUrl));
      },
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

  void _showSearchDialog(BuildContext context, LiveController controller) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('搜索频道', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '输入频道名称',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
            onSubmitted: (value) {
              controller.search(value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                textController.clear();
                controller.search('');
                Navigator.pop(context);
              },
              child: const Text('重置'),
            ),
            TextButton(
              onPressed: () {
                controller.search(textController.text);
                Navigator.pop(context);
              },
              child: const Text('搜索', style: TextStyle(color: Color(0xFFE50914))),
            ),
          ],
        );
      },
    );
  }
}
