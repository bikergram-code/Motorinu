import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import 'biker_rewards.dart';
import 'comic_speech_bubble.dart';

/// Wizard kompatibel:
/// DiySkillsStepWidget(
///   diySkills: ...,
///   onChanged: (v) => ...
/// )
///
/// Optional kompatibel zu älteren Aufrufen:
/// DiySkillsStepWidget(selectedSkills: ..., onSkillsChanged: ...)
class DiySkillsStepWidget extends StatefulWidget {
  final String userName;

  // NEW: Wizard expects this
  final List<String>? diySkills;
  final ValueChanged<List<String>>? onChanged;

  // OLD (optional)
  final List<String>? selectedSkills;
  final ValueChanged<List<String>>? onSkillsChanged;

  const DiySkillsStepWidget({
    super.key,
    this.userName = '',
    this.diySkills,
    this.onChanged,
    this.selectedSkills,
    this.onSkillsChanged,
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/10bikerin_diy.png';

  @override
  State<DiySkillsStepWidget> createState() => _DiySkillsStepWidgetState();
}

class _DiySkillsStepWidgetState extends State<DiySkillsStepWidget> {
  late List<String> _selected;
  bool _explicitNoMechanic = false;

  static const _skills = <String>[
    'Schrauben',
    'Öl / Filter',
    'Reifen',
    'Kette',
    'Bremsen',
    'Elektrik',
    'Tuning',
    'Custom/DIY',
  ];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.diySkills ?? widget.selectedSkills ?? const <String>[]);
  }

  void _toggle(String s) {
    setState(() {
      _explicitNoMechanic = false;

      if (_selected.contains(s)) {
        _selected.remove(s);
      } else {
        _selected.add(s);
      }
    });
    widget.onChanged?.call(List<String>.from(_selected));
    widget.onSkillsChanged?.call(List<String>.from(_selected));
    // Reward only in DIY step
    BikerRewards.maybeDiyTierReward(context, selectedCount: _selected.length);
  }

    void _setNoMechanic() {
    setState(() {
      _explicitNoMechanic = true;
      _selected.clear();
    });
    widget.onChanged?.call(const <String>[]);
    widget.onSkillsChanged?.call(const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip(String s) {
      final on = _selected.contains(s);
      return InkWell(
        onTap: () => _toggle(s),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: on
                ? theme.colorScheme.primary.withOpacity(0.18)
                : theme.colorScheme.surface.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on
                  ? theme.colorScheme.primary.withOpacity(0.55)
                  : theme.colorScheme.outline.withOpacity(0.18),
              width: on ? 2 : 1.5,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      blurRadius: 18,
                      color: theme.colorScheme.primary.withOpacity(0.18),
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_circle : Icons.build,
                size: 18,
                color: on ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                s,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            DiySkillsStepWidget._carbonAsset,
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
                const SizedBox(height: 4),

                ComicSpeechBubble(
                  text: (widget.userName.trim().isNotEmpty)
                      ? '''Okay ${widget.userName.trim()}!
Wie gut bist du im Schrauben?
Wähle alles, was du selbst machst 🔧'''
                      : '''Wie gut bist du im Schrauben?
Wähle alles, was du selbst machst 🔧''',
                  tailOnRight: true,
                  opacity: 0.95,
                ),

                SizedBox(height: 2.h),

                Container(
                  height: 30.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        color: Colors.black.withOpacity(0.35),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    DiySkillsStepWidget._heroAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      alignment: Alignment.center,
                      color: Colors.black.withOpacity(0.2),
                      child: const Text(
                        'Bild fehlt: 10bikerin_diy.png',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 2.2.h),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Deine DIY-Skills',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 1.4.h),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _setNoMechanic,
                            icon: const Icon(Icons.pan_tool_alt_outlined),
                            label: const Text('Kein Schrauber'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: _explicitNoMechanic ? 1 : 0,
                              child: Text(
                                'Alles gut – du musst nichts auswählen.\nWir setzen einfach „Nicht-Schrauber“ 🙂',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.6.h),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _skills.map(chip).toList(),
                      ),
                      SizedBox(height: 1.2.h),
                      Text(
                        'Du kannst später jederzeit Skills hinzufügen oder entfernen.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 2.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}
