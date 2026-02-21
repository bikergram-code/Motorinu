import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/netcup/draft_store_provider.dart';
import '../../core/netcup/profile_draft_store.dart';
import '../../core/netcup/api_client.dart';
import '../../core/netcup/netcup_auth.dart';
import '../../core/auth/bikergram_auth_api.dart';
import '../../core/auth/auth_token_store.dart';
import '../../core/api_client.dart' as core_api;
import '../user_profile/profile_persistence.dart' as up;
import './widgets/biker_rewards.dart';
import '../../routes/app_routes.dart';

import '../../widgets/custom_icon_widget.dart';

import './widgets/moped_progress_indicator.dart';
import './widgets/welcome_intro_step_widget.dart';
import './widgets/language_step_widget.dart';
import './widgets/name_step_widget.dart';
import './widgets/age_step_widget.dart';
import './widgets/postal_code_step_widget.dart';
import './widgets/email_step_widget.dart';
import './widgets/riding_experience_step_widget.dart';
import './widgets/track_experience_step_widget.dart';
import './widgets/bike_count_step_widget.dart';
import './widgets/diy_skills_step_widget.dart';
import './widgets/bikergram_license_step_widget.dart';
import './widgets/picture_step_widget.dart';
import './widgets/password_step_widget.dart';

class ComicCharacterRegistrationWizard extends StatefulWidget {
  const ComicCharacterRegistrationWizard({super.key});

  @override
  State<ComicCharacterRegistrationWizard> createState() =>
      _ComicCharacterRegistrationWizardState();
}

class _ComicCharacterRegistrationWizardState
    extends State<ComicCharacterRegistrationWizard> {
  final PageController _pageController = PageController();

  // Draft store (Netcup / MySQL)
  late final ProfileDraftStore _draftStore = DraftStoreProvider.store;

  bool _submitting = false;
  String? _submitError;

  int _currentStep = 0;
  int _submitAttempt = 0;
  final int _totalSteps = 13;

  bool _languageNavInProgress = false;

  final Map<String, dynamic> _formData = {
    'language': null,
    'name': '',
    'age': 25,
    'postalCode': '',
    'email': '',
    'ridingExperience': 0.0,
    'hasTrackExperience': false,
    'bikeCount': 1,
    'diySkills': <String>[],
    'pictureBytes': null,
    'password': '',
  };

  final Map<int, bool> _stepValidation = {
    0: true,
    1: false,
    2: false,
    3: true,
    4: false,
    5: false,
    6: true,
    7: true,
    8: true,
    9: true,
    10: true,
    11: false,
    12: true,
  };

  void _onNextPressed() {
    final ok = (_stepValidation[_currentStep] ?? true) == true;
    if (ok) {
      _nextStep();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _submitAttempt++);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    if (_currentStep < _totalSteps - 1 &&
        (_stepValidation[_currentStep] ?? true)) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onWizardSwipeEnd(DragEndDetails details) {
    // Avoid interfering with text input gestures.
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return;

    final v = details.primaryVelocity ?? 0.0;
    if (v.abs() < 350) return;

    if (v > 0) {
      _previousStep();
    } else {
      _onNextPressed();
    }
  }



  void _updateFormData(String key, dynamic value) {
    setState(() => _formData[key] = value);
  }

  void _updateStepValidation(int step, bool isValid) {
    setState(() => _stepValidation[step] = isValid);
  }

  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v == null) return;
      if (v is Uint8List) {
        out[k] = base64Encode(v);
        return;
      }
      if (v is List) {
        out[k] = v.map((e) => e is Uint8List ? base64Encode(e) : e).toList();
        return;
      }
      out[k] = v;
    });
    return out;
  }

  Future<void> _persistCurrentStep() async {
    // Persist only serializable data per step. Safe to call even if backend is unavailable.
    try {
      await _draftStore.ensureDraft();
      final step = _currentStep;
      Map<String, dynamic> data = {};
      switch (step) {
        case 1:
          data = {'language': _formData['language']};
          break;
        case 2:
          data = {'name': _formData['name']};
          break;
        case 3:
          data = {'age': _formData['age']};
          break;
        case 4:
          data = {'postalCode': _formData['postalCode']};
          break;
        case 5:
          data = {'email': _formData['email']};
          break;
        case 6:
          data = {'ridingExperience': _formData['ridingExperience']};
          break;
        case 7:
          data = {'hasTrackExperience': _formData['hasTrackExperience']};
          break;
        case 8:
          data = {'bikeCount': _formData['bikeCount']};
          break;
        case 9:
          data = {'diySkills': _formData['diySkills']};
          break;
        case 10:
          // Store image as base64 (server stores JSON)
          data = {'pictureBase64': _formData['pictureBytes']};
          break;
        case 11:
          // Server accepts pw (and optionally password). We store it as pw.
          data = {'pw': _formData['password']};
          break;
        default:
          data = {};
      }
      if (data.isNotEmpty) {
        await _draftStore.saveStep(step, _sanitizeForJson(data), markCompleted: true);
      }
    } catch (_) {}
  }

  Future<void> _completeRegistration() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      HapticFeedback.mediumImpact();

      // Make sure we have a server draft id.
      await _draftStore.ensureDraft();

      final email = (_formData['email'] ?? '').toString().trim();
      final name = (_formData['name'] ?? '').toString().trim();
      final pwd = (_formData['password'] ?? '').toString();

      // Persist credentials in a deterministic step (step 1) so submit can always find them.
      // Backend accepts 'pw' or 'password'. We store 'pw'.
      if (email.isNotEmpty && pwd.isNotEmpty) {
        await _draftStore.saveStep(
          1,
          _sanitizeForJson({'email': email, 'name': name, 'pw': pwd}),
          markCompleted: true,
        );
      }

      // Save full snapshot (last write wins on backend merge)
      final snapshot = Map<String, dynamic>.from(_formData);
      final sanitized = _sanitizeForJson(snapshot);

      // Normalize password key for backend.
      if (pwd.isNotEmpty) {
        sanitized['pw'] = pwd;
      }
      sanitized.remove('password');

      await _draftStore.saveStep(99, sanitized, markCompleted: true);

      // Also store current XP/Badges into the draft payload (optional)
      final xp = await BikerRewards.getPoints();
      final badges = await BikerRewards.getBadges();
      await _draftStore.saveStep(100, {'xp': xp, 'badges': badges}, markCompleted: true);

      // 1) Draft submit is optional (your backend might not have draft endpoints yet).
      //    If it fails, we continue anyway.
      try {
        await _draftStore.submitAndReturn(body: {
          if (email.isNotEmpty) 'email': email,
          if (pwd.isNotEmpty) 'pw': pwd,
          if (pwd.isNotEmpty) 'password': pwd,
        });
      } catch (_) {
        // ignore
      }

      // 2) REAL auth against your live API.
      //    - First try register
      //    - If already exists: try login
      final authApi = BikergramAuthApi();
      BikergramAuthResponse auth;
      try {
        auth = await authApi.register(
          email: email,
          password: pwd,
          username: name.isNotEmpty ? name : null,
        );
      } catch (_) {
        auth = await authApi.login(email: email, password: pwd);
      }

      // Persist tokens in secure storage (+ web fallback) + set token for both clients.
      await WizardTokenStore.saveTokens(auth.tokens);
      await NetcupAuth.saveBearerToken(auth.tokens.accessToken); // compat for netcup client
      await ApiClient.instance.setToken(auth.tokens.accessToken); // netcup client
      await core_api.ApiClient.instance.setToken(auth.tokens.accessToken); // core client

      // Persist locally for the in-app profile screen
      await up.ProfilePersistence.saveProfile(Map<String, dynamic>.from(_formData));

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.mainSocialFeed,
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }



  void _autoGoToLanguage() {
    setState(() => _currentStep = 1);
    _pageController.jumpToPage(1);
  }

  void _selectLanguageAndGoNext(String? language) {
    if (language == null || _languageNavInProgress) return;
    _languageNavInProgress = true;

    _formData['language'] = language;
    _stepValidation[1] = true;

    HapticFeedback.lightImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _currentStep = 2);
      _pageController.jumpToPage(2);
      _languageNavInProgress = false;
    });
  }

  // Prevents "BoxConstraints forces an infinite height" for scrollable steps.
  Widget _wrapInScroll(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String _userName = (_formData['name'] as String?)?.trim() ?? '';

    final showNavButton = _currentStep > 1 && _currentStep < _totalSteps - 1;

    final submitError = _submitError;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _onWizardSwipeEnd,
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: _currentStep > 0
            ? IconButton(
                icon: CustomIconWidget(
                  iconName: 'arrow_back',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                onPressed: _previousStep,
              )
            : null,
        title: const Text('Profil erstellen'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            MopedProgressIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  if (i != _currentStep) setState(() => _currentStep = i);
                },
                children: [
                  // keep unwrapped
                  WelcomeIntroStepWidget(
                    onAutoNext: _autoGoToLanguage,
                  ),
                  // keep unwrapped
                  LanguageStepWidget(
                    selectedLanguage: _formData['language'],
                    onLanguageSelected: _selectLanguageAndGoNext,
                  ),

                  _wrapInScroll(
                    NameStepWidget(
                      name: _formData['name'],
                      userName: _userName,
                      submitAttempt: _submitAttempt,
                      onChanged: (v) {
                        _updateFormData('name', v);
                        final ok = RegExp(r'^[A-Za-z0-9Ã„Ã–ÃœÃ¤Ã¶Ã¼ÃŸ_.!?@#-]{3,18}$').hasMatch(v.trim());
                        _updateStepValidation(2, ok);
                      },
                      onSubmit: _onNextPressed,
                    ),
                  ),

                  _wrapInScroll(
                    AgeStepWidget(
                      age: _formData['age'],
                      userName: _userName,
                      onAgeChanged: (v) {
                        _updateFormData('age', v);
                        _updateStepValidation(3, v >= 8 && v <= 110);
                      },
                    ),
                  ),

                  _wrapInScroll(
                    PostalCodeStepWidget(
                      postalCode: _formData['postalCode'],
                      userName: _userName,
                      submitAttempt: _submitAttempt,
                      onChanged: (v) {
                        _updateFormData('postalCode', v);
                        final ok = RegExp(r'^\d{4,6}$').hasMatch(v.trim());
                        _updateStepValidation(4, ok);
                      },
                    ),
                  ),

                  _wrapInScroll(
                    EmailStepWidget(
                      email: _formData['email'],
                      userName: _userName,
                      submitAttempt: _submitAttempt,
                      onChanged: (v) {
                        _updateFormData('email', v);
                        _updateStepValidation(
                          5,
                          RegExp(r'.+@.+\..+').hasMatch(v),
                        );
                      },
                    ),
                  ),

                  _wrapInScroll(
                    RidingExperienceStepWidget(
                      experience: _formData['ridingExperience'],
                      userName: _userName,
                      onExperienceChanged: (v) {
                        _updateFormData('ridingExperience', v);
                        _updateStepValidation(6, true);
                      },
                    ),
                  ),

                  _wrapInScroll(
                    TrackExperienceStepWidget(
                      hasTrackExperience: _formData['hasTrackExperience'],
                      userName: _userName,
                      onChanged: (v) =>
                          _updateFormData('hasTrackExperience', v),
                    ),
                  ),

                  _wrapInScroll(
                    BikeCountStepWidget(
                      bikeCount: _formData['bikeCount'],
                      userName: _userName,
                      onBikeCountChanged: (v) {
                        _updateFormData('bikeCount', v);
                        _updateStepValidation(8, v >= 0);
                      },
                    ),
                  ),

                  _wrapInScroll(
                    DiySkillsStepWidget(
                      userName: _userName,
                      selectedSkills:
                          (_formData['diySkills'] as List).cast<String>(),
                      onChanged: (v) => _updateFormData('diySkills', v),
                    ),
                  ),

                  _wrapInScroll(
                    PictureStepWidget(
                      initialBytes: _formData['pictureBytes'],
                      userName: _userName,
                      onImageChanged: (b) => _updateFormData('pictureBytes', b),
                    ),
                  ),

                  _wrapInScroll(
                    PasswordStepWidget(
                      initialPassword: _formData['password'],
                      userName: _userName,
                      submitAttempt: _submitAttempt,
                      onPasswordChanged: (v) {
                        _updateFormData('password', v);
                        final ok = v.trim().length >= 8 &&
                            RegExp(r'[A-Za-z]').hasMatch(v) &&
                            RegExp(r'\d').hasMatch(v);
                        _updateStepValidation(11, ok);
                      },
                    ),
                  ),

                  // Final step: the actual Bikergram license
                  _wrapInScroll(
                    BikergramLicenseStepWidget(
                      formData: _formData,
                      userName: _userName,
                      onEdit: _previousStep,
                      onFinish: () async {
                        await _completeRegistration();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (showNavButton)
              Padding(
                padding: EdgeInsets.all(4.w),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentStep > 0 ? _previousStep : null,
                        child: const Text('ZurÃ¼ck'),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        width: double.infinity,
                        height: 6.h,
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          child: const Text('Weiter'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}