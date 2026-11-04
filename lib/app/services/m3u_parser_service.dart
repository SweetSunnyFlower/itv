import 'package:dio/dio.dart';
import '../../app/models/live_channel.dart';

/// 直播源服务
class LiveSourceService {
  static final Dio _dio = Dio();

  /// 分类列表页面
  static const String playlistPageUrl = 'https://freetv.fun/zh-hans/playlist';

  /// 主播放列表
  static const String mainPlaylistUrl = 'https://t.freetv.fun/m3u/playlist.m3u';

  /// 成人内容关键词（需要过滤）
  static const _adultKeywords = [
    'adult', 'porn', 'xxx', 'sex', 'erotic', '18+',
    '成人', '色情', '黄片', '性爱', '情色',
  ];

  /// 检查是否包含成人内容关键词
  static bool _containsAdultContent(String text) {
    final lowerText = text.toLowerCase();
    return _adultKeywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }

  /// 从 HTML 页面解析分类列表
  static Future<List<LiveCategory>> fetchCategories() async {
    try {
      final response = await _dio.get(playlistPageUrl);
      final html = response.data.toString();
      return _parseCategories(html);
    } catch (e) {
      rethrow;
    }
  }

  /// 解析 HTML 获取分类
  static List<LiveCategory> _parseCategories(String html) {
    final List<LiveCategory> categories = [];

    // 使用正则匹配分类卡片
    final cardRegex = RegExp(
      r'<h3 class="playlist-card-title">([^<]+)</h3>.*?data-source-url="https://t\.freetv\.fun/m3u/([^.]+)\.m3u"',
      dotAll: true,
    );

    for (final match in cardRegex.allMatches(html)) {
      final name = match.group(1)?.trim() ?? '';
      final id = match.group(2) ?? '';
      // 过滤成人内容
      if (name.isNotEmpty && id.isNotEmpty && !_containsAdultContent(name)) {
        categories.add(LiveCategory(
          name: name,
          m3uUrl: 'https://t.freetv.fun/m3u/$id.m3u',
        ));
      }
    }

    return categories;
  }

  /// 从网络获取并解析 M3U
  static Future<List<LiveChannel>> fetchChannels(String m3uUrl) async {
    try {
      final response = await _dio.get(m3uUrl);
      return parseM3uContent(response.data.toString());
    } catch (e) {
      rethrow;
    }
  }

  /// 解析 M3U 内容
  static List<LiveChannel> parseM3uContent(String content) {
    final List<LiveChannel> channels = [];
    final lines = content.split('\n');

    String? currentExtInf;

    for (var line in lines) {
      line = line.trim();

      if (line.isEmpty || line.startsWith('#This') || line.startsWith('#freetv') ||
          line.startsWith('#If') || line.startsWith('#http') || line.startsWith('#Generated') ||
          line.startsWith('#這個') || line.startsWith('#以下的') ||
          line.startsWith('#如果您') || line.startsWith('#下載')) {
        continue;
      }

      if (line.startsWith('#EXTM3U')) continue;

      if (line.startsWith('#EXTINF')) {
        currentExtInf = line;
        continue;
      }

      if (line.startsWith('http') && currentExtInf != null) {
        try {
          final channel = LiveChannel.fromM3uLine(currentExtInf, line);
          // 过滤成人内容
          if (channel.name.isNotEmpty && channel.url.isNotEmpty &&
              !_containsAdultContent(channel.name) &&
              !_containsAdultContent(channel.group)) {
            channels.add(channel);
          }
        } catch (e) {
          // 解析失败，跳过
        }
        currentExtInf = null;
      }
    }

    return channels;
  }

  /// 按分组整理频道
  static Map<String, List<LiveChannel>> groupChannels(List<LiveChannel> channels) {
    final Map<String, List<LiveChannel>> grouped = {};

    for (var channel in channels) {
      final group = channel.group.isEmpty ? '未分类' : channel.group;
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(channel);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final sortedMap = <String, List<LiveChannel>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }

    return sortedMap;
  }

  /// 搜索频道
  static List<LiveChannel> searchChannels(List<LiveChannel> channels, String keyword) {
    if (keyword.isEmpty) return channels;

    final lowerKeyword = keyword.toLowerCase();
    return channels.where((channel) {
      return channel.name.toLowerCase().contains(lowerKeyword) ||
          channel.group.toLowerCase().contains(lowerKeyword) ||
          channel.country.toLowerCase().contains(lowerKeyword);
    }).toList();
  }
}
