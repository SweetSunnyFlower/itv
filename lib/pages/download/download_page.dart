import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/models/download_model.dart';
import '../../app/services/download_controller.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DownloadController>();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text('下载管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Obx(() {
            if (ctrl.tasks.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white54),
              onPressed: () => _showClearDialog(context, ctrl),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (ctrl.tasks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined, color: Colors.white12, size: 64),
                SizedBox(height: 12),
                Text('暂无下载任务', style: TextStyle(color: Colors.white24, fontSize: 14)),
              ],
            ),
          );
        }

        final grouped = ctrl.groupedTasks;
        final keys = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final taskList = grouped[keys[index]]!;
            final first = taskList.first;
            return _buildGroupCard(context, ctrl, first, taskList);
          },
        );
      }),
    );
  }

  Widget _buildGroupCard(BuildContext context, DownloadController ctrl, DownloadTask first, List<DownloadTask> taskList) {
    final groupKey = '${first.vodId}_${first.siteUrl}';

    return Obx(() {
      final isExpanded = ctrl.expandedGroups.contains(groupKey);
      final completedCount = taskList.where((t) => t.status == DownloadStatus.completed).length;
      final activeCount = taskList.where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.merging || t.status == DownloadStatus.pending).length;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 影片标题行（点击展开/折叠）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (ctrl.expandedGroups.contains(groupKey)) {
                  ctrl.expandedGroups.remove(groupKey);
                } else {
                  ctrl.expandedGroups.add(groupKey);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    // 封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 54,
                        child: first.vodPic.isNotEmpty
                            ? CachedNetworkImage(imageUrl: first.vodPic, fit: BoxFit.cover, errorWidget: (_, _, _) => _placeholder())
                            : _placeholder(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(first.vodName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            activeCount > 0
                                ? '共${taskList.length}集 下载中$activeCount集'
                                : completedCount == taskList.length
                                    ? '共${taskList.length}集 全部完成'
                                    : '共${taskList.length}集 已完成$completedCount集',
                            style: TextStyle(
                              color: activeCount > 0 ? const Color(0xFFE50914) : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white38,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            // 每集下载状态（展开时显示）
            if (isExpanded) ...taskList.map((task) => _buildTaskItem(context, ctrl, task)),
            if (isExpanded) const SizedBox(height: 4),
          ],
        ),
      );
    });
  }

  Widget _buildTaskItem(BuildContext context, DownloadController ctrl, DownloadTask task) {
    return Obx(() {
      // 重新读取以获取最新状态
      final t = ctrl.tasks[task.id];
      if (t == null) return const SizedBox.shrink();

      return InkWell(
        onTap: t.status == DownloadStatus.completed ? () => _playLocal(t) : null,
        onLongPress: () => _showDeleteDialog(context, ctrl, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 状态图标
              _statusIcon(t),
              const SizedBox(width: 10),
              // 集名
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.episodeName, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (t.status == DownloadStatus.downloading || t.status == DownloadStatus.merging)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: t.progress,
                                minHeight: 3,
                                backgroundColor: const Color(0xFF2A2A2A),
                                valueColor: AlwaysStoppedAnimation(
                                  t.status == DownloadStatus.merging ? Colors.orangeAccent : const Color(0xFFE50914),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t.status == DownloadStatus.merging
                                  ? '合并中...'
                                  : t.totalSegments > 0
                                      ? '${(t.progress * 100).toInt()}%  ${t.downloadedSegments}/${t.totalSegments}片'
                                      : '${(t.progress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white30, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    if (t.status == DownloadStatus.failed && t.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('下载失败', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 进度文字 / 操作按钮
              _actionButton(ctrl, t),
            ],
          ),
        ),
      );
    });
  }

  Widget _statusIcon(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(value: task.progress, strokeWidth: 2, color: const Color(0xFFE50914)),
        );
      case DownloadStatus.merging:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
        );
      case DownloadStatus.paused:
        return const Icon(Icons.pause_circle_outline, color: Colors.white38, size: 20);
      case DownloadStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.redAccent, size: 20);
      case DownloadStatus.pending:
        return const Icon(Icons.schedule, color: Colors.white24, size: 20);
    }
  }

  Widget _actionButton(DownloadController ctrl, DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return GestureDetector(
          onTap: () => ctrl.pauseTask(task.id),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.pause, color: Colors.white54, size: 20),
          ),
        );
      case DownloadStatus.paused:
        return GestureDetector(
          onTap: () => ctrl.resumeTask(task.id),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.play_arrow, color: Colors.white54, size: 20),
          ),
        );
      case DownloadStatus.failed:
        return GestureDetector(
          onTap: () => ctrl.resumeTask(task.id),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.refresh, color: Colors.white54, size: 20),
          ),
        );
      case DownloadStatus.completed:
        return const Text('已完成', style: TextStyle(color: Colors.white24, fontSize: 11));
      case DownloadStatus.merging:
        return const Text('合并中', style: TextStyle(color: Colors.orangeAccent, fontSize: 11));
      case DownloadStatus.pending:
        return const Text('等待中', style: TextStyle(color: Colors.white24, fontSize: 11));
    }
  }

  void _playLocal(DownloadTask task) {
    if (task.savePath.isNotEmpty && File(task.savePath).existsSync()) {
      final ctrl = Get.find<DownloadController>();
      final groupKey = '${task.vodId}_${task.siteUrl}';
      final allTasks = ctrl.groupedTasks[groupKey] ?? [];
      final completedTasks = allTasks
          .where((t) => t.status == DownloadStatus.completed && t.savePath.isNotEmpty)
          .toList();

      final episodes = completedTasks
          .map((t) => {'name': t.episodeName, 'url': t.savePath})
          .toList();
      final epIndex = completedTasks.indexWhere((t) => t.id == task.id);

      Get.toNamed('/player', arguments: {
        'url': task.savePath,
        'title': '${task.vodName} - ${task.episodeName}',
        'vod_name': task.vodName,
        'vod_id': task.vodId,
        'site_url': task.siteUrl,
        'is_local': true,
        'ep_index': epIndex >= 0 ? epIndex : 0,
        'episodes': episodes,
      });
    }
  }

  void _showDeleteDialog(BuildContext context, DownloadController ctrl, DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('删除下载', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('确认删除「${task.episodeName}」?', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.deleteTask(task.id);
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, DownloadController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('清空下载', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('确认清空所有已完成的下载?', style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final completed = ctrl.tasks.values.where((t) => t.status == DownloadStatus.completed).map((t) => t.id).toList();
              for (final id in completed) {
                ctrl.deleteTask(id);
              }
            },
            child: const Text('清空', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 16)),
    );
  }
}
