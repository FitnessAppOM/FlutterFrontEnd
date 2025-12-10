class NewsItem {
  final int id;
  final String title;
  final String subtitle;
  final String tag;
  final DateTime? createdAt;

  const NewsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.createdAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json["id"] is int ? json["id"] as int : int.tryParse("${json["id"]}") ?? 0,
      title: (json["title"] ?? "").toString(),
      subtitle: (json["subtitle"] ?? "").toString(),
      tag: (json["tag"] ?? "").toString(),
      createdAt: DateTime.tryParse("${json["created_at"] ?? ""}"),
    );
  }
}
