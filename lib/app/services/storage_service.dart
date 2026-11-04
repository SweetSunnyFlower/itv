import 'package:get_storage/get_storage.dart';
import '../models/site_model.dart';

class StorageService {
  final _box = GetStorage();

  static const _sitesKey = 'sites';
  static const _currentSiteKey = 'current_site';
  static const _favoritesKey = 'favorites';
  static const _historyKey = 'history';
  static const _progressPrefix = 'progress_';

  static final defaultSites = [
    SiteModel(url: 'http://caiji.dyttzyapi.com', name: '电影天堂资源', detail: 'http://caiji.dyttzyapi.com', isDefault: true),
    SiteModel(url: 'https://dbzy.tv', name: '豆瓣资源', detail: 'https://dbzy.tv'),
    SiteModel(url: 'https://mtzy.me', name: '茅台资源', detail: 'https://mtzy.me'),
    SiteModel(url: 'http://jinyingzy.com', name: '金鹰资源', detail: 'http://jinyingzy.com'),
    SiteModel(url: 'https://cj.rycjapi.com', name: '如意资源'),
    SiteModel(url: 'https://bfzyapi.com', name: '暴风资源'),
    SiteModel(url: 'https://tyyszy.com', name: '天涯资源'),
    SiteModel(url: 'https://zy.xiaomaomi.cc', name: '小猫咪资源'),
    SiteModel(url: 'http://ffzy5.tv', name: '非凡影视', detail: 'http://ffzy5.tv'),
    SiteModel(url: 'https://json.heimuer.xyz', name: '黑木耳', detail: 'https://heimuer.tv'),
    SiteModel(url: 'https://360zy.com', name: '360资源'),
    SiteModel(url: 'https://wolongzyw.com', name: '卧龙资源'),
    SiteModel(url: 'https://cjhwba.com', name: '华为吧资源'),
    SiteModel(url: 'https://jszyapi.com', name: '极速资源', detail: 'https://jszyapi.com'),
    SiteModel(url: 'https://dbzy.com', name: '豆瓣资源'),
    SiteModel(url: 'https://mozhuazy.com', name: '魔爪资源'),
    SiteModel(url: 'https://www.mdzyapi.com', name: '魔都资源'),
    SiteModel(url: 'https://api.zuidapi.com', name: '最大资源'),
    SiteModel(url: 'https://m3u8.apiyhzy.com', name: '樱花资源'),
    SiteModel(url: 'https://api.apibdzy.com', name: '百度云资源'),
    SiteModel(url: 'https://api.wujinapi.me', name: '无尽资源'),
    SiteModel(url: 'https://wwzy.tv', name: '旺旺短剧'),
    SiteModel(url: 'https://ikunzyapi.com', name: 'iKun资源'),
    // 以下为隐藏站点
    // SiteModel(url: 'https://www.ckzy1.com', name: 'CK资源', isAdult: true),
    // SiteModel(url: 'https://api.bwzym3u8.com', name: '百万资源', isAdult: true),
    // SiteModel(url: 'https://gayzy.tv', name: 'X资源', detail: 'https://gayzy.tv', isAdult: true),
    // SiteModel(url: 'https://kbzy1.com', name: '快播资源', detail: 'https://kbzy1.com', isAdult: true),
    // SiteModel(url: 'https://api.souavzy.vip', name: 'souav资源', isAdult: true),
    // SiteModel(url: 'https://155api.com', name: '155资源', isAdult: true),
    // SiteModel(url: 'https://apilsbzy1.com', name: 'lsb资源', isAdult: true),
    // SiteModel(url: 'https://hsckzy.vip', name: '黄色仓库', detail: 'https://hsckzy.vip', isAdult: true),
    // SiteModel(url: 'https://yutuzy10.com', name: '玉兔资源', isAdult: true),
  ];

  /// 获取站点列表
  List<SiteModel> getSites() {
    final data = _box.read<List>(_sitesKey);
    if (data == null) return List.from(defaultSites);
    return data.map((e) => SiteModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// 保存站点列表
  void saveSites(List<SiteModel> sites) {
    _box.write(_sitesKey, sites.map((e) => e.toJson()).toList());
  }

  /// 获取当前选中站点索引
  int getCurrentSiteIndex() => _box.read<int>(_currentSiteKey) ?? 0;

  /// 保存当前选中站点索引
  void saveCurrentSiteIndex(int index) => _box.write(_currentSiteKey, index);

  /// 收藏相关
  List<Map<String, dynamic>> getFavorites() {
    final data = _box.read<List>(_favoritesKey);
    return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  void saveFavorite(Map<String, dynamic> item) {
    final list = getFavorites();
    if (!list.any((e) => e['vod_id'] == item['vod_id'] && e['site_url'] == item['site_url'])) {
      list.insert(0, item);
      _box.write(_favoritesKey, list);
    }
  }

  void removeFavorite(int vodId, String siteUrl) {
    final list = getFavorites();
    list.removeWhere((e) => e['vod_id'] == vodId && e['site_url'] == siteUrl);
    _box.write(_favoritesKey, list);
  }

  bool isFavorite(int vodId, String siteUrl) {
    return getFavorites().any((e) => e['vod_id'] == vodId && e['site_url'] == siteUrl);
  }

  /// 历史记录相关
  List<Map<String, dynamic>> getHistory() {
    final data = _box.read<List>(_historyKey);
    return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  void addHistory(Map<String, dynamic> item) {
    final list = getHistory();
    list.removeWhere((e) => e['vod_id'] == item['vod_id'] && e['site_url'] == item['site_url']);
    list.insert(0, item);
    if (list.length > 100) list.removeLast();
    _box.write(_historyKey, list);
  }

  void clearHistory() => _box.write(_historyKey, []);

  /// 播放进度相关
  String _progressKey(int vodId, String siteUrl) => '$_progressPrefix${vodId}_$siteUrl';

  Map<String, dynamic>? getProgress(int vodId, String siteUrl) {
    return _box.read<Map<String, dynamic>>(_progressKey(vodId, siteUrl));
  }

  void saveProgress(int vodId, String siteUrl, Map<String, dynamic> data) {
    _box.write(_progressKey(vodId, siteUrl), data);
  }

  /// 直播收藏相关
  static const _liveFavoritesKey = 'live_favorites';

  List<Map<String, dynamic>> getLiveFavorites() {
    final data = _box.read<List>(_liveFavoritesKey);
    return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  void saveLiveFavorite(Map<String, dynamic> channel) {
    final list = getLiveFavorites();
    // 使用 url 作为唯一标识
    if (!list.any((e) => e['url'] == channel['url'])) {
      list.insert(0, channel);
      _box.write(_liveFavoritesKey, list);
    }
  }

  void removeLiveFavorite(String url) {
    final list = getLiveFavorites();
    list.removeWhere((e) => e['url'] == url);
    _box.write(_liveFavoritesKey, list);
  }

  bool isLiveFavorite(String url) {
    return getLiveFavorites().any((e) => e['url'] == url);
  }

  /// 搜索历史相关
  static const _searchHistoryKey = 'search_history';

  List<String> getSearchHistory() {
    final data = _box.read<List>(_searchHistoryKey);
    return data?.map((e) => e.toString()).toList() ?? [];
  }

  void addSearchHistory(String keyword) {
    if (keyword.trim().isEmpty) return;
    final list = getSearchHistory();
    list.remove(keyword);
    list.insert(0, keyword);
    if (list.length > 20) list.removeLast();
    _box.write(_searchHistoryKey, list);
  }

  void clearSearchHistory() => _box.write(_searchHistoryKey, []);
}
