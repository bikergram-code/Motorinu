import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';

/// Kommentare: immer **neueste oben** (ohne Sort-Menü)
/// - Client sortiert zusätzlich nach createdAt desc (Fallback)
/// - Paging (limit/offset)
/// - Pull-to-refresh
/// - Optimistic create oben
/// - Löschen nur für eigenen Kommentar (API: /comment_delete.php)
class CommentsSheet extends StatefulWidget {
  final int postId;
  final int? myUserId;
  final int initialCount;
  final ValueChanged<int>? onCountChanged;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.initialCount,
    this.myUserId,
    this.onCountChanged,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  final Set<int> _seenIds = <int>{};

  late int _count;
  int _offset = 0;
  int _limit = 50;
  bool _hasMore = false;

  ScrollController? _attachedController;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _load(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _attachedController?.removeListener(_onScroll);
    super.dispose();
  }

  void _attachController(ScrollController c) {
    if (_attachedController == c) return;
    _attachedController?.removeListener(_onScroll);
    _attachedController = c;
    _attachedController?.addListener(_onScroll);
  }

  void _onScroll() {
    final c = _attachedController;
    if (c == null) return;
    if (!_hasMore || _loadingMore || _loading) return;
    if (!c.hasClients) return;

    const threshold = 320.0;
    if (c.position.pixels >= (c.position.maxScrollExtent - threshold)) {
      _loadMore();
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  DateTime _parseDateSafe(dynamic v) {
    final s = (v ?? '').toString();
    final dt = DateTime.tryParse(s);
    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _setCount(int count) {
    if (count == _count) return;
    _count = count;
    widget.onCountChanged?.call(_count);
  }

  String _formatTime(String createdAt) {
    final dt = DateTime.tryParse(createdAt) ?? DateTime.now();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return '${diff.inMinutes} Min';
    if (diff.inHours < 24) return '${diff.inHours} Std';
    return '${diff.inDays} Tg';
  }

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> m) {
    // Supports:
    // - v3: { id, postId, author:{id,username,displayName}, text, createdAt, isMine }
    // - legacy: { id, userId/user_id, username/user, body/text, createdAt/created_at }
    final author = (m['author'] is Map) ? (m['author'] as Map).cast<String, dynamic>() : null;
    final legacyUser = (m['user'] is Map) ? (m['user'] as Map).cast<String, dynamic>() : null;

    final userId = _toInt(m['userId'] ?? m['user_id'] ?? author?['id'] ?? legacyUser?['id'] ?? 0);
    final username = (author?['displayName'] ??
            author?['username'] ??
            legacyUser?['displayName'] ??
            legacyUser?['username'] ??
            m['username'] ??
            m['user'] ??
            'user')
        .toString();

    final body = (m['text'] ?? m['body'] ?? m['content'] ?? m['message'] ?? '').toString();
    final createdAt = (m['createdAt'] ?? m['created_at'] ?? m['created'] ?? '').toString();

    final isMine = (m['isMine'] == true) || (widget.myUserId != null && userId == widget.myUserId);

    return <String, dynamic>{
      'id': _toInt(m['id']),
      'postId': _toInt(m['postId'] ?? m['post_id'] ?? widget.postId),
      'userId': userId,
      'username': username,
      'body': body,
      'createdAt': createdAt,
      'isMine': isMine,
      '_pending': m['_pending'] == true,
    };
  }

  int _commentSortKey(Map<String, dynamic> c) {
    // newest first
    return _parseDateSafe(c['createdAt']).millisecondsSinceEpoch;
  }

  void _sortNewestFirst() {
    _comments.sort((a, b) => _commentSortKey(b).compareTo(_commentSortKey(a)));
  }

  Future<Map<String, dynamic>> _fetch({required int offset, required int limit}) async {
    // prefer newest first on server, but client will sort too
    final uri = '/comments_list.php?postId=${widget.postId}&limit=$limit&offset=$offset&order=desc';
    final res = await ApiClient.instance.getJson(uri, withAuth: true);

    if (res['ok'] != true) {
      final msg = (res['error']?['message'] ?? res['message'] ?? 'Load failed').toString();
      throw StateError(msg);
    }
    final data = res['data'];
    return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{'items': const []};
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
      _comments = <Map<String, dynamic>>[];
      _seenIds.clear();
      _offset = 0;
      _hasMore = false;
    }

    try {
      final data = await _fetch(offset: 0, limit: _limit);

      dynamic list = data['comments'] ?? data['items'];
      if (list is! List) list = const [];
      final total = _toInt(data['total']);
      final hasMore = (data['hasMore'] == true) ||
          ((_toInt(data['offset']) + (list as List).length) < total);

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final norm = _normalizeItem(item.cast<String, dynamic>());
          final id = _toInt(norm['id']);
          if (id != 0 && !_seenIds.contains(id)) {
            _seenIds.add(id);
            parsed.add(norm);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _comments = parsed;
        _sortNewestFirst();
        _loading = false;
        _offset = parsed.length;
        _hasMore = hasMore;
        _error = null;
      });

      final bestCount = total > 0 ? total : (_count < parsed.length ? parsed.length : _count);
      _setCount(bestCount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final data = await _fetch(offset: _offset, limit: _limit);

      dynamic list = data['comments'] ?? data['items'];
      if (list is! List) list = const [];
      final total = _toInt(data['total']);
      final hasMore = (data['hasMore'] == true) ||
          ((_toInt(data['offset']) + (list as List).length) < total);

      final appended = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final norm = _normalizeItem(item.cast<String, dynamic>());
          final id = _toInt(norm['id']);
          if (id != 0 && !_seenIds.contains(id)) {
            _seenIds.add(id);
            appended.add(norm);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _comments = [..._comments, ...appended];
        _sortNewestFirst();
        _offset = _seenIds.length; // keep paging stable even when list is sorted
        _hasMore = hasMore;
        _loadingMore = false;
      });

      if (total > 0) _setCount(total);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mehr laden fehlgeschlagen: ${e.toString().replaceFirst('Bad state: ', '')}')),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_sending) return;

    HapticFeedback.lightImpact();
    setState(() => _sending = true);

    // Optimistic insert (temporary id) - newest first => insert at top
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final optimistic = <String, dynamic>{
      'id': tempId,
      'postId': widget.postId,
      'userId': widget.myUserId ?? 0,
      'username': 'Du',
      'body': text,
      'createdAt': DateTime.now().toIso8601String(),
      'isMine': true,
      '_pending': true,
    };

    setState(() {
      _comments = [optimistic, ..._comments];
      _sortNewestFirst();
    });
    _setCount(_count + 1);

    try {
      final res = await ApiClient.instance.postJson(
        '/comment_create.php',
        body: {
          'postId': widget.postId,
          'post_id': widget.postId,
          'text': text,
          'body': text,
          'comment': text,
        },
        withAuth: true,
      );

      if (res['ok'] != true) {
        final msg = (res['error']?['message'] ?? res['message'] ?? 'Send failed').toString();
        throw StateError(msg);
      }

      // Server responses differ; keep UI stable even if author isn't included.
      final data = res['data'];
      Map<String, dynamic>? created;
      if (data is Map) {
        final c = data['comment'];
        if (c is Map) created = c.cast<String, dynamic>();
      }

      final real = _normalizeItem(<String, dynamic>{
        'id': created?['id'] ?? tempId,
        'postId': created?['postId'] ?? created?['post_id'] ?? widget.postId,
        'author': created?['author'],
        'userId': created?['userId'] ?? created?['user_id'] ?? widget.myUserId ?? 0,
        'username': created?['username'] ?? optimistic['username'],
        'text': created?['text'] ?? created?['body'] ?? text,
        'createdAt': created?['createdAt'] ?? created?['created_at'] ?? DateTime.now().toIso8601String(),
        'isMine': true,
        '_pending': false,
      });

      if (!mounted) return;
      setState(() {
        _controller.clear();
        _comments = _comments.map((c) => (_toInt(c['id']) == tempId) ? real : c).toList();
        _sortNewestFirst();
        _sending = false;
      });

      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _comments = _comments.where((c) => _toInt(c['id']) != tempId).toList();
        _sending = false;
      });
      _setCount((_count - 1).clamp(0, 1000000));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kommentar fehlgeschlagen: ${e.toString().replaceFirst('Bad state: ', '')}')),
      );
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final id = _toInt(c['id']);
    if (id <= 0) return;
    final isMine = c['isMine'] == true;
    if (!isMine) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kommentar löschen?'),
        content: const Text('Dieser Kommentar wird endgültig gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );

    if (ok != true) return;

    HapticFeedback.mediumImpact();

    // optimistic remove
    final before = List<Map<String, dynamic>>.from(_comments);
    setState(() {
      _comments = _comments.where((x) => _toInt(x['id']) != id).toList();
    });
    _setCount((_count - 1).clamp(0, 1000000));

    try {
      final res = await ApiClient.instance.postJson(
        '/comment_delete.php',
        body: {'commentId': id, 'postId': widget.postId},
        withAuth: true,
      );

      if (res['ok'] != true) {
        final msg = (res['error']?['message'] ?? res['message'] ?? 'Delete failed').toString();
        throw StateError(msg);
      }

      final data = res['data'];
      if (data is Map && data['total'] is int) {
        _setCount(data['total'] as int);
      }
    } catch (e) {
      // rollback
      if (!mounted) return;
      setState(() {
        _comments = before;
        _sortNewestFirst();
      });
      _setCount((_count + 1).clamp(0, 1000000));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: ${e.toString().replaceFirst('Bad state: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          _attachController(scrollController);

          final body = _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          TextButton(onPressed: () => _load(reset: true), child: const Text('Neu laden')),
                        ],
                      ),
                    )
                  : (_comments.isEmpty)
                      ? const Center(child: Text('Noch keine Kommentare'))
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _comments.length + 1,
                            itemBuilder: (context, i) {
                              if (i == _comments.length) {
                                if (_loadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 18),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                if (_hasMore) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: _loadMore,
                                        child: const Text('Mehr laden'),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox(height: 8);
                              }

                              final c = _comments[i];
                              final isMine = c['isMine'] == true;
                              final pending = c['_pending'] == true;

                              final username = (c['username'] ?? 'user').toString();
                              final text = (c['body'] ?? '').toString();
                              final time = _formatTime((c['createdAt'] ?? '').toString());

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      child: Text(
                                        username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        username,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      time,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                                      ),
                                                    ),
                                                    if (pending) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'sende…',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isMine && !pending)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18),
                                                  tooltip: 'Löschen',
                                                  onPressed: () => _deleteComment(c),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(text),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );

          return Material(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text('Kommentare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$_count', style: const TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: body),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Kommentar schreiben…',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
