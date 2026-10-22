class ChatMessage {
  final String id;
  final String sender; // 'user' or 'ai'
  final String content;
  final DateTime timestamp;
  final List<String>? suggestedActions;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.suggestedActions,
  });
}
