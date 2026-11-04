import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'category_controller.dart';
import '../../utils/responsive.dart';
import '../../widgets/tv_focusable.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CategoryController());

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏
            Container(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
              child: const Row(
                children: [
                  Text(
                    '分类',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 一级：父分类 tab
            FocusTraversalGroup(
              child: Obx(() {
              if (ctrl.parentCategories.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 44,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ctrl.parentCategories.length,
                  itemBuilder: (context, index) {
                    final cat = ctrl.parentCategories[index];
                    return Obx(() {
                      final selected =
                          ctrl.selectedParentId.value == cat.typeId;
                      return TVFocusable(
                        onSelect: () => ctrl.selectParent(cat.typeId),
                        borderRadius: BorderRadius.zero,
                        focusScale: 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected
                                    ? const Color(0xFFE50914)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            cat.typeName,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white54,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              );
            }),
            ),
            // 二级：子分类 chips
            Obx(() {
              final children = ctrl.childCategories;
              if (children.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: children.map(
                      (cat) => _buildChip(
                        cat.typeName,
                        ctrl.selectedChildId.value == cat.typeId,
                        () => ctrl.selectChild(cat.typeId),
                      ),
                    ).toList(),
                  ),
                ),
              );
            }),
            // 三级：年份 chips
            Obx(() {
              return Container(
                padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ctrl.years
                        .map(
                          (year) => _buildChip(
                            year.isEmpty ? '全部' : year,
                            ctrl.selectedYear.value == year,
                            () => ctrl.selectYear(year),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }),
            // 内容列表
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)),
                  );
                }
                if (ctrl.vodList.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(color: Colors.white24),
                    ),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (scroll) {
                    if (scroll.metrics.pixels >
                        scroll.metrics.maxScrollExtent - 200) {
                      ctrl.loadVods();
                    }
                    return false;
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = responsiveGridCount(
                        constraints.maxWidth,
                        mobileCount: 3,
                        tabletCount: 4,
                        desktopCount: 6,
                      );
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              childAspectRatio: 0.52,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 14,
                            ),
                        itemCount:
                            ctrl.vodList.length + (ctrl.hasMore.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= ctrl.vodList.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFE50914),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final vod = ctrl.vodList[index];
                          return TVFocusable(
                            onSelect: () => Get.toNamed(
                              '/detail',
                              arguments: {'vod_id': vod.vodId},
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 海报图片
                                  vod.vodPic.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: vod.vodPic,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            color: const Color(0xFF2A2A2A),
                                            child: const Center(
                                              child: Icon(
                                                Icons.movie_outlined,
                                                color: Colors.white24,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF2A2A2A),
                                          child: const Center(
                                            child: Icon(
                                              Icons.movie_outlined,
                                              color: Colors.white24,
                                            ),
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
                                  if (vod.vodRemarks.isNotEmpty)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE50914),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          vod.vodRemarks,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // 名称和分类在蒙层上
                                  Positioned(
                                    left: 6,
                                    right: 6,
                                    bottom: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vod.vodName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            shadows: [
                                              Shadow(blurRadius: 4, color: Colors.black54),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (vod.typeName.isNotEmpty)
                                          Text(
                                            vod.typeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
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
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TVFocusable(
        onSelect: onTap,
        borderRadius: BorderRadius.circular(16),
        focusScale: 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
