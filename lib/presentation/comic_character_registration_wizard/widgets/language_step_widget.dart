import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/api_client.dart';
import '../../../core/auth/bikergram_auth_api.dart';
import '../../../core/auth/token_pair.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/auth/remember_me_store.dart';
import '../../auth/widgets/remember_me_row.dart';
import '../../../routes/app_routes.dart';

class LanguageStepWidget extends StatefulWidget {
  final String? selectedLanguage;
  final ValueChanged<String?> onLanguageSelected;

  const LanguageStepWidget({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  State<LanguageStepWidget> createState() => _LanguageStepWidgetState();
}

class _LanguageStepWidgetState extends State<LanguageStepWidget> {
  bool _autoLoginBusy = false;
  bool _autoLoginTried = false;

  static const List<_LangOption> _options = [
    _LangOption(code: 'de', label: 'Deutsch', flag: '🇩🇪'),
    _LangOption(code: 'it', label: 'Italiano', flag: '🇮🇹'),
    _LangOption(code: 'en', label: 'English', flag: '🇬🇧'),
    _LangOption(code: 'de_CH', label: 'Schweiz', flag: '🇨🇭'),
    _LangOption(code: 'de_AT', label: 'Österreich', flag: '🇦🇹'),
    _LangOption(code: 'pl', label: 'Polski', flag: '🇵🇱'),
    _LangOption(code: 'ru', label: 'Русский', flag: '🇷🇺'),
    _LangOption(code: 'zh', label: '中文', flag: '🇨🇳'),
    _LangOption(code: 'ar', label: 'العربية', flag: '🇸🇦'),
  ];

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLoginIfRemembered());
// Kill leftover focus from previous steps so the keyboard never appears here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    FocusManager.instance.primaryFocus?.unfocus();

    // Tiles: only fixed width; height adapts => no overflow inside tiles.
    final double tileW = 22.w;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/carbon.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wähle deine Sprache',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Tippe auf eine Flagge. Du kannst später in den Einstellungen wechseln.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                SizedBox(height: 2.h),

                // Center vertically when there's free space,
                // still scroll if content becomes taller than the available height.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Wrap(
                              spacing: 3.w,
                              runSpacing: 1.6.h,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final opt in _options) _flagTile(theme, opt, tileW),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Existing account shortcut (so you don't have to click through the whole wizard).
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _openLoginSheet,
                    icon: const Icon(Icons.login),
                    label: const Text('Ich habe schon ein Konto – Anmelden'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.35)),
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      backgroundColor: Colors.black.withOpacity(0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _tryAutoLoginIfRemembered() async {
    if (_autoLoginTried) return;
    _autoLoginTried = true;

    try {
      final creds = await RememberMeStore.instance.load();
      if (creds == null) return;

      if (!mounted) return;
      setState(() => _autoLoginBusy = true);

      final api = BikergramAuthApi();
      final res = await api.login(email: creds.email, password: creds.password);

      final at = res.tokens.accessToken.trim();
      final rt = res.tokens.refreshToken.trim();
      if (at.isEmpty || rt.isEmpty) return;

      await TokenStore().write(
        TokenPair(accessToken: at, refreshToken: rt),
        reason: 'auto_login',
      );
      await ApiClient.instance.setToken(at);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.mainSocialFeed,
        (_) => false,
      );
    } catch (_) {
      // ignore (user can still login manually)
    } finally {
      if (!mounted) return;
      setState(() => _autoLoginBusy = false);
    }
  }



  Future<void> _openLoginSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ExistingLoginSheet(),
    );

    if (!mounted) return;
    if (ok == true) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.mainSocialFeed,
        (_) => false,
      );
    }
  }

  Widget _flagTile(ThemeData theme, _LangOption opt, double w) {
    final selected = widget.selectedLanguage == opt.code;

    return SizedBox(
      width: w,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          widget.onLanguageSelected(opt.code);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.4.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(selected ? 0.40 : 0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.white.withOpacity(0.22),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                opt.flag,
                style: TextStyle(fontSize: 26.sp),
              ),
              SizedBox(height: 0.6.h),
              Text(
                opt.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingLoginSheet extends StatefulWidget {
  const _ExistingLoginSheet();

  @override
  State<_ExistingLoginSheet> createState() => _ExistingLoginSheetState();
}

class _ExistingLoginSheetState extends State<_ExistingLoginSheet> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _rememberEnabled = true;
  bool _busy = false;
  String? _error;



  @override
  void initState() {
    super.initState();
    // Load remembered credentials (if enabled) and prefill fields.
    () async {
      final creds = await RememberMeStore.instance.load();
      if (!mounted) return;
      if (creds != null) {
        setState(() => _rememberEnabled = true);
        _emailCtrl.text = creds.email;
        _pwdCtrl.text = creds.password;
      } else {
        final enabled = await RememberMeStore.instance.isEnabled();
        if (!mounted) return;
        setState(() => _rememberEnabled = enabled);
      }
    }();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    setState(() {
      _error = null;
    });

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Bitte eine gültige Email eingeben.');
      return;
    }
    if (pwd.trim().isEmpty) {
      setState(() => _error = 'Bitte Passwort eingeben.');
      return;
    }

    setState(() => _busy = true);

    try {
      final api = BikergramAuthApi();
      final res = await api.login(email: email, password: pwd);

      final at = res.tokens.accessToken.trim();
      final rt = res.tokens.refreshToken.trim();
      if (at.isEmpty || rt.isEmpty) {
        throw Exception('Login ok, aber Tokens fehlen.');
      }

      await TokenStore().write(
        TokenPair(accessToken: at, refreshToken: rt),
        reason: 'login_sheet',
      );
      await ApiClient.instance.setToken(at);


      // Remember credentials (optional)
      await RememberMeStore.instance.save(
        enabled: _rememberEnabled,
        email: email,
        password: pwd,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Anmelden',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                'Melde dich mit deinem bestehenden Konto an.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              SizedBox(height: 2.h),

              TextField(
                controller: _emailCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              SizedBox(height: 1.2.h),
              TextField(
                controller: _pwdCtrl,
                enabled: !_busy,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _login(),
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                style: const TextStyle(color: Colors.white),
              ),

              RememberMeRow(
                value: _rememberEnabled,
                onChanged: _busy
                    ? (_) {}
                    : (v) async {
                        setState(() => _rememberEnabled = v);
                        if (!v) {
                          await RememberMeStore.instance.clear();
                        }
                      },
              ),


              if (_error != null) ...[
                SizedBox(height: 1.2.h),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.redAccent.withOpacity(0.95)),
                ),
              ],

              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.4.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                        )
                      : const Text('Login'),
                ),
              ),
              SizedBox(height: 1.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption {
  final String code;
  final String label;
  final String flag;

  const _LangOption({required this.code, required this.label, required this.flag});
}
