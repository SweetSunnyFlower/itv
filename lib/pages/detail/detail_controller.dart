import 'package:get/get.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/api_service.dart';
import '../../app/services/collection_controller.dart';
import '../site/site_controller.dart';

class DetailController extends GetxController {
  final _api = ApiService();
  final _collection = Get.find<CollectionController>();
  final siteCtrl = Get.find<SiteController>();

  final vod = Rxn<VodModel>();
  final isLoading = true.obs;
  final currentRoute = ''.obs;
  final isFavorite = false.obs;

  late int vodId;

  @override
  void onInit() {
    super.onInit();
    vodId = Get.arguments['vod_id'];
    loadDetail();
  }

  Future<void> loadDetail() async {
    isLoading.value = true;
    final url = siteCtrl.currentSite.url;
    final result = await _api.getVodDetail(url, vodId);
    vod.value = result;
    if (result != null) {
      final routes = result.playRoutes;
      if (routes.isNotEmpty) {
        final m3u8Route = routes.keys.toList().firstWhereOrNull(
          (r) => r.toLowerCase().contains('m3u8'),
        );
        currentRoute.value = m3u8Route ?? routes.keys.first;
      }
      isFavorite.value = _collection.isFavorite(vodId, url);
      _collection.addHistory({
        'vod_id': result.vodId,
        'vod_name': result.vodName,
        'vod_pic': result.vodPic,
        'vod_remarks': result.vodRemarks,
        'site_url': url,
        'site_name': siteCtrl.currentSite.name,
      });
    }
    isLoading.value = false;
  }

  void switchRoute(String route) {
    currentRoute.value = route;
  }

  void toggleFavorite() {
    final url = siteCtrl.currentSite.url;
    if (isFavorite.value) {
      _collection.removeFavorite(vodId, url);
    } else {
      final v = vod.value!;
      _collection.addFavorite({
        'vod_id': v.vodId,
        'vod_name': v.vodName,
        'vod_pic': v.vodPic,
        'vod_remarks': v.vodRemarks,
        'site_url': url,
        'site_name': siteCtrl.currentSite.name,
      });
    }
    isFavorite.value = !isFavorite.value;
  }

  List<PlayItem> get currentEpisodes {
    final v = vod.value;
    if (v == null || currentRoute.isEmpty) return [];
    return v.playRoutes[currentRoute.value] ?? [];
  }
}
