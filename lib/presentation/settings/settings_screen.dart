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
import '../widgets/bug_report_sheet.dart';

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
              style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Neue E-Mail-Adresse',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF9E9E9E)),
                filled: true,
                fillColor: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
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
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF9E9E9E)))),
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
              style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Neues Passwort',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF9E9E9E)),
                filled: true,
                fillColor: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: GoogleFonts.inter(fontSize: 15, color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Passwort bestätigen',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF9E9E9E)),
                filled: true,
                fillColor: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F3F4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE0E0E0))),
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
                      color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF9E9E9E)))),
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

  void _showPremiumSheet(BuildContext context, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final mutedColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6C757D);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text('Premium kommt bald!', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 8),
            Text('Wir arbeiten an exklusiven Features für Premium-Mitglieder:', style: GoogleFonts.inter(fontSize: 13, color: mutedColor), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _premiumFeature(Icons.verified_rounded, 'Verifiziertes Profil', 'Blauer Haken für dein Profil', textColor, mutedColor),
            _premiumFeature(Icons.trending_up_rounded, 'Profil-Boost', 'Mehr Sichtbarkeit im Feed & Dating', textColor, mutedColor),
            _premiumFeature(Icons.navigation_rounded, 'Pro Navigation', 'Erweiterte Routenplanung & Offroad-Karten', textColor, mutedColor),
            _premiumFeature(Icons.place_rounded, 'Exklusive POIs', 'Geheime Biker-Spots, Scenic Routes & Treffpunkte', textColor, mutedColor),
            _premiumFeature(Icons.block_rounded, 'Keine Werbung', 'Werbefreie Nutzung der App', textColor, mutedColor),
            _premiumFeature(Icons.palette_rounded, 'Exklusive Themes', 'Besondere Farbdesigns für dein Profil', textColor, mutedColor),
            _premiumFeature(Icons.analytics_rounded, 'Detaillierte Statistiken', 'Erweiterte Einblicke in dein Profil', textColor, mutedColor),
            const SizedBox(height: 16),
            Text('Benachrichtigung folgt, sobald Premium verfügbar ist.', style: GoogleFonts.inter(fontSize: 12, color: mutedColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _premiumFeature(IconData icon, String title, String subtitle, Color textColor, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final controller = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: community?.cardFor(brightness) ??
              (isDark ? const Color(0xFF1A1A1A) : Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Konto löschen?',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: community?.textColor(brightness) ??
                        (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dein Konto und alle Daten werden unwiderruflich gelöscht.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: community?.textMutedColor(brightness) ??
                      (isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF6C757D)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tippe LÖSCHEN um zu bestätigen:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF6C757D),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                enabled: !isDeleting,
                autocorrect: false,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'LÖSCHEN',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF9E9E9E)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF1F3F4),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                onChanged: (_) => setStateDialog(() {}),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Abbrechen',
                style: GoogleFonts.inter(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF6C757D)),
              ),
            ),
            TextButton(
              onPressed: (controller.text.trim() == 'LÖSCHEN' && !isDeleting)
                  ? () async {
                      setStateDialog(() => isDeleting = true);
                      await _performAccountDeletion(ctx);
                    }
                  : null,
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.red),
                    )
                  : Text(
                      'Endgültig löschen',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: controller.text.trim() == 'LÖSCHEN'
                            ? Colors.red
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFarewellDialog() {
    final community = ref.read(communityProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF6C757D);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: community?.cardFor(brightness) ??
            (isDark ? const Color(0xFF1A1A1A) : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waving_hand_rounded,
                  color: accentColor, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Auf Wiedersehen!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dein Konto wurde gelöscht. Schade, dass du gehst — wir hoffen, du fährst sicher und kommst irgendwann zurück! 🏍️',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Du kannst dich jederzeit wieder neu registrieren — auch mit derselben E-Mail-Adresse.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: mutedColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: mutedColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Tschüss',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/register');
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(
                    'Neu starten',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext dialogCtx) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) Navigator.pop(dialogCtx);
      return;
    }

    try {
      // Server-side deletion via Postgres RPC (security definer).
      // The function deletes all user data + auth.users row in one transaction.
      // SQL für die Function liegt in supabase/sql/delete_my_account.sql
      await supabase.rpc('delete_my_account');

      // Sign out locally (session is now invalid anyway)
      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pop(dialogCtx);

      // Farewell dialog with re-register option
      if (mounted) _showFarewellDialog();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(dialogCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Löschen: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
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
                onTap: () => _showPremiumSheet(context, brightness),
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
                title: '\u00dcber Bikergram',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Bikergram',
                    applicationVersion: '1.0.0-beta',
                    applicationLegalese: '\u00a9 2025 Bikergram\ninfo@bikergram.com',
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Datenschutzerkl\u00e4rung',
                onTap: () => launchUrl(
                    Uri.parse('https://motorinu.com/privacy'),
                    mode: LaunchMode.externalApplication),
              ),
              _SettingsTile(
                icon: Icons.gavel_outlined,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Nutzungsbedingungen',
                onTap: () => launchUrl(
                    Uri.parse('https://motorinu.com/terms'),
                    mode: LaunchMode.externalApplication),
              ),
              _SettingsTile(
                icon: Icons.bug_report_rounded,
                iconColor: Colors.orange.withValues(alpha: 0.7),
                title: 'Fehler melden',
                onTap: () => BugReportSheet.show(context),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconColor: Colors.white.withValues(alpha: 0.5),
                title: 'Hilfe & Support',
                subtitle: 'info@bikergram.com',
                onTap: () => launchUrl(
                    Uri.parse('mailto:info@bikergram.com'),
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

          // Delete account — full button, red, clearly visible
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showDeleteAccountDialog,
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: Text(
                'Konto l\u00f6schen',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(
                    color: Colors.red.withValues(alpha: 0.5), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
