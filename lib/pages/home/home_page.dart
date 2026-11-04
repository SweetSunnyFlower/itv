import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'home_controller.dart';
import '../../widgets/vod_card.dart';
import '../../widgets/tv_focusable.dart';
import '../../app/models/vod_model.dart';
import '../../utils/responsive.dart';
import '../../utils/tv_detector.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<HomeController>();
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(screenWidth);

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Builder(
        builder: (context) {
          final scrollView = CustomScrollView(
            slivers: [
              // 顶部 AppBar
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF141414),
                elevation: 0,
                title: Row(
                  children: [
                    const Text(
                      'VoirTV',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white, size: 26),
                      onPressed: () => Get.toNamed('/search'),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Obx(() {
                if (ctrl.isLoading.value) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    // 大横幅轮播
                    if (ctrl.featuredList.isNotEmpty)
                      _FeaturedBanner(featuredList: ctrl.featuredList),
                    // 分类行
                    ...ctrl.categoryVods.entries.map((entry) {
                      final name = ctrl.getCategoryName(entry.key);
                      final vods = entry.value;
                      if (vods.isEmpty) return const SizedBox.shrink();
                      return _buildCategoryRow(name, vods, screenWidth, deviceType);
                    }),
                    const SizedBox(height: 80),
                  ]),
                );
              }),
            ],
          );
          if (isAndroidTV) return scrollView;
          return RefreshIndicator(
            color: const Color(0xFFE50914),
            onRefresh: ctrl.loadData,
            child: scrollView,
          );
        },
      ),
    );
  }

  Widget _buildCategoryRow(String title, List<VodModel> vods, double screenWidth, DeviceType deviceType) {
    final isWide = deviceType != DeviceType.mobile;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          if (isWide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = deviceType == DeviceType.desktop ? 6 : 4;
                  final spacing = 12.0;
                  final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 12,
                    children: vods.take(columns * 2).map((vod) {
                      return VodCard(
                        vod: vod,
                        width: cardWidth,
                        onTap: () => Get.toNamed('/detail', arguments: {'vod_id': vod.vodId}),
                      );
                    }).toList(),
                  );
                },
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: vods.length,
                itemBuilder: (context, index) {
                  final vod = vods[index];
                  return VodCard(
                    vod: vod,
                    onTap: () => Get.toNamed('/detail', arguments: {'vod_id': vod.vodId}),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 淡入淡出轮播横幅
class _FeaturedBanner extends StatefulWidget {
  final List<VodModel> featuredList;
  const _FeaturedBanner({required this.featuredList});

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  int _currentIndex = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.featuredList.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannerHeight = responsiveBannerHeight(MediaQuery.of(context).size.width);

    return Container(
      height: bannerHeight,
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          // 淡入淡出图片层
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: TVFocusable(
              key: ValueKey(_currentIndex),
              onSelect: () => Get.toNamed('/detail', arguments: {'vod_id': widget.featuredList[_currentIndex].vodId}),
              borderRadius: BorderRadius.zero,
              focusScale: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.featuredList[_currentIndex].vodPic,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: const Color(0xFF1A1A1A)),
                  ),
                  // 底部渐变
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            const Color(0xFF141414).withValues(alpha: 0.8),
                            const Color(0xFF141414),
                          ],
                          stops: const [0.0, 0.4, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部信息（固定位置，带动画）
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    widget.featuredList[_currentIndex].vodName,
                    key: ValueKey('title_$_currentIndex'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.featuredList[_currentIndex].vodRemarks.isNotEmpty)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      widget.featuredList[_currentIndex].vodRemarks,
                      key: ValueKey('remarks_$_currentIndex'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _bannerButton(Icons.play_arrow, '播放', true, () {
                      Get.toNamed('/detail', arguments: {'vod_id': widget.featuredList[_currentIndex].vodId});
                    }),
                    const SizedBox(width: 10),
                    _bannerButton(Icons.info_outline, '详情', false, () {
                      Get.toNamed('/detail', arguments: {'vod_id': widget.featuredList[_currentIndex].vodId});
                    }),
                  ],
                ),
              ],
            ),
          ),
          // 指示器
          Positioned(
            bottom: 20,
            right: 16,
            child: Row(
              children: List.generate(
                widget.featuredList.length > 5 ? 5 : widget.featuredList.length,
                (index) {
                  final actualIndex = widget.featuredList.length > 5
                      ? (_currentIndex - 2 + index + widget.featuredList.length) % widget.featuredList.length
                      : index;
                  final isActive = _currentIndex == actualIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFE50914) : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerButton(IconData icon, String label, bool primary, VoidCallback onTap) {
    return TVFocusable(
      onSelect: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: primary ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: primary ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
