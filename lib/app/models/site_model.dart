class SiteModel {
  String url;
  String name;
  String detail;
  bool isDefault;
  bool isAdult;

  SiteModel({
    required this.url,
    required this.name,
    this.detail = '',
    this.isDefault = false,
    this.isAdult = false,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      url: json['url'] ?? '',
      name: json['name'] ?? '',
      detail: json['detail'] ?? '',
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
      isAdult: json['is_adult'] == 1 || json['is_adult'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      'detail': detail,
      'is_default': isDefault ? 1 : 0,
      'is_adult': isAdult ? 1 : 0,
    };
  }
}
