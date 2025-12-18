import 'package:equatable/equatable.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';

class ChatPaginated<T> extends Equatable {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String? nextPageUrl;
  final String? prevPageUrl;

  const ChatPaginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  bool get hasNextPage => nextPageUrl != null && nextPageUrl!.isNotEmpty;
  bool get hasPrevPage => prevPageUrl != null && prevPageUrl!.isNotEmpty;

  @override
  List<Object?> get props => [
    data,
    currentPage,
    lastPage,
    perPage,
    total,
    nextPageUrl,
    prevPageUrl,
  ];
}

// Specifically for messages
class PaginatedMessages extends ChatPaginated<Message> {
  const PaginatedMessages({
    required super.data,
    required super.currentPage,
    required super.lastPage,
    required super.perPage,
    required super.total,
    super.nextPageUrl,
    super.prevPageUrl,
  });

  factory PaginatedMessages.fromJson(Map<String, dynamic> json) {
    // Safely extract data list
    final dataList = json['data'] as List? ?? [];

    // Safely parse each message
    final messages = dataList.map((item) {
      try {
        if (item == null) return _createDefaultMessage();

        Map<String, dynamic>? itemMap;

        if (item is Map<String, dynamic>) {
          itemMap = item;
        } else if (item is Map) {
          itemMap = item.cast<String, dynamic>();
        } else {
          print('Unexpected item type: ${item.runtimeType}');
          return _createDefaultMessage();
        }

        return Message.fromJson(itemMap);
      } catch (e) {
        print('Error parsing message: $e');
        return _createDefaultMessage();
      }
    }).toList();

    // Extract pagination from root level (not from meta)
    final currentPage = _safeParseInt(json['current_page'], 1);
    final lastPage = _safeParseInt(json['last_page'], 1);
    final perPage = _safeParseInt(json['per_page'], 50);
    final total = _safeParseInt(json['total'], 0);

    // Extract next/prev URLs - links is an array, not a map!
    String? nextPageUrl;
    String? prevPageUrl;

    final links = json['links'] as List? ?? [];
    for (final link in links) {
      if (link is Map) {
        final label = link['label'] as String?;
        final url = link['url'] as String?;

        if (label?.contains('Next') == true && url != null) {
          nextPageUrl = url;
        } else if (label?.contains('Previous') == true && url != null) {
          prevPageUrl = url;
        }
      }
    }

    // Also check direct next_page_url and prev_page_url if available
    nextPageUrl ??= json['next_page_url'] as String?;
    prevPageUrl ??= json['prev_page_url'] as String?;

    return PaginatedMessages(
      data: messages,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
      nextPageUrl: nextPageUrl,
      prevPageUrl: prevPageUrl,
    );
  }

  static Message _createDefaultMessage() {
    return Message(
      uuid: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      body: 'Message unavailable',
      type: MessageType.text,
      sender: ChatUser(
        uuid: 'unknown',
        userSlug: 'unknown',
        fullName: 'Unknown User',
        avatarUrl: null,
      ),
      media: [],
      reactions: [],
      isEdited: false,
      createdAt: DateTime.now(),
      editedAt: null,
      replyToUuid: null,
    );
  }

  static int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    if (value is double) return value.toInt();
    return defaultValue;
  }
}

// For searching messages
class SearchMessagesResult extends ChatPaginated<Message> {
  const SearchMessagesResult({
    required super.data,
    required super.currentPage,
    required super.lastPage,
    required super.perPage,
    required super.total,
    super.nextPageUrl,
    super.prevPageUrl,
  });

  factory SearchMessagesResult.fromJson(Map<String, dynamic> json) {
    // Safely extract data list
    final dataList = json['data'] as List? ?? [];

    // Safely parse each message
    final messages = dataList.map((item) {
      try {
        if (item == null) return PaginatedMessages._createDefaultMessage();

        Map<String, dynamic>? itemMap;

        if (item is Map<String, dynamic>) {
          itemMap = item;
        } else if (item is Map) {
          itemMap = item.cast<String, dynamic>();
        } else {
          return PaginatedMessages._createDefaultMessage();
        }

        return Message.fromJson(itemMap);
      } catch (e) {
        print('Error parsing search message: $e');
        return PaginatedMessages._createDefaultMessage();
      }
    }).toList();

    // Extract pagination - check both formats
    int currentPage;
    int lastPage;
    int perPage;
    int total;

    if (json.containsKey('meta')) {
      // Has meta object
      final meta = json['meta'] as Map<String, dynamic>? ?? {};
      currentPage = PaginatedMessages._safeParseInt(meta['current_page'], 1);
      lastPage = PaginatedMessages._safeParseInt(meta['last_page'], 1);
      perPage = PaginatedMessages._safeParseInt(meta['per_page'], 50);
      total = PaginatedMessages._safeParseInt(meta['total'], 0);
    } else {
      // Direct pagination at root
      currentPage = PaginatedMessages._safeParseInt(json['current_page'], 1);
      lastPage = PaginatedMessages._safeParseInt(json['last_page'], 1);
      perPage = PaginatedMessages._safeParseInt(json['per_page'], 50);
      total = PaginatedMessages._safeParseInt(json['total'], 0);
    }

    return SearchMessagesResult(
      data: messages,
      currentPage: currentPage,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
      // Search endpoints might not have links
      nextPageUrl: null,
      prevPageUrl: null,
    );
  }
}
