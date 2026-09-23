import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_session.dart';
import '../../models/prediction.dart';
import '../../services/api.dart';
import '../../state/app_controller.dart';
import 'chat_history_screen.dart';

/// DARM Assistant chat. Optionally grounded in a specific [grounding] result so
/// answers refer to the user's actual scan rather than being generic.
/// Pass [existing] to reopen and continue a saved conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.grounding, this.existing});
  final Prediction? grounding;
  final ChatSession? existing;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  late final String _sessionId;
  late final DateTime _createdAt;
  String? _groundingLabel;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _sessionId = existing.id;
      _createdAt = existing.createdAt;
      _groundingLabel = existing.groundingLabel;
      _messages.addAll(existing.messages);
      return;
    }
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _createdAt = DateTime.now();
    final g = widget.grounding;
    if (g != null) {
      _groundingLabel = '${g.topName} · ${(g.topProbability * 100).round()}%';
    }
    final greeting = g == null
        ? 'chat.greetingGeneral'.tr()
        : 'chat.greetingGrounded'
            .tr(args: [g.topName, '${(g.topProbability * 100).round()}']);
    _messages.add(ChatMessage('assistant', greeting));
  }

  void _persist() {
    // Only save once there's a real exchange (more than the greeting).
    if (_messages.where((m) => m.role == 'user').isEmpty) return;
    context.read<AppController>().saveChat(ChatSession(
          id: _sessionId,
          createdAt: _createdAt,
          groundingLabel: _groundingLabel,
          messages: List.of(_messages),
        ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _context() {
    final p = widget.grounding;
    if (p == null) return null;
    return {
      'top_code': p.topCode,
      'top_name': p.topName,
      'top_prob': p.topProbability,
      'malignant_probability': p.malignantProbability,
      'uncertainty': p.confidence.level,
    };
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _sending) return;
    final app = context.read<AppController>();
    if (app.token == null) return;

    setState(() {
      _messages.add(ChatMessage('user', text));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    // Send prior turns as history (exclude the greeting + the just-added msg).
    final history = _messages
        .where((m) => m != _messages.first)
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    if (history.isNotEmpty) history.removeLast();

    try {
      final reply = await app.api.chat(
        token: app.token!,
        message: text,
        history: history,
        context: _context(),
        lang: context.locale.languageCode,
      );
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage('assistant', reply)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() =>
          _messages.add(ChatMessage('assistant', 'Sorry — ${e.message}')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage('assistant',
          "Sorry, I couldn't reach the assistant. Check your connection and try again.")));
    } finally {
      if (mounted) setState(() => _sending = false);
      _persist();
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final quick = widget.grounding != null
        ? [
            'chat.quickMeaning'.tr(),
            'chat.quickSure'.tr(),
            'chat.quickNext'.tr(),
          ]
        : [
            'chat.quickTypes'.tr(),
            'chat.quickAccuracy'.tr(),
            'chat.quickPhoto'.tr(),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text('chat.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'chat.history'.tr(),
            icon: const Icon(Icons.history),
            onPressed: () {
              _persist();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ChatHistoryScreen(),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!app.chatEnabled)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(10),
              child: Text(
                'chat.offline'.tr(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              addAutomaticKeepAlives: false,
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const _TypingBubble();
                }
                return _Bubble(msg: _messages[i]);
              },
            ),
          ),
          // Quick-question chips.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final q in quick)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(q),
                      onPressed: _sending ? null : () => _send(q),
                    ),
                  ),
              ],
            ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final c = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? c.primary : c.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? c.onPrimary : c.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 30,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'chat.hint'.tr(),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
