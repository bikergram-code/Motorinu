import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/models/saved_place.dart';
import '../../providers/blitzer/blitzer_settings_provider.dart';
import '../../providers/blitzer/saved_places_provider.dart';
import '../../providers/core/providers.dart';
import '../../providers/map/live_location_provider.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../services/geocoding_service.dart';
import '../../services/navigation_tts_service.dart';
import '../../theme/app_theme.dart';

// ─── Navigation Settings Screen ──────────────────────────────────────────────
//
// Navigationseinstellungen: Fahrmodus, Route, Gespeicherte Orte, 3D, Batterie, Darstellung

class NavigationSettingsScreen extends ConsumerWidget {
  const NavigationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Navigationseinstellungen',
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
            // ─── Sichtbarkeit ──────────────────────────────────
            _SectionHeader(title: 'Sichtbarkeit', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.visibility_rounded,
                  iconColor: Colors.green,
                  title: 'Auf der Karte sichtbar',
                  subtitle: settings.liveOnMap
                      ? 'Andere Biker sehen dich live'
                      : 'Du bist für andere unsichtbar',
                  value: settings.liveOnMap,
                  onChanged: (v) async {
                    ref.read(blitzerSettingsProvider.notifier)
                        .updateSetting((s) => s.copyWith(liveOnMap: v));
                    final service = ref.read(liveLocationServiceProvider);
                    if (v) {
                      // Go live
                      final authState = ref.read(authNotifierProvider);
                      if (authState is Authenticated) {
                        final user = authState.user;
                        final community = ref.read(communityProvider);
                        await service.goLive(
                          userId: user.id,
                          displayName: user.displayName ?? user.bikername ?? user.username,
                          avatarUrl: user.avatarUrl,
                          plzRegion: user.postalCode,
                          xpTotal: user.xpTotal ?? 0,
                          bikeName: user.bikername,
                          community: community?.name ?? 'bikergram',
                        );
                        ref.read(isLiveProvider.notifier).set(true);
                      }
                    } else {
                      // Go offline
                      await service.goOffline();
                      ref.read(isLiveProvider.notifier).set(false);
                    }
                  },
                  accentColor: accentColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Fahrmodus ───────────────────────────────────
            _SectionHeader(title: 'Fahrmodus', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.gps_fixed_rounded,
                  iconColor: accentColor,
                  title: 'Auto-Follow',
                  subtitle: 'Kamera folgt GPS-Position',
                  value: settings.autoFollowMode,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(autoFollowMode: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.explore_rounded,
                  iconColor: accentColor,
                  title: 'Fahrtrichtung drehen',
                  subtitle: 'Karte dreht mit Heading',
                  value: settings.headingRotation,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(headingRotation: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.speed_rounded,
                  iconColor: accentColor,
                  title: 'Geschwindigkeit anzeigen',
                  value: settings.speedDisplay,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(speedDisplay: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.screen_lock_landscape_rounded,
                  iconColor: accentColor,
                  title: 'Bildschirm an lassen',
                  subtitle: 'Während Navigation',
                  value: settings.keepScreenOn,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(keepScreenOn: v)),
                  accentColor: accentColor,
                ),
                _SliderTile(
                  icon: Icons.zoom_in_rounded,
                  iconColor: accentColor,
                  title: 'Zoom-Level',
                  value: settings.followZoom,
                  min: 14, max: 19, divisions: 10,
                  suffix: 'x',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(followZoom: v)),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _SliderTile(
                  icon: Icons.threed_rotation_rounded,
                  iconColor: accentColor,
                  title: 'Neigung',
                  value: settings.followTilt,
                  min: 0, max: 67, divisions: 10,
                  suffix: '°',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(followTilt: v)),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Navigation ──────────────────────────────────
            _SectionHeader(title: 'Navigation', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.alt_route_rounded,
                  iconColor: Colors.teal,
                  title: 'Auto-Neuberechnung',
                  subtitle: 'Bei Abweichung von der Route',
                  value: settings.autoRecalculate,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(autoRecalculate: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.record_voice_over_rounded,
                  iconColor: Colors.indigo,
                  title: 'Sprachansagen',
                  subtitle: 'Abbiegehinweise vorlesen (TTS)',
                  value: settings.ttsEnabled,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(ttsEnabled: v)),
                  accentColor: accentColor,
                ),
                // Voice picker — shown when TTS is enabled
                if (settings.ttsEnabled)
                  _VoicePicker(
                    currentVoice: settings.ttsVoice,
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onChanged: (voiceId) {
                      ref.read(blitzerSettingsProvider.notifier)
                          .updateSetting((s) => s.copyWith(ttsVoice: voiceId));
                      NavigationTtsService.instance.setVoice(voiceId);
                    },
                  ),
                _Toggle(
                  icon: Icons.radar_rounded,
                  iconColor: Colors.teal,
                  title: 'Blitzer auf Route',
                  subtitle: 'Blitzer entlang der Route anzeigen',
                  value: settings.showBlitzerOnRoute,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(showBlitzerOnRoute: v)),
                  accentColor: accentColor,
                ),
                _SliderTile(
                  icon: Icons.straighten_rounded,
                  iconColor: Colors.teal,
                  title: 'Off-Route Schwelle',
                  value: settings.offRouteThreshold.toDouble(),
                  min: 30, max: 100, divisions: 7,
                  suffix: 'm',
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(offRouteThreshold: v.round())),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Gespeicherte Orte ─────────────────────────────
            _SectionHeader(title: 'Gespeicherte Orte', mutedColor: mutedColor),
            Builder(builder: (_) {
              final places = ref.watch(savedPlacesProvider);
              final home = places.where((p) => p.id == 'home').firstOrNull;
              final work = places.where((p) => p.id == 'work').firstOrNull;
              return _Card(
                cardColor: cardColor,
                children: [
                  _SavedPlaceTile(
                    icon: Icons.home_rounded,
                    iconColor: Colors.green,
                    title: 'Zuhause',
                    subtitle: home?.address ?? 'Nicht festgelegt',
                    hasValue: home != null,
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () => _showPlaceSearchSheet(context, ref, 'home', 'Zuhause', accentColor, textColor, mutedColor, cardColor, brightness),
                    onDelete: home != null ? () => ref.read(savedPlacesProvider.notifier).removePlace('home') : null,
                  ),
                  _SavedPlaceTile(
                    icon: Icons.work_rounded,
                    iconColor: Colors.blue,
                    title: 'Arbeit',
                    subtitle: work?.address ?? 'Nicht festgelegt',
                    hasValue: work != null,
                    accentColor: accentColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () => _showPlaceSearchSheet(context, ref, 'work', 'Arbeit', accentColor, textColor, mutedColor, cardColor, brightness),
                    onDelete: work != null ? () => ref.read(savedPlacesProvider.notifier).removePlace('work') : null,
                    showDivider: false,
                  ),
                ],
              );
            }),

            const SizedBox(height: 24),

            // ─── 3D & Ansicht ─────────────────────────────────
            _SectionHeader(title: '3D & Ansicht', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.view_in_ar_rounded,
                  iconColor: Colors.deepPurple,
                  title: 'Auto-3D bei Navigation',
                  subtitle: 'Karte automatisch in 3D bei Fahrt',
                  value: settings.auto3dNavigation,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(auto3dNavigation: v)),
                  accentColor: accentColor,
                ),
                _Toggle(
                  icon: Icons.threed_rotation_rounded,
                  iconColor: Colors.deepPurple,
                  title: 'Karte immer in 3D',
                  subtitle: '3D-Perspektive dauerhaft aktiv',
                  value: settings.always3d,
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(always3d: v)),
                  accentColor: accentColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Batterie ────────────────────────────────────
            _SectionHeader(title: 'Batterie', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _OptionTile(
                  icon: Icons.battery_charging_full_rounded,
                  iconColor: Colors.green,
                  title: 'Batteriemodus',
                  value: settings.batteryMode,
                  options: const {
                    'performance': 'Leistung',
                    'balanced': 'Ausgewogen',
                    'saver': 'Sparmodus',
                  },
                  subtitle: switch (settings.batteryMode) {
                    'performance' => 'GPS alle 3m • Höchste Genauigkeit',
                    'balanced' => 'GPS alle 5m • Gute Balance',
                    'saver' => 'GPS alle 15m • Batterie schonen',
                    _ => '',
                  },
                  onChanged: (v) => ref.read(blitzerSettingsProvider.notifier)
                      .updateSetting((s) => s.copyWith(batteryMode: v)),
                  accentColor: accentColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Darstellung ───────────────────────────────
            _SectionHeader(title: 'Darstellung', mutedColor: mutedColor),
            _Card(
              cardColor: cardColor,
              children: [
                _Toggle(
                  icon: Icons.dark_mode_rounded,
                  iconColor: Colors.indigo,
                  title: 'Dark Mode',
                  subtitle: brightness == Brightness.dark ? 'Aktiv' : 'Inaktiv',
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                  accentColor: accentColor,
                  showDivider: false,
                ),
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

// ─── Voice Picker ─────────────────────────────────────────────────────────────

class _VoicePicker extends StatelessWidget {
  final String currentVoice;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<String> onChanged;

  const _VoicePicker({
    required this.currentVoice,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
  });

  static const _voiceIcons = <String, IconData>{
    'standard': Icons.record_voice_over_rounded,
    'pirat': Icons.sailing_rounded,
    'biker': Icons.two_wheeler_rounded,
    'robot': Icons.smart_toy_rounded,
    'opa': Icons.elderly_rounded,
    'drill': Icons.military_tech_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final profiles = ttsVoiceProfiles.values.toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 50, bottom: 8),
              child: Text('Stimme wählen', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: mutedColor,
              )),
            ),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 50, right: 16),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final p = profiles[i];
                  final isSelected = p.id == currentVoice;
                  final icon = _voiceIcons[p.id] ?? Icons.record_voice_over_rounded;

                  return GestureDetector(
                    onTap: () {
                      onChanged(p.id);
                      // Play sample
                      NavigationTtsService.instance.speakSample(p.id);
                    },
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.15)
                            : (brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.grey.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon,
                          size: 26,
                          color: isSelected ? accentColor : mutedColor,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? accentColor : textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            // Current voice description
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 6),
              child: Text(
                ttsVoiceProfiles[currentVoice]?.description ?? '',
                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: mutedColor),
              ),
            ),
          ],
        ),
      ),
      Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

// ─── Saved Place Tile ─────────────────────────────────────────────────────────

class _SavedPlaceTile extends StatelessWidget {
  const _SavedPlaceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.hasValue,
    required this.accentColor,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    this.onDelete,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool hasValue;
  final Color accentColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w500, color: textColor,
                )),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hasValue ? mutedColor : accentColor.withValues(alpha: 0.7),
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            )),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: mutedColor),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Icon(Icons.chevron_right_rounded, color: mutedColor, size: 22),
          ]),
        ),
      ),
      if (showDivider)
        Divider(height: 1, indent: 66, color: Colors.white.withValues(alpha: 0.04)),
    ]);
  }
}

// ─── Place Search Bottom Sheet ────────────────────────────────────────────────

void _showPlaceSearchSheet(
  BuildContext context,
  WidgetRef ref,
  String placeId,
  String placeLabel,
  Color accentColor,
  Color textColor,
  Color mutedColor,
  Color cardColor,
  Brightness brightness,
) {
  final searchController = TextEditingController();
  final geocoding = GeocodingService();
  List<GeocodingResult> results = [];
  bool isSearching = false;
  Timer? debounce;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$placeLabel festlegen',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Adresse suchen...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                    prefixIcon: Icon(Icons.search_rounded, color: mutedColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  ),
                  onChanged: (query) {
                    debounce?.cancel();
                    if (query.trim().length < 2) {
                      setSheetState(() { results = []; isSearching = false; });
                      return;
                    }
                    setSheetState(() => isSearching = true);
                    debounce = Timer(const Duration(milliseconds: 400), () async {
                      final r = await geocoding.searchPlace(query.trim());
                      setSheetState(() { results = r; isSearching = false; });
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: isSearching
              ? const Center(child: CircularProgressIndicator())
              : results.isEmpty
                ? Center(child: Text(
                    searchController.text.length < 2
                      ? 'Adresse eingeben...'
                      : 'Kein Ergebnis',
                    style: GoogleFonts.inter(fontSize: 14, color: mutedColor),
                  ))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final r = results[i];
                      return ListTile(
                        leading: Icon(Icons.location_on_rounded, color: accentColor),
                        title: Text(r.shortName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                        subtitle: r.displayName != r.shortName
                          ? Text(r.displayName, style: GoogleFonts.inter(fontSize: 12, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                        onTap: () {
                          final notifier = ref.read(savedPlacesProvider.notifier);
                          if (placeId == 'home') {
                            notifier.setHome(
                              address: r.displayName,
                              lat: r.location.latitude,
                              lng: r.location.longitude,
                            );
                          } else if (placeId == 'work') {
                            notifier.setWork(
                              address: r.displayName,
                              lat: r.location.latitude,
                              lng: r.location.longitude,
                            );
                          }
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
            ),
          ]),
        );
      },
    ),
  );
}
