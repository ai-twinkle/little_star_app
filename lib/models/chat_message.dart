class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? modelName;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.modelName,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    String? modelName,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      modelName: modelName ?? this.modelName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'modelName': modelName,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      modelName: json['modelName'],
    );
  }
} 