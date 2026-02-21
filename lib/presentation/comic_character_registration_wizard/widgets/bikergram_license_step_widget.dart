import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'comic_speech_bubble.dart';
import 'badge_logic.dart';
import 'biker_rewards.dart';

class BikergramLicenseStepWidget extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> formData;
  final Future<void> Function()? onFinish;
  final VoidCallback? onEdit;

  const BikergramLicenseStepWidget({
    super.key,
    this.userName = '',
    required this.formData,
    this.onFinish,
    this.onEdit,
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _ladyAsset = 'assets/images/11bikerin_picture.png';

  @override
  State<BikergramLicenseStepWidget> createState() => _BikergramLicenseStepWidgetState();
}

class _BikergramLicenseStepWidgetState extends State<BikergramLicenseStepWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final int age = (widget.formData['age'] ?? 18) as int;
    final int ridingYears = ((widget.formData['ridingExperience'] ?? 0) as num).round();
    final bool hasTrack = (widget.formData['hasTrackExperience'] ?? false) == true;
    final int bikeCount = (widget.formData['bikeCount'] ?? 0) as int;
    final List<String> diySkills = List<String>.from(widget.formData['diySkills'] ?? const <String>[]);
    final Uint8List? picture = widget.formData['pictureBytes'] as Uint8List?;

    final result = BadgeLogic.buildLicense(
      age: age,
      ridingYears: ridingYears,
      hasTrackExperience: hasTrack,
      bikeCount: bikeCount,
      diySkills: diySkills,
    );

    final rewardsFuture = Future.wait([
      BikerRewards.getPoints(),
      BikerRewards.getBadges(),
    ]);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            BikergramLicenseStepWidget._carbonAsset,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.22),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF15181E), Color(0xFF07080B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ComicSpeechBubble(
                  text: (widget.userName.trim().isNotEmpty)
                      ? 'Willkommen ${widget.userName.trim()}!\nDein offizieller Führerschein 🪪'
                      : 'Willkommen bei BIKERGRAM!\nDein offizieller Führerschein 🪪',
                  tailOnRight: true,
                  opacity: 0.95,
                ),
                SizedBox(height: 2.h),

                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    return _HologramFrame(
                      t: _c.value,
                      child: FutureBuilder<List<Object?>>( 
                        future: rewardsFuture,
                        builder: (context, snap) {
                          final wizardXp = (snap.data?[0] as int?) ?? 0;
                          final wizardBadges = (snap.data?[1] as List<String>?) ?? const <String>[];
                          return _LicenseCard(
                            name: (widget.formData['name'] ?? 'Biker') as String,
                            riderId: (widget.formData['riderId'] ?? 'BG-${DateTime.now().millisecondsSinceEpoch % 1000000}') as String,
                            age: age,
                            picture: picture,
                            experience: result.experience,
                            extraBadges: result.extraBadges,
                            wizardXp: wizardXp,
                            wizardBadges: wizardBadges,
                          );
                        },
                      ),
                    );
                  },
                ),

                SizedBox(height: 2.2.h),

                // Lady header + actions (per your request)
                                // (Bild entfernt)
SizedBox(height: 0.8.h),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Zurück'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.30)),
                          padding: EdgeInsets.symmetric(vertical: 1.4.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (widget.onFinish != null) {
                            await widget.onFinish!();
                          }
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('Profil abschließen'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 1.4.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HologramFrame extends StatelessWidget {
  final double t;
  final Widget child;

  const _HologramFrame({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    final glow = 0.14 + 0.10 * sin(t * 2 * pi);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            spreadRadius: 1,
            color: Colors.cyanAccent.withOpacity(glow),
          ),
          BoxShadow(
            blurRadius: 30,
            spreadRadius: 2,
            color: Colors.purpleAccent.withOpacity(glow * 0.8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: child,
      ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final String name;
  final String riderId;
  final int age;
  final Uint8List? picture;
  final ExperienceBadge experience;
  final List<String> extraBadges;
  final int wizardXp;
  final List<String> wizardBadges;

  const _LicenseCard({
    required this.name,
    required this.riderId,
    required this.age,
    required this.picture,
    required this.experience,
    required this.extraBadges,
    required this.wizardXp,
    required this.wizardBadges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(picture: picture),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIKERGRAM FÜHRERSCHEIN',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.92),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $riderId   •   Alter: $age',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _GlassInfoRow(
            label: 'Level',
            value: '${experience.icon} ${experience.title}',
            valueColor: experience.color,
          ),
          const SizedBox(height: 8),
          Text(
            experience.comment,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.90),
            ),
          ),

          const SizedBox(height: 12),

          _GlassBadgeWrap(
            title: 'Badges',
            badges: [...extraBadges, ...wizardBadges],
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Text(
                'GESAMT: $wizardXp XP',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Uint8List? picture;
  const _Avatar({required this.picture});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        color: Colors.black.withOpacity(0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: picture == null
          ? const Icon(Icons.person, color: Colors.white70, size: 42)
          : Image.memory(picture!, fit: BoxFit.cover),
    );
  }
}

class _GlassInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _GlassInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: (valueColor ?? Colors.white).withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBadgeWrap extends StatelessWidget {
  final String title;
  final List<String> badges;

  const _GlassBadgeWrap({required this.title, required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final unique = <String>[];
    for (final b in badges) {
      if (b.trim().isEmpty) continue;
      if (!unique.contains(b)) unique.add(b);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.90),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (unique.isEmpty)
                _BadgeChip(text: '—'),
              ...unique.map((b) => _BadgeChip(text: b)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String text;
  const _BadgeChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }
}
