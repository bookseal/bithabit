/// 채팅방 화면 (메인 화면)
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// 채팅 메시지 모델
class ChatMessage {
  final int id;
  final int userId;
  final String username;
  final String? gifUrl;
  final String? text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    this.gifUrl,
    this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userId: json['user_id'],
      username: json['username'],
      gifUrl: json['gif_url'],
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// 채팅방 화면 위젯
class ChatScreen extends StatefulWidget {
  final String? pendingGifBase64;

  const ChatScreen({super.key, this.pendingGifBase64});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  html.WebSocket? _webSocket;
  int? _userId;
  String? _username;
  bool _isLoading = true;
  bool _isSending = false;
  String? _pendingGif;

  @override
  void initState() {
    super.initState();
    _pendingGif = widget.pendingGifBase64;
    _initChat();
  }

  @override
  void dispose() {
    _webSocket?.close();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _username = prefs.getString('username');

    if (_userId == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    await _loadMessages();
    _connectWebSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ApiService.getMessages();
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages.map((m) => ChatMessage.fromJson(m)));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _connectWebSocket() {
    try {
      _webSocket = html.WebSocket(ApiService.wsUrl);

      _webSocket!.onMessage.listen((event) {
        try {
          final data = jsonDecode(event.data);
          final message = ChatMessage.fromJson(data);
          if (mounted) {
            setState(() => _messages.add(message));
            _scrollToBottom();
          }
        } catch (e) {
          debugPrint('WebSocket 파싱 오류: $e');
        }
      });

      _webSocket!.onClose.listen((_) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _connectWebSocket();
        });
      });
    } catch (e) {
      debugPrint('WebSocket 연결 실패: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingGif == null) return;

    setState(() => _isSending = true);

    try {
      await ApiService.sendMessage(
        userId: _userId!,
        text: text.isNotEmpty ? text : null,
        gifBase64: _pendingGif,
      );
      _textController.clear();
      setState(() => _pendingGif = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _cancelPendingGif() {
    setState(() => _pendingGif = null);
  }

  /// 습관 시작 (타이머/카메라 화면으로 이동)
  void _startHabit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// 로그아웃
  Future<void> _logout() async {
    await ApiService.clearTokens();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFF0D1B2A),
      endDrawer: _buildMembersDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.chat_bubble, color: Color(0xFF00D9A5), size: 24),
            const SizedBox(width: 8),
            const Text('BitHabit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_username != null)
              Text(
                _username!,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Color(0xFF00D9A5)),
            onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Members',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // 습관 시작 버튼
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1B263B),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startHabit,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Start Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9A5),
                  foregroundColor: const Color(0xFF0D1B2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // 메시지 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9A5)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet\nSend the first one!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
                      ),
          ),

          // GIF 프리뷰
          if (_pendingGif != null) _buildGifPreview(),

          // 입력 영역
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isMe = message.userId == _userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00D9A5),
              child: Text(
                message.username[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.username,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF00D9A5) : const Color(0xFF253449),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.gifUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${ApiService.hostUrl}${message.gifUrl}',
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 200,
                              height: 100,
                              color: Colors.black26,
                              child: const Icon(Icons.broken_image, color: Colors.white54),
                            ),
                          ),
                        ),
                      if (message.text != null && message.text!.isNotEmpty) ...[
                        if (message.gifUrl != null) const SizedBox(height: 8),
                        Text(
                          message.text!,
                          style: TextStyle(
                            color: isMe ? const Color(0xFF0D1B2A) : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF253449),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(_pendingGif!.split(',').last),
              width: 80,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('GIF ready to send', style: TextStyle(color: Colors.white.withOpacity(0.7)))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _cancelPendingGif,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1B263B),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF253449),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF00D9A5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1B2A)),
                      )
                    : const Icon(Icons.send, color: Color(0xFF0D1B2A)),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1B263B),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF253449))),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: Color(0xFF00D9A5), size: 22),
                      SizedBox(width: 8),
                      Text('Members',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text('People in this group',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            // Member list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: ApiService.getUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00D9A5)));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                        child: Text('Failed to load',
                            style: TextStyle(color: Colors.white.withOpacity(0.5))));
                  }

                  final users = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final name = user['username'] ?? '';
                      final email = user['email'] ?? '';
                      final isMe = user['id'] == _userId;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isMe
                              ? const Color(0xFF00D9A5)
                              : const Color(0xFF253449),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isMe
                                  ? const Color(0xFF0D1B2A)
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D9A5).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('you',
                                    style: TextStyle(
                                        color: Color(0xFF00D9A5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: email.isNotEmpty
                            ? Text(email,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 11))
                            : null,
                        dense: true,
                      );
                    },
                  );
                },
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF253449))),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: ApiService.getUsers(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Text('$count members',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35), fontSize: 12));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
