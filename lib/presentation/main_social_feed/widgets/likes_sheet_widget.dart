import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_export.dart';

class LikesSheet extends StatefulWidget {
  final int postId;
  final int? myUserId;

  const LikesSheet({
    super.key,
    required this.postId,
    this.myUserId,
  });

  @override
  State<LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends State<LikesSheet> {
  bool _loading = true;
  String? _error;
  int _count = 0;
  List<Map<String, dynamic>> _likes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.getJson(
        '/likes_list.php?postId=${widget.postId}&limit=100',
        withAuth: true,
      );

      if (res['ok'] != true) {
        throw Exception((res['error']?['message'] ?? 'Like-Liste konnte nicht geladen werden').toString());
      }

      final data = (res['data'] as Map?) ?? const {};
      final count = data['count'];
      final likes = data['likes'];

      setState(() {
        _count = count is int ? count : 0;
        _likes = (likes is List)
            ? likes
                .whereType<Map>()
                .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
                .toList()
            : <Map<String, dynamic>>[];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Like-Liste konnte nicht geladen werden';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.70,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Gefällt mir',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_count',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: CustomIconWidget(
                        iconName: 'refresh',
                        color: theme.colorScheme.onSurface,
                        size: 22,
                      ),
                      tooltip: 'Aktualisieren',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_error != null)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          )
                        : (_likes.isEmpty)
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Noch keine Likes.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _likes.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final like = _likes[index];
                                  final id = like['id'];
                                  final username = (like['username'] ?? '').toString();
                                  final isMe = (widget.myUserId != null && id == widget.myUserId);

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                                      ),
                                    ),
                                    title: Text(
                                      username,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: isMe
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Du',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          )
                                        : null,
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
