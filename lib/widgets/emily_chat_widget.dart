import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

class EmilyChatWidget extends StatefulWidget {
  const EmilyChatWidget({super.key});

  @override
  State<EmilyChatWidget> createState() => _EmilyChatWidgetState();
}

class _EmilyChatWidgetState extends State<EmilyChatWidget> {
  bool _open = false;
  bool _enabled = false;
  final _controller = TextEditingController();
  final _messages = <_ChatMsg>[
    _ChatMsg(fromBot: true, text: '¡Hola! Soy Emily, ¿en qué te ayudo?'),
  ];
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnabled());
  }

  Future<void> _checkEnabled() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    try {
      // Fuente de verdad: app_settings/chatbot_app (admin). Sin doc → off.
      final enabled = await app.firebase.fetchChatbotAppEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _enabled = false);
    }
  }

  void _connect() {
    if (_channel != null) return;
    final session = context.read<AppProvider>().user?.uid ??
        'guest_${DateTime.now().millisecondsSinceEpoch}';
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(ApiConfig.chatbotWsUrl(session)),
      );
      _channel!.stream.listen((event) {
        try {
          final data = jsonDecode(event.toString());
          final text = (data['message'] ?? data['text'] ?? event).toString();
          if (mounted) {
            setState(() => _messages.add(_ChatMsg(fromBot: true, text: text)));
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _messages.add(_ChatMsg(fromBot: true, text: event.toString())),
            );
          }
        }
      }, onError: (_) {}, onDone: () => _channel = null);
    } catch (_) {
      setState(() {
        _messages.add(
          _ChatMsg(
            fromBot: true,
            text: 'No pude conectar al chat ahora. Intenta más tarde.',
          ),
        );
      });
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(fromBot: false, text: text));
      _controller.clear();
    });
    _connect();
    try {
      _channel?.sink.add(jsonEncode({'message': text, 'channel': 'mobile'}));
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open) _panel(),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'emily',
            backgroundColor: AppColors.primaryEnd,
            onPressed: () {
              setState(() => _open = !_open);
              if (_open) _connect();
            },
            child: Icon(_open ? Icons.close : Icons.chat_bubble, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: Container(
        width: 300,
        height: 380,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppColors.radiusLg),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Emily',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  return Align(
                    alignment:
                        m.fromBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: m.fromBot
                            ? AppColors.lightBg
                            : AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMsg {
  _ChatMsg({required this.fromBot, required this.text});
  final bool fromBot;
  final String text;
}
