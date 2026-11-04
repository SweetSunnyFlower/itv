enum DownloadStatus { pending, downloading, paused, merging, completed, failed }

class DownloadTask {
  final String id; // vodId_epIndex 唯一标识
  final int vodId;
  final String vodName;
  final String vodPic;
  final String episodeName;
  final String url; // 原始视频URL（m3u8或mp4）
  final String siteUrl;
  String savePath; // 最终保存路径
  DownloadStatus status;
  double progress; // 0.0 ~ 1.0
  int totalSegments; // m3u8 总分片数
  int downloadedSegments; // 已下载分片数
  String? error;

  DownloadTask({
    required this.id,
    required this.vodId,
    required this.vodName,
    required this.vodPic,
    required this.episodeName,
    required this.url,
    required this.siteUrl,
    this.savePath = '',
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vod_id': vodId,
    'vod_name': vodName,
    'vod_pic': vodPic,
    'episode_name': episodeName,
    'url': url,
    'site_url': siteUrl,
    'save_path': savePath,
    'status': status.index,
    'progress': progress,
    'total_segments': totalSegments,
    'downloaded_segments': downloadedSegments,
    'error': error,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'] ?? '',
    vodId: json['vod_id'] ?? 0,
    vodName: json['vod_name'] ?? '',
    vodPic: json['vod_pic'] ?? '',
    episodeName: json['episode_name'] ?? '',
    url: json['url'] ?? '',
    siteUrl: json['site_url'] ?? '',
    savePath: json['save_path'] ?? '',
    status: DownloadStatus.values[json['status'] ?? 0],
    progress: (json['progress'] ?? 0.0).toDouble(),
    totalSegments: json['total_segments'] ?? 0,
    downloadedSegments: json['downloaded_segments'] ?? 0,
    error: json['error'],
  );
}
