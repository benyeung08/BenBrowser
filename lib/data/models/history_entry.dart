/// 历史记录条目
class HistoryEntry {
  final String id;
  final String title;
  final String url;
  final DateTime visitedAt;

  const HistoryEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  factory HistoryEntry.create({required String title, required String url}) =>
      HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        url: url,
        visitedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'visitedAt': visitedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
