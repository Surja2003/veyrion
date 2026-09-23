import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_session.dart';
import '../../state/app_controller.dart';
import 'chat_screen.dart';

/// Saved DARM Assistant conversations: tap to reopen/continue, swipe or use the
/// menu to delete a single chat, or clear them all.
class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final chats = app.chats;

    return Scaffold(
      appBar: AppBar(
        title: Text('chat.history'.tr()),
        actions: [
          if (chats.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClearAll(context),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text('chat.clearAll'.tr()),
            ),
        ],
      ),
      body: SafeArea(
        child: chats.isEmpty
            ? _Empty()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ChatTile(session: chats[i]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('chat.clearAllTitle'.tr()),
        content: Text('chat.clearAllBody'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('chat.clearAll'.tr())),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppController>().clearChats();
    }
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.session});
  final ChatSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = DateFormat('d MMM, h:mm a').format(session.createdAt);
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => context.read<AppController>().deleteChat(session.id),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.forum_outlined,
                color: theme.colorScheme.onPrimaryContainer, size: 20),
          ),
          title:
              Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              when,
              if (session.groundingLabel != null) session.groundingLabel!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: 'chat.deleteChat'.tr(),
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                context.read<AppController>().deleteChat(session.id),
          ),
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatScreen(existing: session),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('chat.historyEmpty'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
