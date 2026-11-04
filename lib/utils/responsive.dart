import 'dart:io';
import 'tv_detector.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double wide = 1600;
}

enum DeviceType { mobile, tablet, desktop }

DeviceType getDeviceType(double width) {
  if (width >= Breakpoints.desktop) return DeviceType.desktop;
  if (width >= Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.mobile;
}

bool get isDesktopPlatform {
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

bool get shouldDisableSensors => isDesktopPlatform || isAndroidTV;

int responsiveGridCount(double width, {int mobileCount = 3, int tabletCount = 4, int desktopCount = 6}) {
  final type = getDeviceType(width);
  switch (type) {
    case DeviceType.desktop:
      return desktopCount;
    case DeviceType.tablet:
      return tabletCount;
    case DeviceType.mobile:
      return mobileCount;
  }
}

int responsiveEpisodeCount(double width) {
  if (width >= Breakpoints.wide) return 10;
  if (width >= Breakpoints.desktop) return 8;
  if (width >= Breakpoints.tablet) return 6;
  return 4;
}

double responsiveBannerHeight(double width) {
  if (width >= Breakpoints.desktop) return 500;
  if (width >= Breakpoints.tablet) return 460;
  return 420;
}
