/// One saved DARM Assistant conversation.
class ChatMessage {
  ChatMessage(this.role, this.text);
  final String role; // 'user' | 'assistant'
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
      j['role'] as String? ?? 'assistant', j['text'] as String? ?? '');
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.createdAt,
    required this.messages,
    this.groundingLabel,
  });

  final String id;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  /// e.g. "Melanocytic Nevus · 44%" when the chat was opened from a result.
  final String? groundingLabel;

  /// Title = the first thing the user actually asked (fallback to a generic).
  String get title {
    final firstUser = messages.where((m) => m.role == 'user').toList();
    if (firstUser.isEmpty) return 'New conversation';
    final t = firstUser.first.text.trim();
    return t.length <= 60 ? t : '${t.substring(0, 57)}…';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'groundingLabel': groundingLabel,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        groundingLabel: j['groundingLabel'] as String?,
        messages: (j['messages'] as List? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
