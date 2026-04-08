import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../services/push_notification_service.dart';

import '../../core/community.dart';
import '../../domain/xp_calculator.dart';
import '../../domain/models/user.dart' as app;
import '../core/providers.dart';
import '../map/live_location_provider.dart';
import 'auth_state.dart';

/// Manages the auth lifecycle using Supabase Auth.
class AuthNotifier extends Notifier<AuthState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  AuthState build() {
    // Listen to Supabase auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('[Auth] Supabase event: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (!_isRegistering) {
            _loadProfile();
          } else {
            debugPrint('[Auth] Skipping _loadProfile during registration');
          }
          break;
        case AuthChangeEvent.signedOut:
          state = const Unauthenticated();
          break;
        default:
          break;
      }
    });

    // Check if already logged in on startup
    Future.microtask(() => checkAuth());

    return const AuthInitial();
  }

  /// Called on app start — checks if we have a valid Supabase session.
  Future<void> checkAuth() async {
    state = const AuthLoading();
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        state = const Unauthenticated();
        return;
      }

      // Session exists — load profile
      await _loadProfile();
    } catch (e) {
      debugPrint('[Auth] checkAuth failed: $e');
      state = const Unauthenticated();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Auth state change listener will call _loadProfile()
    } on AuthException catch (e) {
      state = AuthError(_friendlyAuthError(e));
    } catch (e) {
      state = AuthError(_friendlyError(e));
    }
  }

  /// Flag to prevent the auth listener from calling _loadProfile() during
  /// registration — we do it manually after the profile update.
  bool _isRegistering = false;

  Future<void> register({
    required String email,
    required String password,
    String? username,
    int? birthYear,
    String? postalCode,
    int? motoStartAge,
    int? carStartAge,
    bool? hasTrackExperience,
    bool? interestedInDating,
    double? homeLat,
    double? homeLng,
  }) async {
    state = const AuthLoading();
    _isRegistering = true;
    try {
      // Persist selected community
      final community = ref.read(communityProvider);

      // Pass ALL registration data as user_metadata so the DB trigger
      // can populate the profile even before email confirmation.
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          if (username != null) 'username': username,
          if (username != null) 'display_name': username,
          if (birthYear != null) 'birth_year': birthYear,
          if (postalCode != null) 'postal_code': postalCode,
          if (motoStartAge != null) 'moto_start_age': motoStartAge,
          if (carStartAge != null) 'car_start_age': carStartAge,
          if (hasTrackExperience != null)
            'has_track_experience': hasTrackExperience,
          if (interestedInDating != null)
            'interested_in_dating': interestedInDating,
          if (community != null) 'community': community.name,
          if (homeLat != null) 'home_lat': homeLat,
          if (homeLng != null) 'home_lng': homeLng,
        },
      );

      // Check if email confirmation is required (session is null)
      if (response.session == null && response.user != null) {
        debugPrint('[Auth] SignUp OK but no session — email confirmation required');
        _isRegistering = false;
        state = const AuthError(
          'Fast geschafft! Bitte bestätige deine E-Mail und melde dich dann an.',
        );
        return;
      }

      // After signup (with session), also update profile via API as fallback.
      // The DB trigger already reads user_metadata, but this ensures any
      // columns the trigger doesn't know about are set too.
      final userId = response.user?.id;
      if (userId != null) {
        final updates = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (birthYear != null) updates['birth_year'] = birthYear;
        if (postalCode != null) updates['postal_code'] = postalCode;
        if (motoStartAge != null) updates['moto_start_age'] = motoStartAge;
        if (carStartAge != null) updates['car_start_age'] = carStartAge;
        if (hasTrackExperience != null) {
          updates['has_track_experience'] = hasTrackExperience;
        }
        if (interestedInDating != null) {
          updates['interested_in_dating'] = interestedInDating;
        }
        if (community != null) {
          updates['community'] = community.name;
        }

        if (updates.length > 1) {
          // Wait for the DB trigger to create the profile row
          await Future.delayed(const Duration(milliseconds: 800));

          try {
            await _supabase
                .from('profiles')
                .update(updates)
                .eq('id', userId);
            debugPrint('[Auth] Profile updated with ${updates.keys.join(', ')}');
          } catch (e) {
            debugPrint('[Auth] Profile update failed: $e — trying upsert');
            try {
              updates['id'] = userId;
              await _supabase.from('profiles').upsert(updates);
              debugPrint('[Auth] Profile upserted successfully');
            } catch (e2) {
              debugPrint('[Auth] Profile upsert also failed: $e2');
            }
          }
        }

        // home_lat / home_lng separat — Spalten existieren evtl. noch nicht
        if (homeLat != null && homeLng != null) {
          try {
            await _supabase.from('profiles').update({
              'home_lat': homeLat,
              'home_lng': homeLng,
            }).eq('id', userId);
          } catch (e) {
            debugPrint('[Auth] home_lat/home_lng update failed (migration pending?): $e');
          }
        }
      }

      // NOW load profile with the updated data — bypasses the race condition
      _isRegistering = false;
      await _loadProfile();
    } on AuthException catch (e) {
      _isRegistering = false;
      state = AuthError(_friendlyAuthError(e));
    } catch (e) {
      _isRegistering = false;
      state = AuthError(_friendlyError(e));
    }
  }

  Future<void> logout() async {
    // Go offline immediately — sends goodbye payload so other users see us
    // disappear right away, and clears the top badge.
    try {
      await ref.read(liveLocationServiceProvider).goOffline();
    } catch (_) {}
    isLiveNotifier.value = false;
    onlineUsersNotifier.value = {};

    // Remove FCM token so device stops receiving pushes for this user
    try {
      await PushNotificationService.instance.removeToken();
    } catch (_) {}
    try {
      // Also sign out from Google so account picker shows next time
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[Auth] logout error: $e');
    }
    state = const Unauthenticated();
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      const webClientId = '611571947292-8ma9r2hcopn38g9un4acgei56gjmtgtc.apps.googleusercontent.com';
      debugPrint('[Auth] Google sign-in starting with clientId: $webClientId');
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      // Always sign out first so the account picker is shown
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      debugPrint('[Auth] Google user: $googleUser');
      if (googleUser == null) {
        debugPrint('[Auth] Google sign-in cancelled by user');
        state = const Unauthenticated();
        return;
      }

      debugPrint('[Auth] Google user email: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      debugPrint('[Auth] idToken: ${idToken != null ? "${idToken.substring(0, 20)}..." : "NULL"}');
      debugPrint('[Auth] accessToken: ${accessToken != null ? "${accessToken.substring(0, 20)}..." : "NULL"}');

      if (idToken == null) {
        debugPrint('[Auth] ERROR: idToken is null!');
        state = const AuthError('Google-Anmeldung fehlgeschlagen');
        return;
      }

      debugPrint('[Auth] Calling Supabase signInWithIdToken...');
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      debugPrint('[Auth] Supabase signInWithIdToken SUCCESS');
      // Auth state change listener will call _loadProfile()
    } on AuthException catch (e) {
      debugPrint('[Auth] AuthException: ${e.message}');
      state = AuthError(_friendlyAuthError(e));
    } catch (e) {
      debugPrint('[Auth] Google sign-in error: $e');
      // Don't show error if user cancelled
      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') ||
          msg.contains('cancelled') ||
          msg.contains('sign_in_canceled')) {
        state = const Unauthenticated();
        return;
      }
      state = AuthError(_friendlyError(e));
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthLoading();
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        state = const AuthError('Apple-Anmeldung fehlgeschlagen');
        return;
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Auth state change listener will call _loadProfile()
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const Unauthenticated();
        return;
      }
      state = AuthError(_friendlyError(e));
    } on AuthException catch (e) {
      state = AuthError(_friendlyAuthError(e));
    } catch (e) {
      state = AuthError(_friendlyError(e));
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Load the user profile from Supabase profiles table.
  Future<void> _loadProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        state = const Unauthenticated();
        return;
      }

      // Try to fetch profile from profiles table
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      final user = app.User(
        id: authUser.id,
        email: authUser.email ?? '',
        username: profileData?['username'] ??
            authUser.userMetadata?['username'] ??
            authUser.email?.split('@').first ??
            '',
        displayName: profileData?['display_name'] ??
            authUser.userMetadata?['display_name'],
        bikername: profileData?['bikername'],
        avatarUrl: profileData?['avatar_url'],
        avatarUrlCargram: profileData?['avatar_url_cargram'],
        bio: profileData?['bio'],
        postalCode: profileData?['postal_code'],
        country: profileData?['country'],
        community: profileData?['community'],
        birthYear: profileData?['birth_year'] as int?,
        motoStartAge: profileData?['moto_start_age'] as int?,
        carStartAge: profileData?['car_start_age'] as int?,
        hasTrackExperience: profileData?['has_track_experience'] ?? false,
        homeLat: profileData?.containsKey('home_lat') == true
            ? (profileData!['home_lat'] as num?)?.toDouble()
            : null,
        homeLng: profileData?.containsKey('home_lng') == true
            ? (profileData!['home_lng'] as num?)?.toDouble()
            : null,
        xpTotal: profileData?['xp_total'] ?? 0,
        level: profileData?['level'] ?? 1,
        isPremium: profileData?['is_premium'] ?? false,
        isBusiness: profileData?['is_business'] ?? false,
      );

      state = Authenticated(user);
      debugPrint('[Auth] Authenticated as: ${user.username} (${user.id}), avatar: ${user.avatarUrl}');

      // ── Daily Login XP + Streak ──
      _checkDailyLogin(authUser.id, profileData);

      // Restore saved community selection
      if (user.community != null && ref.read(communityProvider) == null) {
        final saved = Community.values.where((c) => c.name == user.community);
        if (saved.isNotEmpty) {
          ref.read(communityProvider.notifier).select(saved.first);
        }
      }
    } catch (e) {
      debugPrint('[Auth] _loadProfile error: $e');
      // Even if profile fetch fails, user is still authenticated
      final authUser = _supabase.auth.currentUser;
      if (authUser != null) {
        state = Authenticated(app.User(
          id: authUser.id,
          email: authUser.email ?? '',
          username: authUser.email?.split('@').first ?? '',
        ));
      } else {
        state = const Unauthenticated();
      }
    }
  }

  /// Daily Login XP + Streak. Called once per _loadProfile().
  void _checkDailyLogin(String userId, Map<String, dynamic>? profileData) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastLoginStr = profileData?['last_login_date'] as String?;
      final oldStreak = profileData?['login_streak'] as int? ?? 0;

      // Already logged in today → skip
      if (lastLoginStr == todayStr) return;

      int newStreak;
      if (lastLoginStr != null) {
        final lastDate = DateTime.tryParse(lastLoginStr);
        final yesterday = today.subtract(const Duration(days: 1));
        final isConsecutive = lastDate != null &&
            lastDate.year == yesterday.year &&
            lastDate.month == yesterday.month &&
            lastDate.day == yesterday.day;
        newStreak = isConsecutive ? oldStreak + 1 : 1;
      } else {
        newStreak = 1;
      }

      // Update profile
      await _supabase.from('profiles').update({
        'last_login_date': todayStr,
        'login_streak': newStreak,
      }).eq('id', userId);

      // +3 XP for daily login
      XpCalculator.awardXp(userId, XpCalculator.xpDailyLogin, 'daily_login');

      // Streak bonuses
      if (newStreak == 7) {
        XpCalculator.awardXp(userId, XpCalculator.xpStreak7, 'streak_7');
        debugPrint('[XP] 🔥 7-Tage-Streak! +${XpCalculator.xpStreak7} Bonus');
      }
      if (newStreak == 30) {
        XpCalculator.awardXp(userId, XpCalculator.xpStreak30, 'streak_30');
        debugPrint('[XP] 🔥🔥 30-Tage-Streak! +${XpCalculator.xpStreak30} Bonus');
      }

      debugPrint('[XP] Daily Login: streak=$newStreak, +${XpCalculator.xpDailyLogin} XP');
    } catch (e) {
      debugPrint('[XP] Daily login check failed: $e');
    }
  }

  /// Supabase-specific error messages in German.
  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'E-Mail oder Passwort falsch';
    }
    if (msg.contains('email already registered') ||
        msg.contains('user already registered')) {
      return 'Diese E-Mail ist bereits registriert';
    }
    if (msg.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail';
    }
    if (msg.contains('signup is not allowed') ||
        msg.contains('signups not allowed')) {
      return 'Registrierung ist derzeit deaktiviert';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Zu viele Versuche — bitte warte einen Moment';
    }
    if (msg.contains('password') && msg.contains('short')) {
      return 'Passwort muss mindestens 6 Zeichen lang sein';
    }

    return e.message;
  }

  String _friendlyError(Object e) {
    final str = e.toString().toLowerCase();

    if (str.contains('socketexception') || str.contains('connection refused')) {
      return 'Keine Internetverbindung';
    }
    if (str.contains('timeout')) {
      return 'Server antwortet nicht — bitte versuche es später';
    }

    return 'Etwas ist schiefgelaufen. Bitte versuche es erneut.';
  }
}

// Provider
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
