import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/community.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../theme/app_theme.dart';
import '../profile/widgets/edit_profile_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Toggle states stored locally for now
  bool _pushEnabled = true;
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _followersEnabled = true;
  bool _privateProfile = false;
  bool _liveGoVisible = true;

  void _showChangeEmailDialog(Color accentColor) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('E-Mail ändern',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Eine Bestätigungs-E-Mail wird an die neue Adresse gesendet.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D)))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Neue E-Mail-Adresse',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Abbrechen',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty || !email.contains('@')) return;
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.auth
                      .updateUser(UserAttributes(email: email));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Bestätigungs-E-Mail gesendet an $email'),
                    backgroundColor: accentColor,
                  ));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Fehler: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: Text('Ändern',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: accentColor))),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(Color accentColor) {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Passwort ändern',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Neues Passwort',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Passwort bestätigen',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Abbrechen',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
              onPressed: () async {
                final pw = controller.text.trim();
                final confirm = confirmController.text.trim();
                if (pw.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Mindestens 6 Zeichen'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                if (pw != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Passwörter stimmen nicht überein'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.auth
                      .updateUser(UserAttributes(password: pw));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Passwort wurde geändert'),
                    backgroundColor: accentColor,
                  ));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Fehler: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: Text('Ändern',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: accentColor))),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Konto löschen?',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)))),
        content: Text(
            'Dein Konto und alle Daten werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
            style: GoogleFonts.inter(
                fontSize: 14, color: community?.textMutedColor(brightness) ?? (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Abbrechen',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5)))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // TODO: Implement account deletion via Supabase Edge Function
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Bitte kontaktiere den Support um dein Konto zu löschen.'),
                ));
              },
              child: Text('Löschen',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final authState = ref.watch(authNotifierProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    final userEmail = authState is Authenticated
        ? authState.user.email
        : '';

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A))),
        ),
        title: Text(
          'Einstellungen',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: community?.textColor(brightness) ?? (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Account section
          _SectionHeader(title: 'Konto'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: accentColor,
                title: 'Profil bearbeiten',
                onTap: () async {
                  await EditProfileSheet.show(context);
                  ref.read(authNotifierProvider.notifier).checkAuth();
                },
              ),
              _SettingsTile(
                icon: Icons.email_outlined,
                iconColor: accentColor,
                title: 'E-Mail ändern',
                subtitle: userEmail,
                onTap: () => _showChangeEmailDialog(accentColor),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconColor: accentColor,
                title: 'Passwort ändern',
                onTap: () => _showChangePasswordDialog(accentColor),
              ),
              _SettingsTile(
                icon: Icons.swap_horiz_rounded,
                iconColor: accentColor,
                title: 'Community wechseln',
                subtitle: community?.displayName ?? '',
                onTap: () {
                  ref.read(communityProvider.notifier).select(null);
                  context.go('/');
                },
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Appearance section
          _SectionHeader(title: 'Darstellung'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsToggle(
                icon: Icons.dark_mode_rounded,
                iconColor: accentColor,
                title: 'Dark Mode',
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Premium section
          _SectionHeader(title: 'Premium'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_rounded,
                iconColor: Colors.amber,
                title: 'Premium Abo',
                subtitle: 'Werbefrei & erweiterte Features',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '4,99 \u20ac/Mo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Premium kommt bald!'),
                  ));
                },
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Notifications section
          _SectionHeader(title: 'Benachrichtigungen'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsToggle(
                icon: Icons.notifications_outlined,
                iconColor: accentColor,
                title: 'Push-Benachrichtigungen',
                value: _pushEnabled,
                onChanged: (v) => setState(() => _pushEnabled = v),
              ),
              _SettingsToggle(
                icon: Icons.favorite_border_rounded,
                iconColor: Colors.red,
                title: 'Likes',
                value: _likesEnabled,
                onChanged: (v) => setState(() => _likesEnabled = v),
              ),
              _SettingsToggle(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: accentColor,
                title: 'Kommentare',
                value: _commentsEnabled,
                onChanged: (v) => setState(() => _commentsEnabled = v),
              ),
              _SettingsToggle(
                icon: Icons.person_add_outlined,
                iconColor: Colors.green,
                title: 'Neue Follower',
                value: _followersEnabled,
                onChanged: (v) => setState(() => _followersEnabled = v),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Privacy section
          _SectionHeader(title: 'Privatsph\u00e4re'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsToggle(
                icon: Icons.visibility_outlined,
                iconColor: accentColor,
                title: 'Privates Profil',
                value: _privateProfile,
                onChanged: (v) => setState(() => _privateProfile = v),
              ),
              _SettingsToggle(
                icon: Icons.cell_tower_rounded,
                iconColor: accentColor,
                title: 'Live-Go sichtbar',
                value: _liveGoVisible,
                onChanged: (v) => setState(() => _liveGoVisible = v),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info section
          _SectionHeader(title: 'Info'),
          _SettingsCard(
            cardColor: community?.cardFor(brightness),
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: '\u00dcber ${community?.displayName ?? 'die App'}',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Motorgram',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '\u00a9 2025 Motorgram',
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Datenschutzerkl\u00e4rung',
                onTap: () => launchUrl(
                    Uri.parse('https://motorgram.app/privacy'),
                    mode: LaunchMode.externalApplication),
              ),
              _SettingsTile(
                icon: Icons.gavel_outlined,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Nutzungsbedingungen',
                onTap: () => launchUrl(
                    Uri.parse('https://motorgram.app/terms'),
                    mode: LaunchMode.externalApplication),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Hilfe & Support',
                onTap: () => launchUrl(
                    Uri.parse('mailto:support@motorgram.app'),
                    mode: LaunchMode.externalApplication),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text(
                'Abmelden',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorDark,
                side: BorderSide(
                    color: AppTheme.errorDark.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Delete account
          Center(
            child: TextButton(
              onPressed: _showDeleteAccountDialog,
              child: Text(
                'Konto l\u00f6schen',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Version
          Center(
            child: Text(
              'Version 1.0.0',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF6C757D),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, this.cardColor});

  final List<Widget> children;
  final Color? cardColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: cardColor ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: showDivider
              ? BorderRadius.zero
              : const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: iconColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF6C757D),
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            color: Colors.white.withValues(alpha: 0.04),
          ),
      ],
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final community =
        ProviderScope.containerOf(context).read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: accentColor.withValues(alpha: 0.4),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return accentColor;
                  }
                  return Colors.white.withValues(alpha: 0.5);
                }),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 66,
            color: Colors.white.withValues(alpha: 0.04),
          ),
      ],
    );
  }
}
