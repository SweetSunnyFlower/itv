class VodCategory {
  int typeId;
  int typePid;
  String typeName;

  VodCategory({required this.typeId, this.typePid = 0, required this.typeName});

  factory VodCategory.fromJson(Map<String, dynamic> json) {
    return VodCategory(
      typeId: json['type_id'] ?? 0,
      typePid: json['type_pid'] ?? 0,
      typeName: json['type_name'] ?? '',
    );
  }
}

class VodModel {
  int vodId;
  String vodName;
  String vodPic;
  String vodRemarks;
  int typeId;
  String typeName;
  String vodYear;
  String vodArea;
  String vodLang;
  String vodActor;
  String vodDirector;
  String vodContent;
  String vodPlayFrom;
  String vodPlayUrl;

  VodModel({
    required this.vodId,
    required this.vodName,
    this.vodPic = '',
    this.vodRemarks = '',
    this.typeId = 0,
    this.typeName = '',
    this.vodYear = '',
    this.vodArea = '',
    this.vodLang = '',
    this.vodActor = '',
    this.vodDirector = '',
    this.vodContent = '',
    this.vodPlayFrom = '',
    this.vodPlayUrl = '',
  });

  factory VodModel.fromJson(Map<String, dynamic> json) {
    return VodModel(
      vodId: json['vod_id'] ?? 0,
      vodName: json['vod_name'] ?? '',
      vodPic: json['vod_pic'] ?? '',
      vodRemarks: json['vod_remarks'] ?? '',
      typeId: json['type_id'] ?? 0,
      typeName: json['type_name'] ?? '',
      vodYear: json['vod_year']?.toString() ?? '',
      vodArea: json['vod_area'] ?? '',
      vodLang: json['vod_lang'] ?? '',
      vodActor: json['vod_actor'] ?? '',
      vodDirector: json['vod_director'] ?? '',
      vodContent: json['vod_content'] ?? '',
      vodPlayFrom: json['vod_play_from'] ?? '',
      vodPlayUrl: json['vod_play_url'] ?? '',
    );
  }

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.flv') ||
        lower.contains('.mkv') ||
        lower.contains('.ts') ||
        lower.contains('.avi') ||
        lower.contains('/video/') ||
        lower.contains('/m3u8/');
  }

  /// 解析播放线路，返回 {线路名: [{集名, url}]}
  /// 自动过滤掉非视频地址的线路
  Map<String, List<PlayItem>> get playRoutes {
    if (vodPlayFrom.isEmpty || vodPlayUrl.isEmpty) return {};
    final routes = <String, List<PlayItem>>{};
    final froms = vodPlayFrom.split(r'$$$');
    final urls = vodPlayUrl.split(r'$$$');
    for (var i = 0; i < froms.length && i < urls.length; i++) {
      final routeName = froms[i].trim();
      final episodes = urls[i].split('#').where((e) => e.contains(r'$')).map((e) {
        final parts = e.split(r'$');
        return PlayItem(name: parts[0], url: parts.length > 1 ? parts[1] : '');
      }).where((e) => e.url.isNotEmpty && _isVideoUrl(e.url)).toList();
      if (episodes.isNotEmpty) {
        routes[routeName] = episodes;
      }
    }
    return routes;
  }
}

class PlayItem {
  final String name;
  final String url;
  PlayItem({required this.name, required this.url});
}

class VodListResponse {
  int code;
  int page;
  int pagecount;
  int total;
  List<VodModel> list;
  List<VodCategory> categories;

  VodListResponse({
    this.code = 0,
    this.page = 1,
    this.pagecount = 1,
    this.total = 0,
    this.list = const [],
    this.categories = const [],
  });

  factory VodListResponse.fromJson(Map<String, dynamic> json) {
    return VodListResponse(
      code: json['code'] ?? 0,
      page: int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      pagecount: int.tryParse(json['pagecount']?.toString() ?? '1') ?? 1,
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      list: (json['list'] as List?)?.map((e) => VodModel.fromJson(e)).toList() ?? [],
      categories: (json['class'] as List?)?.map((e) => VodCategory.fromJson(e)).toList() ?? [],
    );
  }
}
