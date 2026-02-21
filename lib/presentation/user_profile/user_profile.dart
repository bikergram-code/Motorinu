import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/auth/remember_me_store.dart';
import '../../core/auth/token_store.dart';
import '../../core/profile/local_profile_store.dart';

/// Profile screen:
/// - "Me" mode: shows /me.php + local overrides (persisted profile edits)
/// - Public mode: shows preview data (from feed) for other users
class UserProfile extends StatefulWidget {
  /// Optional: open a specific user directly (public mode)
  final int? userId;

  /// Optional: username (public mode). Only used for headline.
  final String? username;

  /// Optional: avatar URL preview (public mode).
  final String? avatarUrl;

  /// Optional: preview map (public mode)
  final Map<String, dynamic>? preview;

  const UserProfile({
    super.key,
    this.userId,
    this.username,
    this.avatarUrl,
    this.preview,
  });

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  Map<String, dynamic>? _meUser; // /me.php user
  Map<String, dynamic>? _localOverrides; // saved local edits for this account
  bool _loadingMe = false;
  String? _error;

  bool get _isMeMode {
    // If no explicit userId passed OR it's the same as my id, show Me.
    if (widget.userId == null) return true;
    final myId = _meUser?['id'];
    if (myId is int && myId == widget.userId) return true;
    return false;
  }

  Map<String, dynamic>? get _activeProfile {
    if (_isMeMode) {
      if (_meUser != null) return _meUser;
      return widget.preview;
    }
    // public profile (other user)
    if (widget.preview != null) return widget.preview;
    return {
      'id': widget.userId,
      'username': widget.username,
      'avatarUrl': widget.avatarUrl,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _copyToClipboard(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label kopiert')),
    );
  }

  bool _looksLikeUrl(String s) {
    final v = s.trim();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  void _openAvatarFullscreen(String url) {
    final u = url.trim();
    if (u.isEmpty || !_looksLikeUrl(u)) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    u,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, st) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white70, size: 48),
                    ),
                    loadingBuilder: (c, w, p) {
                      if (p == null) return w;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _error = null;
    });

    // Always try to load "me" once so that the tab works reliably
    await _loadMe();

    // If a public userId is requested and it's NOT me, later we can call a public profile endpoint.
    // For now we rely on preview data.
  }

  Future<void> _loadMe() async {
    setState(() {
      _loadingMe = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.getJson('/me.php', withAuth: true);
      final user = res?['data']?['user'];
      if (user is! Map) {
        throw Exception('Invalid /me.php response');
      }

      final me = Map<String, dynamic>.from(user);
      final uid = me['id'];

      // Load local overrides for this account (displayName/bikername/avatar/bio...)
      Map<String, dynamic>? local;
      if (uid is int) {
        local = await LocalProfileStore.instance.load(uid);
        if (local != null) {
          _applyLocalOverrides(me, local);
        }
      }

      setState(() {
        _meUser = me;
        _localOverrides = local;
        _loadingMe = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    }
  }

  void _applyLocalOverrides(Map<String, dynamic> me, Map<String, dynamic> local) {
    String? _s(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final displayName = _s(local['displayName']);
    final bikername = _s(local['bikername']);
    final avatarUrl = _s(local['avatarUrl']);
    final bio = _s(local['bio']);

    if (displayName != null) me['displayName'] = displayName;
    if (bikername != null) me['bikername'] = bikername;
    if (avatarUrl != null) me['avatarUrl'] = avatarUrl;
    if (bio != null) me['bio'] = bio;
  }

  Future<void> _logout() async {
    // Clear tokens
    try {
      await TokenStore().clear();
    } catch (_) {}

    // Optional: clear remembered credentials
    try {
      await RememberMeStore.instance.clear();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openSupport() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support kommt gleich.')),
    );
  }

  Future<void> _showEditSheet() async {
    if (!_isMeMode) return;
    final me = _meUser;
    if (me == null) return;

    final uid = me['id'];
    if (uid is! int) return;

    String _pickString(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final displayNameCtrl = TextEditingController(
      text: _pickString(me, ['displayName', 'name', 'username']),
    );
    final bikernameCtrl = TextEditingController(
      text: _pickString(me, ['bikername', 'bikerName', 'username']),
    );
    final avatarCtrl = TextEditingController(
      text: _pickString(me, ['avatarUrl', 'avatar', 'imageUrl']),
    );
    final bioCtrl = TextEditingController(
      text: _pickString(me, ['bio', 'about']),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool busy = false;

        Future<void> save() async {
          if (busy) return;
          busy = true;

          final patch = <String, dynamic>{
            'displayName': displayNameCtrl.text.trim(),
            'bikername': bikernameCtrl.text.trim(),
            'avatarUrl': avatarCtrl.text.trim(),
            'bio': bioCtrl.text.trim(),
          };

          // Persist locally (works even if backend update doesn't exist yet)
          await LocalProfileStore.instance.savePatch(uid, patch);

          // Best-effort backend update (endpoint can be added later).
          try {
            await ApiClient.instance.postJson('/profile_update.php', body: patch);
          } catch (_) {
            // ignore - we still persist locally
          }

          // Update local state immediately
          if (!mounted) return;
          setState(() {
            _meUser ??= <String, dynamic>{};
            for (final e in patch.entries) {
              final v = (e.value is String) ? (e.value as String).trim() : e.value;
              if (v == null || (v is String && v.isEmpty)) {
                (_meUser!).remove(e.key);
              } else {
                (_meUser!)[e.key] = v;
              }
            }
          });

          if (!mounted) return;
          Navigator.of(ctx).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil gespeichert.')),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF121318),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: StatefulBuilder(
                builder: (ctx2, setModal) {
                  Future<void> _savePressed() async {
                    if (busy) return;
                    setModal(() => busy = true);
                    await save();
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Profil bearbeiten',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Avatar editor (URL) with preview + fullscreen
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              final url = avatarCtrl.text.trim();
                              if (_looksLikeUrl(url)) _openAvatarFullscreen(url);
                            },
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                                color: const Color(0xFF10131A),
                              ),
                              child: ClipOval(
                                child: Builder(
                                  builder: (_) {
                                    final url = avatarCtrl.text.trim();
                                    if (_looksLikeUrl(url)) {
                                      return Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.white54, size: 34),
                                        loadingBuilder: (c, child, loading) => loading == null
                                            ? child
                                            : const Center(
                                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                              ),
                                      );
                                    }
                                    return const Icon(Icons.person, color: Colors.white54, size: 34);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profilbild', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: avatarCtrl,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setModal(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Avatar-URL (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final d = await Clipboard.getData(Clipboard.kTextPlain);
                                        final t = (d?.text ?? '').trim();
                                        if (t.isEmpty) return;
                                        avatarCtrl.text = t;
                                        setModal(() {});
                                      },
                                      icon: const Icon(Icons.content_paste, size: 18),
                                      label: const Text('Einfügen'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        avatarCtrl.clear();
                                        setModal(() {});
                                      },
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Leeren'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      TextField(
                        controller: displayNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Anzeigename',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bikernameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Bikername',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bio (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: busy ? null : _savePressed,
                        icon: const Icon(Icons.save),
                        label: Text(busy ? 'Speichern…' : 'Speichern'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hinweis: Wird lokal gespeichert. Backend-Update kommt danach.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    displayNameCtrl.dispose();
    bikernameCtrl.dispose();
    avatarCtrl.dispose();
    bioCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _activeProfile;

    final userId = p?['id'];
    final String username = (p?['username'] ?? widget.username ?? 'user').toString();
    final String displayName = (p?['displayName'] ?? p?['name'] ?? username).toString();
    final dynamic emailVal = (p == null) ? null : p['email'];
    final String? email = emailVal?.toString();


    final dynamic bikernameVal = (p == null) ? null : p['bikername'];
    final String? bikername = bikernameVal?.toString();
    final dynamic bioVal = (p == null) ? null : p['bio'];
    final String? bio = bioVal?.toString();

    final dynamic avRaw = (p?['avatarUrl'] ?? p?['avatar'] ?? widget.avatarUrl);
    final String? avatar = avRaw is String ? avRaw : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            _HeaderCard(
              displayName: displayName,
              username: username,
              avatarUrl: avatar,
              subtitle: _isMeMode ? null : 'Öffentliches Profil kommt gleich',
              onAvatarTap: (avatar != null && avatar.trim().isNotEmpty) ? () => _openAvatarFullscreen(avatar) : null,
            ),
            const SizedBox(height: 10),

            if (_loadingMe)
              const _SectionCard(
                title: 'Lädt…',
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            if (_error != null)
              _SectionCard(
                title: 'Fehler',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
                ),
              ),

            _SectionCard(
              title: 'Überblick',
              child: _buildOverview(userId: userId, username: username, email: email, bikername: bikername, bio: bio),
            ),
            const SizedBox(height: 10),

            _SectionCard(
              title: 'Quick Actions',
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.favorite,
                    title: 'Meine Likes',
                    subtitle: 'kommt gleich (Dashboard)',
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  _ActionRow(
                    icon: Icons.image,
                    title: 'Meine Bilder',
                    subtitle: 'kommt gleich (Galerie)',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_isMeMode)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showEditSheet,
                      icon: const Icon(Icons.edit),
                      label: const Text('Bearbeiten'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: _openSupport,
              icon: const Icon(Icons.support_agent),
              label: const Text('Support'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview({
    required dynamic userId,
    required String username,
    required String? email,
    required String? bikername,
    required String? bio,
  }) {
    Widget card(String title, List<Widget> children) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF151720),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...children,
          ],
        ),
      );
    }

    Widget tile({
      required String label,
      required String value,
      required IconData icon,
      bool copyable = true,
    }) {
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(icon, size: 18, color: Colors.white70),
        title: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
        subtitle: SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: copyable
            ? IconButton(
                tooltip: '$label kopieren',
                onPressed: () => _copyToClipboard(label, value),
                icon: const Icon(Icons.copy, size: 18),
              )
            : null,
      );
    }

    final uidText = userId?.toString() ?? '-';
    final emailText = (email ?? '').trim();
    final bikerText = (bikername ?? '').trim();
    final bioText = (bio ?? '').trim();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card('Account', [
            tile(label: 'User-ID', value: uidText, icon: Icons.badge_outlined, copyable: true),
            tile(label: 'Username', value: username, icon: Icons.alternate_email, copyable: true),
            if (emailText.isNotEmpty) tile(label: 'E-Mail', value: emailText, icon: Icons.email_outlined, copyable: true),
          ]),
          card('Profil', [
            if (bikerText.isNotEmpty) tile(label: 'Bikername', value: bikerText, icon: Icons.motorcycle_outlined, copyable: true),
            if (bioText.isNotEmpty)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                leading: Icon(Icons.info_outline, size: 18, color: Colors.white70),
                title: Text('Bio', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                subtitle: Text(bioText, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            if (bikerText.isEmpty && bioText.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Text(
                  'Noch keine Profil-Infos – tippe oben auf „Bearbeiten“.',
                  style: TextStyle(color: Colors.white.withOpacity(0.65)),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? subtitle;
  final VoidCallback? onAvatarTap;

  const _HeaderCard({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    this.subtitle,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = (avatarUrl != null && avatarUrl!.trim().isNotEmpty) ? avatarUrl!.trim() : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D2A), Color(0xFF11131A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InkWell(
              onTap: (img != null) ? onAvatarTap : null,
              borderRadius: BorderRadius.circular(56),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white10,
                    backgroundImage: (img != null) ? NetworkImage(img) : null,
                    child: img == null ? const Icon(Icons.person, size: 34) : null,
                  ),
                  if (img != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.fullscreen, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle!,
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          child,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}