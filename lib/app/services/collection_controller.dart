import 'package:get/get.dart';
import '../services/storage_service.dart';

class CollectionController extends GetxController {
  final _storage = StorageService();
  final favorites = <Map<String, dynamic>>[].obs;
  final history = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    favorites.value = _storage.getFavorites();
    history.value = _storage.getHistory();
  }

  void addFavorite(Map<String, dynamic> item) {
    _storage.saveFavorite(item);
    favorites.value = _storage.getFavorites();
  }

  void removeFavorite(int vodId, String siteUrl) {
    _storage.removeFavorite(vodId, siteUrl);
    favorites.value = _storage.getFavorites();
  }

  bool isFavorite(int vodId, String siteUrl) {
    return _storage.isFavorite(vodId, siteUrl);
  }

  void addHistory(Map<String, dynamic> item) {
    _storage.addHistory(item);
    history.value = _storage.getHistory();
  }

  void clearHistory() {
    _storage.clearHistory();
    history.value = [];
  }
}
