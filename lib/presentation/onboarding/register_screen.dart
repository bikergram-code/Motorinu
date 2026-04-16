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
import 'widgets/social_sign_in_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _plzController = TextEditingController();
  bool _obscurePassword = true;

  // 8 steps: 0=name, 1=email, 2=birthYear, 3=plz, 4=experience, 5=track, 6=interests, 7=password
  int _currentStep = 0;
  static const _totalSteps = 8;

  // New fields
  int _birthYear = 1990;
  int? _motoStartAge;
  int? _carStartAge;
  bool _hasMoto = true;
  bool _hasCar = true;
  bool _hasTrackExperience = false;
  bool _celebrationShown = false;
  bool _interestedInDating = false;
  bool _interestedInMarketplace = true;
  bool _interestedInEvents = true;
  bool _interestedInNavigation = true;

  int get _currentAge => DateTime.now().year - _birthYear;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _plzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final community = ref.watch(communityProvider);
    final isLoading = authState is AuthLoading;
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    ref.listen<AuthState>(authNotifierProvider, (prev, state) {
      if (state is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: AppTheme.errorDark,
          ),
        );
      }
      // After successful registration → show app tour
      if (prev is AuthLoading && state is Authenticated) {
        context.go('/app-tour');
      }
      // Email confirmation required → still show the app tour,
      // then land on login with a "check your email" banner.
      if (prev is AuthLoading && state is EmailConfirmationPending) {
        context.go('/app-tour', extra: {'pendingEmail': state.email});
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed header: back button + step counter + progress ──
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_currentStep > 0) {
                            setState(() => _currentStep--);
                          } else {
                            context.go('/login');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/motorino_icon.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content area ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Step content (no inner scroll!)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildStepNoScroll(accentColor),
                    ),

                    const SizedBox(height: 24),

                    // Bottom button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
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
                                    : 'Konto erstellen',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    // Show social buttons only on first 2 steps
                    if (_currentStep < 2) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'oder',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SocialSignInButtons(
                        isLoading: isLoading,
                        onGooglePressed: () {
                          ref
                              .read(authNotifierProvider.notifier)
                              .signInWithGoogle();
                        },
                        onApplePressed: () {
                          ref
                              .read(authNotifierProvider.notifier)
                              .signInWithApple();
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Login link
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            children: [
                              const TextSpan(text: 'Bereits ein Konto? '),
                              TextSpan(
                                text: 'Anmelden',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step Builder (no inner scroll — parent handles scrolling) ───

  Widget _buildStepNoScroll(Color accentColor) {
    switch (_currentStep) {
      case 0:
        return _stepColumn(
          key: 'step_name',
          title: 'W\u00e4hle deinen\nBenutzernamen',
          subtitle: 'So wirst du in der Community angezeigt',
          child: _buildTextField(
            controller: _usernameController,
            hint: 'z.B. RiderMax42',
            icon: Icons.person_outline_rounded,
            accentColor: accentColor,
            autofocus: true,
          ),
        );

      case 1:
        return _stepColumn(
          key: 'step_email',
          title: 'Deine\nE-Mail Adresse',
          subtitle: 'Wir senden dir eine Best\u00e4tigung',
          child: _buildTextField(
            controller: _emailController,
            hint: 'deine@email.de',
            icon: Icons.mail_outline_rounded,
            accentColor: accentColor,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
        );

      case 2:
        return _buildBirthYearStep(accentColor);

      case 3:
        return _stepColumn(
          key: 'step_plz',
          title: 'Deine\nPostleitzahl',
          subtitle: 'F\u00fcr die Rider Map und lokale Events',
          child: _buildTextField(
            controller: _plzController,
            hint: 'z.B. 10115',
            icon: Icons.location_on_outlined,
            accentColor: accentColor,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
        );

      case 4:
        return _buildExperienceStep(accentColor);

      case 5:
        return _buildTrackStep(accentColor);

      case 6:
        return _buildInterestsStep(accentColor);

      case 7:
        return _stepColumn(
          key: 'step_password',
          title: 'Erstelle ein\nsicheres Passwort',
          subtitle: 'Mindestens 8 Zeichen',
          child: Column(
            children: [
              _buildTextField(
                controller: _passwordController,
                hint: 'Passwort',
                icon: Icons.lock_outline_rounded,
                accentColor: accentColor,
                obscure: _obscurePassword,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmController,
                hint: 'Passwort best\u00e4tigen',
                icon: Icons.lock_outline_rounded,
                accentColor: accentColor,
                obscure: _obscurePassword,
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  /// Simple column with title + subtitle + child — NO scroll wrapper.
  Widget _stepColumn({
    required String key,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      key: ValueKey(key),
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
    );
  }

  // ── Step 2: Birth Year ──────────────────────────────────────────

  Widget _buildBirthYearStep(Color accentColor) {
    final age = _currentAge;
    final ageBadge = BadgeCalculator.getAgeBadge(_birthYear);

    return _stepColumn(
      key: 'step_birth',
      title: 'Wie alt\nbist du?',
      subtitle: 'Dein Alter bestimmt deinen Alters-Badge',
      child: Column(
        children: [
          // Big age display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
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

          // Slider
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
              label: 'Geburtsjahr: $_birthYear',
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
                Text(
                  '${DateTime.now().year - 99}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  'Geburtsjahr: $_birthYear',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '${DateTime.now().year - 8}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Driving Experience ──────────────────────────────────

  Widget _buildExperienceStep(Color accentColor) {
    final age = _currentAge;

    return _stepColumn(
      key: 'step_experience',
      title: 'Deine\nFahrerfahrung',
      subtitle: 'Seit wann f\u00e4hrst du?',
      child: Column(
          children: [
            // ── Motorrad Section ──
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
              experienceYears:
                  _hasMoto && _motoStartAge != null ? age - _motoStartAge! : 0,
            ),

            const SizedBox(height: 20),

            // ── Auto Section ──
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
              experienceYears:
                  _hasCar && _carStartAge != null ? age - _carStartAge! : 0,
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
                          fontSize: 13,
                          color: AppTheme.errorDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
          // Header with toggle
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

            // "Seit ich X bin" text
            Row(
              children: [
                Text(
                  'Seit ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$startAge',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
                Text(
                  ' J. \u2192 ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Flexible(
                  child: Text(
                    '$experienceYears Jahre Erfahrung',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: startAge.toDouble().clamp(8, maxAge.toDouble()),
                min: 8,
                max: maxAge.toDouble().clamp(9, 99),
                divisions:
                    (maxAge - 8).clamp(1, 91),
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onAgeChanged(v.round());
                },
              ),
            ),

            // Badge preview
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
                      color: accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Step 5: Track Experience ────────────────────────────────────

  Widget _buildTrackStep(Color accentColor) {
    return _stepColumn(
      key: 'step_track',
      title: 'Warst du schon\nauf der Rennstrecke?',
      subtitle: 'Track Days, Rennstreckentraining etc.',
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Yes button
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

          // No button
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
                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('\u{1F3C1}', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Track Racer Badge freigeschaltet!',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE53935),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
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

  // ── Step 6: Interests ───────────────────────────────────────────

  Widget _buildInterestsStep(Color accentColor) {
    return _stepColumn(
      key: 'step_interests',
      title: 'Was interessiert\ndich?',
      subtitle: 'Wir passen die App an deine Interessen an',
      child: Column(
          children: [
            _buildInterestTile(
              emoji: '\u{1F6E3}\uFE0F',
              title: 'Navigation & Touren',
              subtitle: 'Routen planen, Gruppenfahrten, GPS-Tracking',
              isSelected: _interestedInNavigation,
              accentColor: accentColor,
              onTap: () => setState(() => _interestedInNavigation = !_interestedInNavigation),
            ),
            const SizedBox(height: 10),
            _buildInterestTile(
              emoji: '\u{1F6D2}',
              title: 'Marktplatz',
              subtitle: 'Bikes, Teile & Zubeh\u00f6r kaufen/verkaufen',
              isSelected: _interestedInMarketplace,
              accentColor: accentColor,
              onTap: () => setState(() => _interestedInMarketplace = !_interestedInMarketplace),
            ),
            const SizedBox(height: 10),
            _buildInterestTile(
              emoji: '\u{1F3AD}',
              title: 'Events & Treffen',
              subtitle: 'Biker-Treffen, Stammtische, Ausfahrten',
              isSelected: _interestedInEvents,
              accentColor: accentColor,
              onTap: () => setState(() => _interestedInEvents = !_interestedInEvents),
            ),
            const SizedBox(height: 10),
            _buildInterestTile(
              emoji: '\u2764\uFE0F',
              title: 'Dating / Lovo',
              subtitle: 'Biker & Bikerinnen kennenlernen',
              isSelected: _interestedInDating,
              accentColor: accentColor,
              onTap: () {
                setState(() => _interestedInDating = !_interestedInDating);
                if (_interestedInDating) {
                  HapticFeedback.mediumImpact();
                }
              },
            ),
            if (_interestedInDating && _currentAge < 18) ...[
              const SizedBox(height: 12),
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
                    const Icon(Icons.info_outline, color: AppTheme.errorDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dating ist erst ab 18 Jahren verf\u00fcgbar',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.errorDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
    );
  }

  Widget _buildInterestTile({
    required String emoji,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(Icons.check_circle_rounded, color: accentColor, size: 22, key: const ValueKey('on'))
                  : Icon(Icons.circle_outlined, color: Colors.white.withValues(alpha: 0.15), size: 22, key: const ValueKey('off')),
            ),
          ],
        ),
      ),
    );
  }

  // ── Text Field Builder ──────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofocus: autofocus,
      style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.25),
        ),
        prefixIcon:
            Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────

  void _handleNext() {
    switch (_currentStep) {
      case 0: // Username
        if (_usernameController.text.trim().isEmpty) {
          _showError('Bitte gib einen Benutzernamen ein');
          return;
        }
        break;

      case 1: // Email
        if (_emailController.text.trim().isEmpty) {
          _showError('Bitte gib deine E-Mail Adresse ein');
          return;
        }
        break;

      case 2: // Birth year
        if (_currentAge < 8 || _currentAge > 99) {
          _showError('Alter muss zwischen 8 und 99 sein');
          return;
        }
        // Initialize experience start ages based on age
        if (_motoStartAge == null && _hasMoto) {
          _motoStartAge = (_currentAge >= 16) ? 16 : 8;
        }
        if (_carStartAge == null && _hasCar) {
          _carStartAge = (_currentAge >= 18) ? 18 : _currentAge;
        }
        break;

      case 3: // PLZ
        final plz = _plzController.text.trim();
        if (plz.isEmpty || !RegExp(r'^\d{4,6}$').hasMatch(plz)) {
          _showError('Bitte gib eine g\u00fcltige PLZ ein (4-6 Ziffern)');
          return;
        }
        break;

      case 4: // Experience
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

      case 5: // Track — always valid
        break;

      case 6: // Interests — always valid
        // Enforce: dating only 18+
        if (_interestedInDating && _currentAge < 18) {
          setState(() => _interestedInDating = false);
        }
        break;

      case 7: // Password
        if (_passwordController.text.length < 8) {
          _showError('Passwort muss mindestens 8 Zeichen lang sein');
          return;
        }
        if (_passwordController.text != _confirmController.text) {
          _showError('Passw\u00f6rter stimmen nicht \u00fcberein');
          return;
        }
        // SUBMIT
        ref.read(authNotifierProvider.notifier).register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              username: _usernameController.text.trim(),
              birthYear: _birthYear,
              postalCode: _plzController.text.trim(),
              motoStartAge: _hasMoto ? _motoStartAge : null,
              carStartAge: _hasCar ? _carStartAge : null,
              hasTrackExperience: _hasTrackExperience,
              interestedInDating: _interestedInDating && _currentAge >= 18,
            );
        return;
    }

    HapticFeedback.lightImpact();
    setState(() => _currentStep++);
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
