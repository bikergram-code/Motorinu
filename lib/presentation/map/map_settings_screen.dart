import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../providers/map/map_settings_provider.dart';
import '../../providers/core/providers.dart';
import '../../services/navigation_tts_service.dart';
import '../../theme/app_theme.dart';

// ─── Map Settings Screen ─────────────────────────────────────────────────────
//
// Settings panel for the Community Map (alerts, audio, driving mode, battery).
// Accessible from: Speed-Dial → Karten-Einst., or Settings → Karte

class MapSettingsScreen extends ConsumerStatefulWidget {
  const MapSettingsScreen({super.key});

  @override
  ConsumerState<MapSettingsScreen> createState() => _MapSettingsScreenState();
}

class _MapSettingsScreenState extends ConsumerState<MapSettingsScreen> {
  String _selectedVoice = NavigationTtsService.instance.currentVoice;

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final brightness = Theme.of(context).brightness;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final textColor = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF6C757D));
    final cardColor = community?.cardFor(brightness) ??
        (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white);

    final settingsAsync = ref.watch(blitzerSettingsProvider);

    return Scaffold(
      backgroundColor: community?.scaffoldFor(brightness) ??
          (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
      appBar: AppBar(
        backgroundColor: community?.scaffoldFor(brightness) ??
            (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5)),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        title: Text(
          'Blitzer-Einstellungen',
          style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: textColor, letterSpacing: -0.3,
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ─── Warnungen ───────────────────────────────────
            _SectionHeader(title: 'Warnungen', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.photo_camera_rounded,
                  iconColor: Colors.red,
                  title: 'Feste Blitzer',
                  value: settings.warnFixed,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(warnFixed: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.directions_car_rounded,
                  iconColor: Colors.orange,
                  title: 'Mobile Blitzer',
                  value: settings.warnMobile,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(warnMobile: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.local_police_rounded,
                  iconColor: Colors.blue,
                  title: 'Polizeikontrollen',
                  value: settings.warnPolice,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(warnPolice: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.construction_rounded,
                  iconColor: Colors.amber,
                  title: 'Baustellen',
                  value: settings.warnConstruction,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(warnConstruction: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.warning_rounded,
                  iconColor: Colors.purple,
                  title: 'Unfälle',
                  value: settings.warnAccident,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(warnAccident: v)),
                  accentColor: accentColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Warnstufen ──────────────────────────────────
            _SectionHeader(title: 'Warnstufen', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.notifications_active_rounded,
                  iconColor: Colors.orange.shade600,
                  title: 'Frühwarnung',
                  subtitle: 'Ab ~20 Sek. Entfernung',
                  value: settings.earlyWarningEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(earlyWarningEnabled: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.amber.shade700,
                  title: 'Annäherungswarnung',
                  subtitle: 'Ab 500m Entfernung',
                  value: settings.approachWarningEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(approachWarningEnabled: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.crisis_alert_rounded,
                  iconColor: Colors.red.shade700,
                  title: 'Sofortwarnung',
                  subtitle: 'Ab 200m Entfernung',
                  value: settings.immediateWarningEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(immediateWarningEnabled: v)),
                  accentColor: accentColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Warnabstand ─────────────────────────────────
            _SectionHeader(title: 'Warnabstand', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _SliderTile(
                  icon: Icons.photo_camera_rounded,
                  iconColor: Colors.red,
                  title: 'Feste Blitzer',
                  value: settings.alertDistanceFixed.toDouble(),
                  min: 200, max: 1500, divisions: 13,
                  suffix: 'm',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(alertDistanceFixed: v.round())),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _SliderTile(
                  icon: Icons.directions_car_rounded,
                  iconColor: Colors.orange,
                  title: 'Mobile Blitzer',
                  value: settings.alertDistanceMobile.toDouble(),
                  min: 300, max: 2000, divisions: 17,
                  suffix: 'm',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(alertDistanceMobile: v.round())),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _SliderTile(
                  icon: Icons.local_police_rounded,
                  iconColor: Colors.blue,
                  title: 'Polizei',
                  value: settings.alertDistancePolice.toDouble(),
                  min: 200, max: 1500, divisions: 13,
                  suffix: 'm',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(alertDistancePolice: v.round())),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Audio & Vibration ───────────────────────────
            _SectionHeader(title: 'Audio & Vibration', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.volume_up_rounded,
                  iconColor: Colors.green,
                  title: 'Audio-Warnungen',
                  subtitle: 'Master-Schalter für alle Töne',
                  value: settings.audioAlertsEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(audioAlertsEnabled: v)),
                  accentColor: accentColor,
                ),
                if (settings.audioAlertsEnabled) ...[
                  _SliderTile(
                    icon: Icons.tune_rounded,
                    iconColor: Colors.green,
                    title: 'Lautstärke',
                    value: settings.audioVolume,
                    min: 0, max: 1, divisions: 10,
                    suffix: '%',
                    displayMultiplier: 100,
                    onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(audioVolume: v)),
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  _Toggle(
                    icon: Icons.navigation_rounded,
                    iconColor: Colors.blue,
                    title: 'Navigations-Töne',
                    subtitle: 'Abbiegen, Ankunft, Neuberechnung',
                    value: settings.navSoundEnabled,
                    onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(navSoundEnabled: v)),
                    accentColor: accentColor,
                  ),
                  _Toggle(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    title: 'Warnmeldungs-Töne',
                    subtitle: 'Blitzer, Polizei, Gefahren',
                    value: settings.warningSoundEnabled,
                    onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(warningSoundEnabled: v)),
                    accentColor: accentColor,
                  ),
                ],
                _Toggle(
                  icon: Icons.vibration_rounded,
                  iconColor: Colors.deepPurple,
                  title: 'Vibration',
                  value: settings.hapticAlertsEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(hapticAlertsEnabled: v)),
                  accentColor: accentColor,
                ),
                if (settings.hapticAlertsEnabled)
                  _OptionTile(
                    icon: Icons.settings_input_composite_rounded,
                    iconColor: Colors.deepPurple,
                    title: 'Vibrationsstärke',
                    value: settings.hapticIntensity,
                    options: const {
                      'light': 'Leicht',
                      'medium': 'Mittel',
                      'heavy': 'Stark',
                    },
                    onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(hapticIntensity: v)),
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    showDivider: false,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Navigationsstimme ──────────────────────────
            _SectionHeader(title: 'Navigationsstimme', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                for (final entry in ttsVoiceProfiles.entries) ...[
                  _VoiceTile(
                    profile: entry.value,
                    isSelected: _selectedVoice == entry.key,
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () {
                      setState(() => _selectedVoice = entry.key);
                      NavigationTtsService.instance.setVoice(entry.key);
                    },
                    onPreview: () => NavigationTtsService.instance.speakSample(entry.key),
                    showDivider: entry.key != ttsVoiceProfiles.keys.last,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color mutedColor;
  const _SectionHeader({required this.title, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: mutedColor, letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Color cardColor;
  final List<Widget> children;
  const _Card({required this.cardColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(children: children),
    );
  }
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;
  final bool showDivider;

  const _Toggle({
    required this.icon, required this.iconColor, required this.title,
    this.subtitle, required this.value, required this.onChanged,
    required this.accentColor, this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
              )),
              if (subtitle != null)
                Text(subtitle!, style: GoogleFonts.inter(
                  fontSize: 12, color: brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6C757D),
                )),
            ],
          )),
          Switch(
            value: value, onChanged: onChanged,
            activeTrackColor: accentColor.withValues(alpha: 0.4),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor;
              return Colors.white.withValues(alpha: 0.5);
            }),
          ),
        ]),
      ),
      if (showDivider)
        Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double value;
  final double min, max;
  final int divisions;
  final String suffix;
  final double displayMultiplier;
  final ValueChanged<double> onChanged;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final bool showDivider;

  const _SliderTile({
    required this.icon, required this.iconColor, required this.title,
    required this.value, required this.min, required this.max,
    required this.divisions, required this.suffix,
    this.displayMultiplier = 1, required this.onChanged,
    required this.accentColor, required this.textColor, required this.mutedColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = (value * displayMultiplier).round();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w500, color: textColor,
          ))),
          Text('$displayValue$suffix', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: accentColor,
          )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(60, 0, 16, 8),
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentColor,
            inactiveTrackColor: accentColor.withValues(alpha: 0.15),
            thumbColor: accentColor,
            overlayColor: accentColor.withValues(alpha: 0.1),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max), min: min, max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ),
      if (showDivider)
        Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final bool showDivider;

  const _OptionTile({
    required this.icon, required this.iconColor, required this.title,
    this.subtitle, required this.value, required this.options,
    required this.onChanged, required this.accentColor,
    required this.textColor, required this.mutedColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w500, color: textColor,
                  )),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: GoogleFonts.inter(
                        fontSize: 12, color: mutedColor,
                      )),
                    ),
                ],
              )),
            ]),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Wrap(spacing: 8, children: options.entries.map((e) {
                final isSelected = e.key == value;
                return GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(e.value, style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? accentColor : mutedColor,
                    )),
                  ),
                );
              }).toList()),
            ),
          ],
        ),
      ),
      if (showDivider)
        Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

// ─── Voice Selection Tile ───────────────────────────────────────────────────

class _VoiceTile extends StatelessWidget {
  final TtsVoiceProfile profile;
  final bool isSelected;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final bool showDivider;

  const _VoiceTile({
    required this.profile,
    required this.isSelected,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    required this.onPreview,
    this.showDivider = true,
  });

  static const _iconMap = {
    'record_voice_over': Icons.record_voice_over_rounded,
    'sailing': Icons.sailing_rounded,
    'two_wheeler': Icons.two_wheeler_rounded,
    'smart_toy': Icons.smart_toy_rounded,
    'elderly': Icons.elderly_rounded,
    'military_tech': Icons.military_tech_rounded,
    'sports_motorsports': Icons.sports_motorsports_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[profile.icon] ?? Icons.record_voice_over_rounded;
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withValues(alpha: 0.15) : mutedColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: isSelected ? accentColor : mutedColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? accentColor : textColor)),
                    Text(profile.description, style: GoogleFonts.inter(
                      fontSize: 12, color: mutedColor)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPreview,
                icon: Icon(Icons.play_circle_outline_rounded, size: 24, color: accentColor),
                tooltip: 'Probe hören',
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 22, color: accentColor),
            ],
          ),
        ),
      ),
      if (showDivider)
        Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

