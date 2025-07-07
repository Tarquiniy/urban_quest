import 'dart:async';
import 'package:urban_quest/models/team.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/providers/auth_provider.dart';

class TeamChatScreen extends StatefulWidget {
  final Team team;

  const TeamChatScreen({
    Key? key,
    required this.team,
  }) : super(key: key);

  @override
  _TeamChatScreenState createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  late RealtimeChannel _chatChannel;
  String? _userId;
  String? _username;
  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  FocusNode _focusNode = FocusNode();
  String? _typingUser;
  Timer? _typingEndTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initRealtimeSubscription();
    _loadInitialMessages();
    _messageController.addListener(_handleTyping);
  }

  void _handleTyping() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _typingUser = _username;
      });

      _typingEndTimer?.cancel();
      _typingEndTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _typingUser = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _typingEndTimer?.cancel();
    _chatChannel.unsubscribe();
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser != null) {
        setState(() {
          _userId = currentUser.id;
          _username = currentUser.username;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки пользователя: $e');
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final response = await _supabase
          .from('team_chat_messages')
          .select()
          .eq('team_id', widget.team.id)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
    } catch (e) {
      debugPrint('Ошибка загрузки сообщений: $e');
    }
  }

  void _initRealtimeSubscription() {
    _chatChannel = _supabase.channel('team_chat_${widget.team.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'team_chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'team_id',
          value: widget.team.id,
        ),
        callback: (payload) {
          _handleChatEvent(payload);
        },
      ).subscribe();
  }

  void _handleChatEvent(PostgresChangePayload payload) {
    if (!mounted) return;

    final event = payload.eventType;
    final newData = payload.newRecord;
    final oldData = payload.oldRecord;

    switch (event) {
      case PostgresChangeEvent.insert:
        if (newData != null) {
          setState(() {
            if (!_messages.any((m) => m['id'] == newData['id'])) {
              _messages.insert(0, newData);
              _scrollToBottom();
            }
          });
        }
        break;
      case PostgresChangeEvent.delete:
        if (oldData != null) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == oldData['id']);
          });
        }
        break;
      case PostgresChangeEvent.update:
        if (newData != null) {
          setState(() {
            final index = _messages.indexWhere((m) => m['id'] == newData['id']);
            if (index != -1) {
              _messages[index] = newData;
            }
          });
        }
        break;
      case PostgresChangeEvent.all:
        break;
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      // Сначала удаляем локально для мгновенного отображения
      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });

      // Затем удаляем на сервере
      await _supabase
          .from('team_chat_messages')
          .delete()
          .eq('id', messageId)
          .eq('user_id', _userId!);
    } catch (e) {
      if (mounted) {
        // В случае ошибки возвращаем сообщение обратно
        final message = await _supabase
            .from('team_chat_messages')
            .select()
            .eq('id', messageId)
            .single();

        if (message != null) {
          setState(() {
            _messages.insert(0, message);
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: ${e.toString()}')),
        );
      }
    }
  }

  void _showDeleteDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Вы уверены, что хотите удалить это сообщение?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending ||
        _messageController.text.trim().isEmpty ||
        _userId == null) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final message = _messageController.text.trim();
      _messageController.clear();

      await _supabase.from('team_chat_messages').insert({
        'team_id': widget.team.id,
        'user_id': _userId,
        'username': _username,
        'message': message,
      });

      if (mounted) {
        setState(() {
          _typingUser = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCurrentUser) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onLongPress:
          isCurrentUser ? () => _showDeleteDialog(message['id']) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser)
              CircleAvatar(
                backgroundColor: Colors.grey,
                radius: 16,
                child: Text(
                  message['username']?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 2),
                      child: Text(
                        message['username'] ?? 'Аноним',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? (isDarkMode ? Colors.blue[800] : Colors.blue[100])
                          : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isCurrentUser
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                        bottomRight: isCurrentUser
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['message'] ?? '',
                          style: TextStyle(
                            color: isCurrentUser
                                ? (isDarkMode ? Colors.white : Colors.black)
                                : (isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message['created_at']),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrentUser
                                ? (isDarkMode ? Colors.white70 : Colors.black54)
                                : (isDarkMode
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Чат команды ${widget.team.name}'),
            if (_typingUser != null)
              Text(
                '$_typingUser печатает...',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _focusNode.unfocus(),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isCurrentUser = message['user_id'] == _userId;
                  return _buildMessageBubble(message, isCurrentUser);
                },
              ),
            ),
          ),
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dateTime = DateTime.parse(isoTime);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
