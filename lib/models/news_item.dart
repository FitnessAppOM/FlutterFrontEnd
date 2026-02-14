class NewsItem {
  final int id;
  final String title;
  final String subtitle;
  final String content;
  final String contentUrl;
  final String tag;
  final DateTime? createdAt;

  const NewsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.contentUrl,
    required this.tag,
    this.createdAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json["id"] is int ? json["id"] as int : int.tryParse("${json["id"]}") ?? 0,
      title: (json["title"] ?? "").toString(),
      subtitle: (json["subtitle"] ?? "").toString(),
      content: (json["content"] ?? json["body"] ?? "").toString(),
      contentUrl: (json["content_url"] ?? "").toString(),
      tag: (json["tag"] ?? "").toString(),
      createdAt: DateTime.tryParse("${json["created_at"] ?? ""}"),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "subtitle": subtitle,
      "content": content,
      "content_url": contentUrl,
      "tag": tag,
      "created_at": createdAt?.toIso8601String(),
    };
  }
}
