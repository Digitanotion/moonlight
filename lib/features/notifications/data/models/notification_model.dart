class NotificationModel {
  final String id; // Changed from int to String (UUID)
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Extract the nested data object
    final data = json['data'] as Map<String, dynamic>? ?? {};

    return NotificationModel(
      id: json['id']?.toString() ?? '', // This is a UUID string, not int
      title: data['title']?.toString() ?? '', // From nested data
      body: data['body']?.toString() ?? '', // From nested data
      isRead: json['read_at'] != null,
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel.fromJson(map);
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
