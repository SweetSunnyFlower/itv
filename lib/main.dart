import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'app/routes/app_pages.dart';
import 'utils/responsive.dart';
import 'utils/tv_detector.dart';
import 'pages/site/site_controller.dart';
import 'pages/home/home_page.dart';
import 'pages/home/home_controller.dart';
import 'pages/category/category_page.dart';
import 'pages/rank/rank_page.dart';
import 'pages/live/live_page.dart';
import 'pages/mine/mine_page.dart';
import 'app/services/collection_controller.dart';
import 'app/services/download_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await GetStorage.init();
  await initTVDetection();
  Get.put(SiteController(), permanent: true);
  Get.put(CollectionController(), permanent: true);
  Get.put(DownloadController(), permanent: true);
  Get.put(HomeController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Voir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF141414),
        ),
      ),
      getPages: AppPages.pages,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _countdown = 2;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();

    // 弹跳动画
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();

    // 淡出动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(_fadeController);

    // 倒计时
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_skipped) return;
      if (mounted && _countdown > 1) {
        setState(() => _countdown--);
        _startCountdown();
      } else if (_countdown == 1) {
        _goToMain();
      }
    });
  }

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    _goToMain();
  }

  void _goToMain() async {
    await _fadeController.forward();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainPage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 弹跳 icon
            Center(
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnimation.value * 300),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 120,
                  height: 120,
                ),
              ),
            ),
            // 右上角跳过按钮
            Positioned(
              top: 50,
              right: 20,
              child: Focus(
                autofocus: isAndroidTV,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                    _skip();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '跳过 $_countdown 秒',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final currentIndex = 0.obs;
  StreamSubscription? _accelSub;
  DateTime _lastShake = DateTime(2000);
  static const _shakeThreshold = 40.0;

  DateTime? _lastPressedAt; // 记录上次按返回键的时间

  final pages = [
    const HomePage(),
    const CategoryPage(),
    const LivePage(),
    const RankPage(),
    const MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    if (!shouldDisableSensors) {
      _accelSub = accelerometerEventStream().listen((event) {
        final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (magnitude > _shakeThreshold) {
          final now = DateTime.now();
          if (now.difference(_lastShake).inMilliseconds > 1500) {
            _lastShake = now;
            Get.toNamed('/site');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isDesktopPlatform,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isDesktopPlatform) return;

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          Get.snackbar(
            '',
            '再按一次退出应用',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            colorText: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 14),
            borderRadius: 20,
            titleText: const SizedBox.shrink(),
          );
        } else {
          exit(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= Breakpoints.tablet;
          if (isWide) {
            return Obx(() => Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: currentIndex.value,
                    onDestinationSelected: (i) => currentIndex.value = i,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: const Color(0xFF1A1A1A),
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    unselectedIconTheme: const IconThemeData(color: Colors.white30),
                    selectedLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    unselectedLabelTextStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                    indicatorColor: const Color(0xFFE50914).withValues(alpha: 0.2),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.home_filled), label: Text('首页')),
                      NavigationRailDestination(icon: Icon(Icons.apps_outlined), label: Text('分类')),
                      NavigationRailDestination(icon: Icon(Icons.live_tv_outlined), label: Text('TV')),
                      NavigationRailDestination(icon: Icon(Icons.leaderboard_outlined), label: Text('排行')),
                      NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('我的')),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 0.5, color: Color(0xFF2A2A2A)),
                  Expanded(
                    child: IndexedStack(
                      index: currentIndex.value,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ));
          }
          return Obx(() => Scaffold(
            body: IndexedStack(
              index: currentIndex.value,
              children: pages,
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex.value,
                onTap: (i) => currentIndex.value = i,
                backgroundColor: const Color(0xFF141414),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white30,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '首页'),
                  BottomNavigationBarItem(icon: Icon(Icons.apps_outlined), label: '分类'),
                  BottomNavigationBarItem(icon: Icon(Icons.live_tv_outlined), label: 'TV'),
                  BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined), label: '排行'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '我的'),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }
}
