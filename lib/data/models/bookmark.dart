/// 书签条目
class Bookmark {
  final String id;
  final String title;
  final String url;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  factory Bookmark.create({required String title, required String url}) => Bookmark(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        url: url,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
