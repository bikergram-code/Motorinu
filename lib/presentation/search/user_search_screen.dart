import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/core/providers.dart';
import '../../theme/app_theme.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggested = [];
  bool _isLoading = false;
  bool _isSuggestedLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
    // Autofocus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final repo = ref.read(profileRepositoryProvider);
      final data = await repo.getSuggestedUsers(limit: 15);
      if (!mounted) return;
      setState(() {
        _suggested = data;
        _isSuggestedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSuggestedLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final repo = ref.read(profileRepositoryProvider);
        final data = await repo.searchUsers(query.trim());
        if (!mounted) return;
        setState(() {
          _results = data;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final scaffoldBg = community?.scaffoldFor(brightness) ??
        (brightness == Brightness.dark
            ? Colors.black
            : const Color(0xFFF5F5F5));
    final textColor = community?.textColor(brightness) ??
        (brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF6C757D));
    final cardBg = community?.cardFor(brightness) ??
        (brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white);

    final isSearching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: community?.borderFor(brightness) ??
                  (brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: textColor,
            ),
            decoration: InputDecoration(
              hintText: 'Nutzer suchen...',
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: mutedColor,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: mutedColor,
              ),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: mutedColor),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          // Quick-access chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(Icons.groups_rounded, size: 16, color: accentColor),
                  label: Text('Gruppen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  backgroundColor: cardBg,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () => context.push('/groups'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(
        isSearching: isSearching,
        accentColor: accentColor,
        textColor: textColor,
        mutedColor: mutedColor,
        cardBg: cardBg,
        brightness: brightness,
        community: community,
      )),
        ],
      ),
    );
  }

  Widget _buildBody({
    required bool isSearching,
    required Color accentColor,
    required Color textColor,
    required Color mutedColor,
    required Color cardBg,
    required Brightness brightness,
    required Community? community,
  }) {
    // Searching mode
    if (isSearching) {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }

      if (_results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 48, color: mutedColor.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'Keine Nutzer gefunden',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Versuche einen anderen Suchbegriff',
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _results.length,
        itemBuilder: (context, index) => _UserTile(
          user: _results[index],
          accentColor: accentColor,
          textColor: textColor,
          mutedColor: mutedColor,
          cardBg: cardBg,
          brightness: brightness,
          community: community,
          onTap: () =>
              context.push('/profile/${_results[index]['id']}'),
        ),
      );
    }

    // Suggestions mode (no search query)
    if (_isSuggestedLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_suggested.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: mutedColor.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Noch keine Nutzer',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text(
            'Vorgeschlagene Nutzer',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _suggested.length,
            itemBuilder: (context, index) => _UserTile(
              user: _suggested[index],
              accentColor: accentColor,
              textColor: textColor,
              mutedColor: mutedColor,
              cardBg: cardBg,
              brightness: brightness,
              community: community,
              onTap: () =>
                  context.push('/profile/${_suggested[index]['id']}'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── User Tile ────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.cardBg,
    required this.brightness,
    required this.community,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final Color cardBg;
  final Brightness brightness;
  final Community? community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String? ?? '';
    final displayName = user['display_name'] as String?;
    final bikername = user['bikername'] as String?;
    final bio = user['bio'] as String?;
    final avatarUrl = community?.name == 'cargram'
        ? (user['avatar_url_cargram'] as String? ?? user['avatar_url'] as String?)
        : user['avatar_url'] as String?;
    final level = user['level'] as int? ?? 1;
    final plz = user['postal_code'] as String?;
    final isPremium = user['is_premium'] as bool? ?? false;
    final isBusiness = user['is_business'] as bool? ?? false;

    final name = displayName ?? bikername ?? username;
    final hasBio = bio != null && bio.isNotEmpty;
    final hasPlz = plz != null && plz.length >= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        elevation: brightness == Brightness.dark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: community?.borderFor(brightness) ??
                    (brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(avatarUrl, username),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name row
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.workspace_premium_rounded,
                                size: 14, color: Colors.amber),
                          ],
                          if (isBusiness) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.storefront_rounded,
                                size: 14, color: accentColor),
                          ],
                        ],
                      ),

                      // @username
                      if (displayName != null && displayName != username)
                        Text(
                          '@$username',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: mutedColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Bio
                      if (hasBio) ...[
                        const SizedBox(height: 2),
                        Text(
                          bio!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: mutedColor,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // PLZ-Hinweis
                      if (hasPlz) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 11, color: mutedColor),
                            const SizedBox(width: 2),
                            Text(
                              'PLZ ${plz!.substring(0, 3)}..',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Level badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    'Lv.$level',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                Icon(Icons.chevron_right_rounded,
                    size: 20, color: mutedColor.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String username) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: url == null || url.isEmpty
            ? LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.6)])
            : null,
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _avatarFallback(username),
              )
            : _avatarFallback(username),
      ),
    );
  }

  Widget _avatarFallback(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          (username.isNotEmpty ? username[0] : '?').toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
