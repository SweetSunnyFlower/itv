import 'package:get/get.dart';
import '../../pages/home/home_page.dart';
import '../../pages/home/home_controller.dart';
import '../../pages/search/search_page.dart';
import '../../pages/detail/detail_page.dart';
import '../../pages/player/player_page.dart';
import '../../pages/short_drama/short_drama_page.dart';
import '../../pages/site/site_page.dart';
import '../../pages/favorites/favorites_page.dart';
import '../../pages/history/history_page.dart';
import '../../pages/rank/rank_page.dart';
import '../../pages/category/category_page.dart';
import '../../pages/download/download_page.dart';
import '../../pages/live/live_page.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: '/home',
      page: () => const HomePage(),
      binding: BindingsBuilder(() {
        Get.put(HomeController());
      }),
    ),
    GetPage(name: '/search', page: () => const SearchPage()),
    GetPage(name: '/detail', page: () => const DetailPage()),
    GetPage(name: '/player', page: () => const PlayerPage()),
    GetPage(name: '/short_drama', page: () => const ShortDramaPage()),
    GetPage(name: '/site', page: () => const SitePage()),
    GetPage(name: '/favorites', page: () => const FavoritesPage()),
    GetPage(name: '/history', page: () => const HistoryPage()),
    GetPage(name: '/rank', page: () => const RankPage()),
    GetPage(name: '/category', page: () => const CategoryPage()),
    GetPage(name: '/download', page: () => const DownloadPage()),
    GetPage(name: '/live', page: () => const LivePage()),
  ];
}
