# ITV - 视频点播应用

一款基于 Flutter 开发的跨平台视频点播应用，支持 Android、iOS、Web、macOS、Windows 和 Linux 平台。

## 功能特性

- **首页推荐** - 浏览热门视频内容
- **分类浏览** - 按类型、地区、年份筛选视频
- **排行榜** - 查看热门视频排行
- **视频搜索** - 关键词搜索视频资源
- **视频详情** - 查看影片信息、演员、导演、简介等
- **多线路播放** - 支持多播放源切换
- **收藏功能** - 收藏喜欢的影片
- **观看历史** - 记录观看进度
- **离线下载** - 支持视频离线缓存
- **DLNA 投屏** - 投屏到电视等设备
- **多站点支持** - 可切换不同视频源站点
- **摇一摇切换站点** - 摇动手机快速切换站点

## 技术栈

- **Flutter** `^3.10.7` - 跨平台 UI 框架
- **GetX** - 状态管理、路由管理
- **media_kit** - 视频播放器
- **Dio** - 网络请求
- **GetStorage** - 本地数据存储
- **CachedNetworkImage** - 图片缓存

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── app/
│   ├── models/              # 数据模型
│   │   ├── vod_model.dart   # 视频数据模型
│   │   ├── site_model.dart  # 站点模型
│   │   └── download_model.dart
│   ├── routes/              # 路由配置
│   │   └── app_pages.dart
│   └── services/            # 服务层
│       ├── api_service.dart      # API 接口服务
│       ├── storage_service.dart  # 存储服务
│       ├── dlna_service.dart     # DLNA 投屏服务
│       ├── collection_controller.dart
│       └── download_controller.dart
├── pages/                   # 页面
│   ├── home/               # 首页
│   ├── category/           # 分类页
│   ├── rank/               # 排行榜
│   ├── search/             # 搜索页
│   ├── detail/             # 详情页
│   ├── player/             # 播放器
│   ├── favorites/          # 收藏页
│   ├── history/            # 历史记录
│   ├── download/           # 下载管理
│   ├── site/               # 站点设置
│   └── short_drama/        # 短剧页
└── widgets/                # 公共组件
    └── vod_card.dart       # 视频卡片组件
```

## 开始使用

### 环境要求

- Flutter SDK `^3.10.7`
- Dart SDK `^3.10.7`

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# 开发模式
flutter run

# 指定平台运行
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### 构建发布版

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

## API 接口

应用使用标准的视频点播 API 接口，支持以下接口格式：

| 参数 | 说明 |
|------|------|
| `ac=detail` | 获取视频详情列表 |
| `ac=list` | 获取分类列表 |
| `ac=rank` | 获取排行榜 |
| `ac=filter` | 分类筛选 |
| `wd` | 搜索关键词 |
| `t` | 分类ID |
| `pg` | 页码 |
| `ids` | 视频ID |

## 平台支持

| 平台 | 状态 |
|------|------|
| Android | ✅ 支持 |
| iOS | ✅ 支持 |
| Web | ✅ 支持 |
| macOS | ✅ 支持 |
| Windows | ✅ 支持 |
| Linux | ✅ 支持 |

## 许可证

本项目仅供学习交流使用。

```
flutter pub run flutter_launcher_icons:main
```

https://freetv.fun/zh-hans/playlist