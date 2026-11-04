import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'rank_controller.dart';
import '../../widgets/tv_focusable.dart';
import '../../utils/tv_detector.dart';

class RankPage extends StatelessWidget {
  const RankPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RankController());

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
                  '排行榜',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          // 内容
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
              }
              if (ctrl.rankList.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.leaderboard_outlined, color: Colors.white12, size: 64),
                      SizedBox(height: 12),
                      Text('暂无排行数据', style: TextStyle(color: Colors.white24)),
                    ],
                  ),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Builder(
                    builder: (context) {
                      final listView = ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: ctrl.rankList.length,
                        itemBuilder: (context, index) {
                          final vod = ctrl.rankList[index];
                          return TVFocusable(
                            onSelect: () => Get.toNamed('/detail', arguments: {'vod_id': vod.vodId}),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // 排名数字
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: index < 3 ? const Color(0xFFE50914) : Colors.white38,
                                        fontSize: index < 3 ? 20 : 16,
                                        fontWeight: index < 3 ? FontWeight.w900 : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 封面
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: vod.vodPic.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: vod.vodPic,
                                            width: 80,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, _, _) => _placeholderCover(),
                                          )
                                        : _placeholderCover(),
                                  ),
                                  const SizedBox(width: 12),
                                  // 信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vod.vodName,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        if (vod.typeName.isNotEmpty)
                                          Text(vod.typeName, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                        if (vod.vodRemarks.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                vod.vodRemarks,
                                                style: const TextStyle(color: Color(0xFFE50914), fontSize: 10),
                                              ),
                                            ),
                                          ),
                                        if (vod.vodYear.isNotEmpty || vod.vodArea.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              [vod.vodYear, vod.vodArea].where((s) => s.isNotEmpty).join(' · '),
                                              style: const TextStyle(color: Colors.white24, fontSize: 11),
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
                      if (isAndroidTV) return listView;
                      return RefreshIndicator(
                        color: const Color(0xFFE50914),
                        onRefresh: ctrl.loadRank,
                        child: listView,
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 80,
      height: 110,
      color: const Color(0xFF2A2A2A),
      child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24)),
    );
  }
}
