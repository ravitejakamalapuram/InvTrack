/// One short money-learning tip. Content only, never user data.
library;

class Tip {
  const Tip({required this.id, required this.title, required this.body});

  factory Tip.fromJson(Map<String, dynamic> json) => Tip(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  final String id;
  final String title;
  final String body;
}
