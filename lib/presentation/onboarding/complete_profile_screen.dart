import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/community.dart';
import '../../domain/badge_calculator.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/auth/auth_state.dart';
import '../../providers/core/providers.dart';
import '../../theme/app_theme.dart';
import 'widgets/experience_celebration.dart';

/// Shown after Google/Apple sign-in when the profile is incomplete
/// (birth_year is null). Collects: birth year, PLZ, experience, track.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  int _currentStep = 0;
  static const _totalSteps = 4;

  final _plzController = TextEditingController();

  int _birthYear = 1990;
  int? _motoStartAge;
  int? _carStartAge;
  bool _hasMoto = true;
  bool _hasCar = true;
  bool _hasTrackExperience = false;
  bool _isSaving = false;
  bool _celebrationShown = false;

  int get _currentAge => DateTime.now().year - _birthYear;

  @override
  void dispose() {
    _plzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Top bar
              Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      onPressed: () =>
                          setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox(width: 40),
                  const Spacer(),
                  Text(
                    'Schritt ${_currentStep + 1} von $_totalSteps',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 3,
                ),
              ),

              const SizedBox(height: 12),

              // Welcome hint (only first step)
              if (_currentStep == 0)
                Text(
                  'Noch schnell dein Profil vervollst\u00e4ndigen \u{1F3CD}\uFE0F',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),

              const SizedBox(height: 20),

              // Step content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(accentColor),
                ),
              ),

              // Bottom button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep < _totalSteps - 1
                              ? 'Weiter'
                              : 'Fertig \u{1F3C1}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step Builder ────────────────────────────────────────────────

  Widget _buildStep(Color accentColor) {
    switch (_currentStep) {
      case 0:
        return _buildBirthYearStep(accentColor);
      case 1:
        return _buildPlzStep(accentColor);
      case 2:
        return _buildExperienceStep(accentColor);
      case 3:
        return _buildTrackStep(accentColor);
      default:
        return const SizedBox();
    }
  }

  // ── Step 0: Birth Year ──────────────────────────────────────────

  Widget _buildBirthYearStep(Color accentColor) {
    final age = _currentAge;
    final ageBadge = BadgeCalculator.getAgeBadge(_birthYear);

    return _StepContent(
      key: const ValueKey('step_birth'),
      title: 'Wie alt\nbist du?',
      subtitle: 'Dein Alter bestimmt deinen Alters-Badge',
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '$age',
                  style: GoogleFonts.inter(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jahre alt',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                if (ageBadge != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ageBadge.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ageBadge.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      ageBadge.displayText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ageBadge.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: _birthYear.toDouble(),
              min: (DateTime.now().year - 99).toDouble(),
              max: (DateTime.now().year - 8).toDouble(),
              divisions: 91,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _birthYear = v.round());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${DateTime.now().year - 99}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3))),
                Text('Geburtsjahr: $_birthYear',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6))),
                Text('${DateTime.now().year - 8}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: PLZ ─────────────────────────────────────────────────

  Widget _buildPlzStep(Color accentColor) {
    return _StepContent(
      key: const ValueKey('step_plz'),
      title: 'Deine\nPostleitzahl',
      subtitle: 'F\u00fcr die Rider Map und lokale Events',
      child: TextField(
        controller: _plzController,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'z.B. 10115',
          hintStyle: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.25)),
          prefixIcon: Icon(Icons.location_on_outlined,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Step 2: Experience ──────────────────────────────────────────

  Widget _buildExperienceStep(Color accentColor) {
    final age = _currentAge;

    return _StepContent(
      key: const ValueKey('step_experience'),
      title: 'Deine\nFahrerfahrung',
      subtitle: 'Seit wann f\u00e4hrst du?',
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildExperienceSection(
              emoji: '\u{1F3CD}\uFE0F',
              title: 'Motorrad / Roller',
              isEnabled: _hasMoto,
              startAge: _motoStartAge,
              maxAge: age,
              accentColor: accentColor,
              onToggle: (v) {
                setState(() {
                  _hasMoto = v;
                  if (!v) _motoStartAge = null;
                  if (v && _motoStartAge == null) _motoStartAge = 16;
                });
              },
              onAgeChanged: (v) => setState(() => _motoStartAge = v),
              badgeLabel: _hasMoto && _motoStartAge != null
                  ? '\u{1F3CD}\uFE0F ${BadgeCalculator.getMotoLabel(age - _motoStartAge!)}'
                  : null,
              experienceYears: _hasMoto && _motoStartAge != null
                  ? age - _motoStartAge!
                  : 0,
            ),
            const SizedBox(height: 20),
            _buildExperienceSection(
              emoji: '\u{1F697}',
              title: 'Auto / PKW',
              isEnabled: _hasCar,
              startAge: _carStartAge,
              maxAge: age,
              accentColor: accentColor,
              onToggle: (v) {
                setState(() {
                  _hasCar = v;
                  if (!v) _carStartAge = null;
                  if (v && _carStartAge == null) _carStartAge = 18;
                });
              },
              onAgeChanged: (v) => setState(() => _carStartAge = v),
              badgeLabel: _hasCar && _carStartAge != null
                  ? '\u{1F697} ${BadgeCalculator.getCarLabel(age - _carStartAge!)}'
                  : null,
              experienceYears: _hasCar && _carStartAge != null
                  ? age - _carStartAge!
                  : 0,
            ),
            if (!_hasMoto && !_hasCar) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorDark.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorDark.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.errorDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bitte w\u00e4hle mindestens eine Fahrzeugart',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppTheme.errorDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceSection({
    required String emoji,
    required String title,
    required bool isEnabled,
    required int? startAge,
    required int maxAge,
    required Color accentColor,
    required ValueChanged<bool> onToggle,
    required ValueChanged<int> onAgeChanged,
    required String? badgeLabel,
    required int experienceYears,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? const Color(0xFF1A1A1A)
            : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? accentColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                onChanged: onToggle,
                activeColor: accentColor,
              ),
            ],
          ),
          if (isEnabled && startAge != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Seit ich ',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6))),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$startAge',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor)),
                ),
                Text(' bin  \u2192  ',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6))),
                Text('$experienceYears Jahre',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor:
                    Colors.white.withValues(alpha: 0.08),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: startAge.toDouble().clamp(8, maxAge.toDouble()),
                min: 8,
                max: maxAge.toDouble().clamp(9, 99),
                divisions: (maxAge - 8).clamp(1, 91),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onAgeChanged(v.round());
                },
              ),
            ),
            if (badgeLabel != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(badgeLabel,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accentColor)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Step 3: Track ───────────────────────────────────────────────

  Widget _buildTrackStep(Color accentColor) {
    return _StepContent(
      key: const ValueKey('step_track'),
      title: 'Warst du schon\nauf der Rennstrecke?',
      subtitle: 'Track Days, Rennstreckentraining etc.',
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildTrackOption(
            emoji: '\u{1F3C1}',
            label: 'Ja, war ich!',
            subtitle: 'Du erh\u00e4ltst den Track Racer Badge',
            isSelected: _hasTrackExperience,
            accentColor: accentColor,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _hasTrackExperience = true);
            },
          ),
          const SizedBox(height: 12),
          _buildTrackOption(
            emoji: '\u{1F6E3}\uFE0F',
            label: 'Nein, noch nicht',
            subtitle: 'Kein Problem, die Stra\u00dfe reicht!',
            isSelected: !_hasTrackExperience,
            accentColor: accentColor,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _hasTrackExperience = false);
            },
          ),
          if (_hasTrackExperience) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFE53935).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE53935)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('\u{1F3C1}',
                      style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text('Track Racer Badge freigeschaltet!',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE53935))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackOption({
    required String emoji,
    required String label,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color:
                              Colors.white.withValues(alpha: 0.45))),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: accentColor, size: 24),
          ],
        ),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────

  void _handleNext() {
    switch (_currentStep) {
      case 0: // Birth year
        if (_currentAge < 8 || _currentAge > 99) {
          _showError('Alter muss zwischen 8 und 99 sein');
          return;
        }
        if (_motoStartAge == null && _hasMoto) {
          _motoStartAge = (_currentAge >= 16) ? 16 : 8;
        }
        if (_carStartAge == null && _hasCar) {
          _carStartAge = (_currentAge >= 18) ? 18 : _currentAge;
        }
        break;

      case 1: // PLZ
        final plz = _plzController.text.trim();
        if (plz.isEmpty || !RegExp(r'^\d{4,6}$').hasMatch(plz)) {
          _showError(
              'Bitte gib eine g\u00fcltige PLZ ein (4-6 Ziffern)');
          return;
        }
        break;

      case 2: // Experience
        if (!_hasMoto && !_hasCar) {
          _showError('Bitte w\u00e4hle mindestens eine Fahrzeugart');
          return;
        }
        // Celebrate high experience!
        if (!_celebrationShown) {
          final motoYears = _hasMoto && _motoStartAge != null
              ? _currentAge - _motoStartAge!
              : 0;
          final carYears = _hasCar && _carStartAge != null
              ? _currentAge - _carStartAge!
              : 0;
          final maxYears = motoYears > carYears ? motoYears : carYears;
          if (ExperienceCelebration.maybeShow(context, maxYears)) {
            _celebrationShown = true;
          }
        }
        break;

      case 3: // Track — save & finish
        _saveProfile();
        return;
    }

    HapticFeedback.lightImpact();
    setState(() => _currentStep++);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        birthYear: _birthYear,
        postalCode: _plzController.text.trim(),
        motoStartAge: _hasMoto ? _motoStartAge : null,
        carStartAge: _hasCar ? _carStartAge : null,
        hasTrackExperience: _hasTrackExperience,
      );

      // Reload profile so badges appear
      await ref.read(authNotifierProvider.notifier).checkAuth();

      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Fehler beim Speichern: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: AppTheme.errorDark,
      ),
    );
  }
}

// ── Step Content Wrapper ────────────────────────────────────────

class _StepContent extends StatelessWidget {
  const _StepContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}
