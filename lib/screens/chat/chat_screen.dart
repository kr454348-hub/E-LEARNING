import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/global_app_bar.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserName;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserName,
    required this.otherUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late Stream<List<Message>> _messageStream;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessages(widget.roomId);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _chatService.markAsRead(widget.roomId, user.uid);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final firebaseUser = authService.currentUser;
    final userModel = authService.userModel;
    if (firebaseUser == null || userModel == null) return;

    setState(() => _isSending = true);
    _messageCtrl.clear();

    try {
      final message = Message(
        id: '',
        senderId: firebaseUser.uid,
        senderName: userModel.name.isNotEmpty ? userModel.name : userModel.email,
        senderRole: userModel.role,
        text: text,
        timestamp: DateTime.now(),
        readBy: [firebaseUser.uid],
      );
      await _chatService.sendMessage(widget.roomId, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthService>(context).currentUser;
    final currentUserId = user?.uid ?? '';

    return Scaffold(
      appBar: const GlobalAppBar(
        title: null,
        leading: BackButton(),
      ),
      body: Column(
        children: [
          // Chat header below the global app bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _roleColor(widget.otherUserRole),
                  child: Text(
                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.otherUserName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                      Text(widget.otherUserRole.toUpperCase(), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Chat Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('Start the conversation!', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _buildMessageBubble(msg, isMe, theme);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg.senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _roleColor(msg.senderRole))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: _roleColor(msg.senderRole).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(msg.senderRole.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _roleColor(msg.senderRole))),
                    ),
                  ],
                ),
              ),
            Text(msg.text, style: TextStyle(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface, fontSize: 15)),
            const SizedBox(height: 4),
            Text(_formatTime(msg.timestamp), style: TextStyle(fontSize: 11, color: isMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.7) : theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'teacher':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}
