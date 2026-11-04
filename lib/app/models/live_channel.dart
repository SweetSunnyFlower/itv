/// 直播分类模型
class LiveCategory {
  final String name;
  final String m3uUrl;

  LiveCategory({
    required this.name,
    required this.m3uUrl,
  });
}

/// 直播频道模型
class LiveChannel {
  final String name;
  final String url;
  final String logo;
  final String group;
  final String tvgId;
  final String tvgName;
  final String country;
  final String language;

  LiveChannel({
    required this.name,
    required this.url,
    this.logo = '',
    this.group = '',
    this.tvgId = '',
    this.tvgName = '',
    this.country = '',
    this.language = '',
  });

  factory LiveChannel.fromM3uLine(String extInfLine, String urlLine) {
    String tvgName = '';
    String tvgId = '';
    String country = '';
    String language = '';
    String logo = '';
    String group = '';
    String name = '';

    final tvgNameMatch = RegExp(r'tvg-name="([^"]*)"').firstMatch(extInfLine);
    if (tvgNameMatch != null) tvgName = tvgNameMatch.group(1) ?? '';

    final tvgIdMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(extInfLine);
    if (tvgIdMatch != null) tvgId = tvgIdMatch.group(1) ?? '';

    final countryMatch = RegExp(r'tvg-country="([^"]*)"').firstMatch(extInfLine);
    if (countryMatch != null) country = countryMatch.group(1) ?? '';

    final languageMatch = RegExp(r'tvg-language="([^"]*)"').firstMatch(extInfLine);
    if (languageMatch != null) language = languageMatch.group(1) ?? '';

    final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(extInfLine);
    if (logoMatch != null) logo = logoMatch.group(1) ?? '';

    final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(extInfLine);
    if (groupMatch != null) group = groupMatch.group(1) ?? '';

    final nameMatch = RegExp(r',(.+)$').firstMatch(extInfLine);
    if (nameMatch != null) name = nameMatch.group(1)?.trim() ?? '';

    return LiveChannel(
      name: name,
      url: urlLine.trim(),
      logo: logo,
      group: group,
      tvgId: tvgId,
      tvgName: tvgName,
      country: country,
      language: language,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'logo': logo,
      'group': group,
      'tvgId': tvgId,
      'tvgName': tvgName,
      'country': country,
      'language': language,
    };
  }

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      logo: json['logo'] ?? '',
      group: json['group'] ?? '',
      tvgId: json['tvgId'] ?? '',
      tvgName: json['tvgName'] ?? '',
      country: json['country'] ?? '',
      language: json['language'] ?? '',
    );
  }
}
