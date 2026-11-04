import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail_controller.dart';
import '../../app/models/vod_model.dart';
import '../../app/models/download_model.dart';
import '../../app/services/download_controller.dart';
import '../../utils/responsive.dart';
import '../../widgets/tv_focusable.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  void _goPlay(VodModel vod, String routeName, List<PlayItem> episodes, int epIndex, String siteUrl) {
    final ep = episodes[epIndex];
    Get.toNamed('/player', arguments: {
      'url': ep.url,
      'title': '${vod.vodName} - ${ep.name}',
      'vod_name': vod.vodName,
      'vod_id': vod.vodId,
      'site_url': siteUrl,
      'vod_remarks': vod.vodRemarks,
      'vod_content': vod.vodContent,
      'vod_director': vod.vodDirector,
      'vod_actor': vod.vodActor,
      'route_name': routeName,
      'ep_index': epIndex,
      'episodes': episodes.map((e) => {'name': e.name, 'url': e.url}).toList(),
    });
  }

  void _goShortDrama(VodModel vod, String routeName, List<PlayItem> episodes, int epIndex, String siteUrl) {
    Get.toNamed('/short_drama', arguments: {
      'vod_name': vod.vodName,
      'vod_id': vod.vodId,
      'site_url': siteUrl,
      'ep_index': epIndex,
      'episodes': episodes.map((e) => {'name': e.name, 'url': e.url}).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DetailController());
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
        }
        final vod = ctrl.vod.value;
        if (vod == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                const Text('加载失败', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                TextButton(onPressed: ctrl.loadDetail, child: const Text('重试', style: TextStyle(color: Color(0xFFE50914)))),
              ],
            ),
          );
        }
        final routes = vod.playRoutes;

        if (isWide) {
          return _buildDesktopLayout(context, ctrl, vod, routes, screenWidth);
        }
        return _buildMobileLayout(context, ctrl, vod, routes);
      }),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, DetailController ctrl, VodModel vod, Map<String, List<PlayItem>> routes, double screenWidth) {
    final epColumns = responsiveEpisodeCount(screenWidth - 400);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧封面
        SizedBox(
          width: 400,
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: vod.vodPic,
                width: 400,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(color: const Color(0xFF1A1A1A)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF141414).withValues(alpha: 0.8),
                        const Color(0xFF141414),
                      ],
                      stops: const [0.3, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ),
            ],
          ),
        ),
        // 右侧内容
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 顶部操作栏
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16),
                  child: Row(
                    children: [
                      const Spacer(),
                      if (routes.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.download_outlined, color: Colors.white),
                          onPressed: () => _showDownloadSheet(context, vod, ctrl),
                        ),
                      Obx(() => IconButton(
                        icon: Icon(
                          ctrl.isFavorite.value ? Icons.favorite : Icons.favorite_border,
                          color: ctrl.isFavorite.value ? const Color(0xFFE50914) : Colors.white,
                        ),
                        onPressed: ctrl.toggleFavorite,
                      )),
                    ],
                  ),
                ),
              ),
              // 标题 + 元信息
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vod.vodName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), maxLines: 2),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (vod.vodYear.isNotEmpty) _infoTag(vod.vodYear),
                          if (vod.vodArea.isNotEmpty) _infoTag(vod.vodArea),
                          if (vod.typeName.isNotEmpty) _infoTag(vod.typeName),
                          if (vod.vodRemarks.isNotEmpty) _infoTag(vod.vodRemarks),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 播放按钮
              if (routes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Obx(() {
                      final episodes = ctrl.currentEpisodes;
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: episodes.isNotEmpty
                                  ? () => _goPlay(vod, ctrl.currentRoute.value, episodes, 0, ctrl.siteCtrl.currentSite.url)
                                  : null,
                              icon: const Icon(Icons.play_arrow, size: 22),
                              label: const Text('立即播放', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: episodes.isNotEmpty
                                  ? () => _goShortDrama(vod, ctrl.currentRoute.value, episodes, 0, ctrl.siteCtrl.currentSite.url)
                                  : null,
                              icon: const Icon(Icons.stay_current_portrait, size: 18),
                              label: const Text('短剧', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF1E1E1E),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              // 简介
              if (vod.vodContent.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      _stripHtml(vod.vodContent),
                      style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (vod.vodDirector.isNotEmpty || vod.vodActor.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vod.vodDirector.isNotEmpty)
                          Text('导演: ${vod.vodDirector}', style: const TextStyle(color: Colors.white30, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (vod.vodActor.isNotEmpty)
                          Text('主演: ${vod.vodActor}', style: const TextStyle(color: Colors.white30, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              // 线路切换
              if (routes.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('播放线路', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Obx(() => Row(
                            children: routes.keys.map((route) {
                              final selected = ctrl.currentRoute.value == route;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: TVFocusable(
                                  onSelect: () => ctrl.switchRoute(route),
                                  borderRadius: BorderRadius.circular(4),
                                  focusScale: 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(route, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                                  ),
                                ),
                              );
                            }).toList(),
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              // 选集
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('选集', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Obx(() {
                        final episodes = ctrl.currentEpisodes;
                        if (episodes.isEmpty) {
                          return const Text('暂无播放源', style: TextStyle(color: Colors.white24, fontSize: 13));
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = epColumns;
                            final spacing = 8.0;
                            final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: List.generate(episodes.length, (index) {
                                final ep = episodes[index];
                                return TVFocusable(
                                  onSelect: () => _goPlay(vod, ctrl.currentRoute.value, episodes, index, ctrl.siteCtrl.currentSite.url),
                                  borderRadius: BorderRadius.circular(4),
                                  focusScale: 1.0,
                                  child: Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(ep.name, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, DetailController ctrl, VodModel vod, Map<String, List<PlayItem>> routes) {
    return CustomScrollView(
      slivers: [
        // 大封面 + 渐变
        SliverToBoxAdapter(
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: vod.vodPic,
                width: double.infinity,
                height: 360,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(height: 360, color: const Color(0xFF1A1A1A)),
              ),
              Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      const Color(0xFF141414).withValues(alpha: 0.9),
                      const Color(0xFF141414),
                    ],
                    stops: const [0.0, 0.3, 0.75, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (routes.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.download_outlined, color: Colors.white),
                        onPressed: () => _showDownloadSheet(context, vod, ctrl),
                      ),
                    Obx(() => IconButton(
                      icon: Icon(
                        ctrl.isFavorite.value ? Icons.favorite : Icons.favorite_border,
                        color: ctrl.isFavorite.value ? const Color(0xFFE50914) : Colors.white,
                      ),
                      onPressed: ctrl.toggleFavorite,
                    )),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vod.vodName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), maxLines: 2),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (vod.vodYear.isNotEmpty) _infoTag(vod.vodYear),
                        if (vod.vodArea.isNotEmpty) _infoTag(vod.vodArea),
                        if (vod.typeName.isNotEmpty) _infoTag(vod.typeName),
                        if (vod.vodRemarks.isNotEmpty) _infoTag(vod.vodRemarks),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 立即播放按钮
        if (routes.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Obx(() {
                final episodes = ctrl.currentEpisodes;
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: episodes.isNotEmpty
                            ? () => _goPlay(vod, ctrl.currentRoute.value, episodes, 0, ctrl.siteCtrl.currentSite.url)
                            : null,
                        icon: const Icon(Icons.play_arrow, size: 22),
                        label: const Text('立即播放', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: episodes.isNotEmpty
                            ? () => _goShortDrama(vod, ctrl.currentRoute.value, episodes, 0, ctrl.siteCtrl.currentSite.url)
                            : null,
                        icon: const Icon(Icons.stay_current_portrait, size: 18),
                        label: const Text('短剧', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF1E1E1E),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        // 简介
        if (vod.vodContent.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                _stripHtml(vod.vodContent),
                style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (vod.vodDirector.isNotEmpty || vod.vodActor.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (vod.vodDirector.isNotEmpty)
                    Text('导演: ${vod.vodDirector}', style: const TextStyle(color: Colors.white30, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (vod.vodActor.isNotEmpty)
                    Text('主演: ${vod.vodActor}', style: const TextStyle(color: Colors.white30, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        // 线路切换
        if (routes.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('播放线路', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(() => Row(
                      children: routes.keys.map((route) {
                        final selected = ctrl.currentRoute.value == route;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => ctrl.switchRoute(route),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(route, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                  ),
                ],
              ),
            ),
          ),
        // 选集
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选集', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Obx(() {
                  final episodes = ctrl.currentEpisodes;
                  if (episodes.isEmpty) {
                    return const Text('暂无播放源', style: TextStyle(color: Colors.white24, fontSize: 13));
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(episodes.length, (index) {
                      final ep = episodes[index];
                      return TVFocusable(
                        onSelect: () => _goPlay(vod, ctrl.currentRoute.value, episodes, index, ctrl.siteCtrl.currentSite.url),
                        borderRadius: BorderRadius.circular(4),
                        focusScale: 1.0,
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(ep.name, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDownloadSheet(BuildContext context, VodModel vod, DetailController ctrl) {
    final dlCtrl = Get.find<DownloadController>();
    final episodes = ctrl.currentEpisodes;
    if (episodes.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      isScrollControlled: true,
      builder: (ctx) {
        final selected = <int>[].obs;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      const Text('选择下载', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Obx(() => TextButton(
                        onPressed: () {
                          if (selected.length == episodes.length) {
                            selected.clear();
                          } else {
                            selected.clear();
                            selected.addAll(List.generate(episodes.length, (i) => i));
                          }
                        },
                        child: Text(
                          selected.length == episodes.length ? '取消全选' : '全选',
                          style: const TextStyle(color: Color(0xFFE50914), fontSize: 13),
                        ),
                      )),
                    ],
                  ),
                ),
                // 剧集列表
                Expanded(
                  child: Obx(() {
                    selected.length;
                    dlCtrl.tasks.length;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = responsiveEpisodeCount(constraints.maxWidth);
                        return GridView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: episodes.length,
                          itemBuilder: (_, index) {
                            final ep = episodes[index];
                            final isSelected = selected.contains(index);
                            final status = dlCtrl.getTaskStatus(vod.vodId, ep.name);
                            final isDownloaded = status == DownloadStatus.completed;
                            final isDownloading = status == DownloadStatus.downloading || status == DownloadStatus.pending;

                            return TVFocusable(
                              onSelect: () {
                                if (isDownloaded || isDownloading) return;
                                if (isSelected) {
                                  selected.remove(index);
                                } else {
                                  selected.add(index);
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              focusScale: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDownloaded
                                      ? const Color(0xFF2A3A2A)
                                      : isSelected
                                          ? const Color(0xFFE50914)
                                          : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isDownloaded ? '${ep.name} ✓' : ep.name,
                                  style: TextStyle(
                                    color: isDownloaded ? Colors.white38 : isSelected ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
                ),
                // 下载按钮
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Obx(() => SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selected.isNotEmpty
                            ? () {
                                final siteUrl = ctrl.siteCtrl.currentSite.url;
                                for (final i in selected) {
                                  final ep = episodes[i];
                                  dlCtrl.addTask(
                                    vodId: vod.vodId,
                                    vodName: vod.vodName,
                                    vodPic: vod.vodPic,
                                    episodeName: ep.name,
                                    url: ep.url,
                                    siteUrl: siteUrl,
                                  );
                                }
                                Navigator.pop(ctx);
                                Get.snackbar('下载任务已添加', '已添加 ${selected.length} 集到下载队列',
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                  margin: const EdgeInsets.all(12),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          disabledBackgroundColor: const Color(0xFF2A2A2A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('下载 (${selected.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    )),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
      child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
  }
}
