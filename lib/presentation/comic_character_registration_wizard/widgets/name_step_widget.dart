import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/netcup/bikername_service.dart';
import '../../../../core/api_config.dart';
import 'comic_speech_bubble.dart';
import 'step_bubbles.dart';

class NameStepWidget extends StatefulWidget {
  final String userName;
  final int submitAttempt;
  final String? netcupBaseUrl;

  final String? name;
  final ValueChanged<String> onChanged;

  /// Globaler Wizard-Weiter-Button bleibt (dieses Step hat keinen eigenen).
  final VoidCallback onSubmit;

  const NameStepWidget({
    super.key,
    this.userName = '',
    this.submitAttempt = 0,
    this.netcupBaseUrl,
    required this.name,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  State<NameStepWidget> createState() => _NameStepWidgetState();
}

class _NameStepWidgetState extends State<NameStepWidget> {
  static final String _defaultBaseUrl = ApiConfig.apiBaseUrl;

  static String _sanitizeBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return ApiConfig.apiBaseUrl;
    // Fix common typos like https// or http// (missing colon)
    s = s.replaceFirst(RegExp(r'^https//', caseSensitive: false), 'https://');
    s = s.replaceFirst(RegExp(r'^http//', caseSensitive: false), 'http://');
    // Fix 'wwww.' typo
    s = s.replaceAll('wwww.', 'www.');
    // Add scheme if missing
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    // Remove trailing slash
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    try {
      final u = Uri.parse(s);
      final host = u.host.toLowerCase();
      // If someone points to the website host, map to the API host
      if (host == 'bikergram.de' || host == 'bikergram.com') {
        return u.replace(host: 'api.$host').toString();
      }
      if (host.startsWith('www.')) {
        return u.replace(host: host.replaceFirst('www.', 'api.')).toString();
      }
    } catch (_) {}
    return s;
  }


  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/3bikerin_name.png';

  late final TextEditingController _ctrl;
  Timer? _debounce;
  late final BikernameService _svc;

  bool _checking = false;
  int _rollToken = 0;
  bool _showError = false;

  String _sanitizeName(String raw) {
    // Allow letters (incl. umlauts), digits, space and _ - #
    var s = raw.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß _\-#]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    if (s.length <= 18) return s;
    return s.substring(0, 18);
  }

  bool _isValidName(String v) =>
      RegExp(r'^[A-Za-z0-9ÄÖÜäöüß _\-#]{3,18}$').hasMatch(v.trim());
  String _bikerCommentFor(String seed) {
    const comments = <String>[
      'Ready für die nächste Tour! 🏍️',
      'Klingt nach Asphalt & Freiheit. 😎',
      'Der Helm sitzt – der Name auch! 🪖',
      'Mit dem Namen wirst du gesehen. 👀',
      'Vorsicht: könnte süchtig nach Kurven machen. 🌀',
      'Besser als ein Burnout: dein Style! 🔥',
      'Passt wie Kette aufs Ritzel. ⚙️',
    ];
    final s = seed.trim().isEmpty ? 'biker' : seed.trim().toLowerCase();
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return comments[h % comments.length];
  }


  bool? _available;
  String? _statusText;

  // Mini keyboard is the default (OS keyboard should never pop up on this step).
  bool _useMiniKeyboard = true;

  // One-shot shift like on phones: after inserting ONE capital letter, it flips back.
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _sanitizeName(widget.name ?? ''));
    final base = _sanitizeBaseUrl(widget.netcupBaseUrl ?? _defaultBaseUrl);
    _svc = BikernameService(baseUrl: base);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCheck(_ctrl.text, immediate: true);
    });
  }

  @override
  void didUpdateWidget(covariant NameStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submitAttempt != oldWidget.submitAttempt) {
      final ok = _isValidName(_ctrl.text);
      setState(() => _showError = !ok);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _setStatus({required bool checking, bool? available, String? text}) {
    if (!mounted) return;
    setState(() {
      _checking = checking;
      _available = available;
      _statusText = text;
    });
  }

  void _maybeCheck(String raw, {bool immediate = false}) {
    final name = _sanitizeName(raw).trim();
    if (!_isValidName(name)) {
      _setStatus(checking: false, available: null, text: null);
      return;
    }

    _debounce?.cancel();
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 450);

    _debounce = Timer(delay, () async {
      _setStatus(checking: true, available: null, text: 'prüfe…');
      try {
        final r = await _svc.check(name);
        final ok = r.available;

        _setStatus(
          checking: false,
          available: ok,
          text: ok
              ? 'Name frei ✅ Gib dein Name einfach ein oder würfel nochmal!'
              : 'Name leider vergeben ❌',
        );
      } catch (e) {
        final base = _sanitizeBaseUrl(widget.netcupBaseUrl ?? _defaultBaseUrl);
        _setStatus(
          checking: false,
          available: null,
          text: 'Server/Netzwerk Fehler beim Namen-Check\n$e',
        );
      }
    });
  }

  void _toggleMiniKeyboard() {
    setState(() {
      _useMiniKeyboard = !_useMiniKeyboard;
      // When switching to mini keyboard, hide the OS keyboard.
      if (_useMiniKeyboard) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _insertText(String text) {
    final value = _ctrl.value;
    final selection = value.selection;

    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;

    final rawText = value.text.replaceRange(start, end, text);

    final newText = _sanitizeName(rawText);
    final newSelection = TextSelection.collapsed(offset: newText.length);

    _ctrl.value = value.copyWith(text: newText, selection: newSelection, composing: TextRange.empty);
    widget.onChanged(_ctrl.text.trim());
    _maybeCheck(_ctrl.text);
  }

  void _backspace() {
    final value = _ctrl.value;
    final selection = value.selection;
    final text = value.text;

    if (text.isEmpty) return;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    // If user has a selection, delete it.
    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      _ctrl.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      widget.onChanged(_ctrl.text.trim());
      _maybeCheck(_ctrl.text);
      return;
    }

    // Otherwise delete one char before cursor.
    if (start == 0) return;
    final newText = text.replaceRange(start - 1, start, '');
    _ctrl.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start - 1),
      composing: TextRange.empty,
    );
    widget.onChanged(_ctrl.text.trim());
    _maybeCheck(_ctrl.text);
  }

  void _space() => _insertText(' ');
  void _clear() {
    _ctrl.clear();
    widget.onChanged('');
    _maybeCheck('', immediate: true);
  }

  Future<void> _rollName() async {
    final token = ++_rollToken;
    _setStatus(checking: true, available: null, text: 'würfle…');
    try {
      final candidate = await _svc.generateAvailableName(maxAttempts: 60);
      if (!mounted || token != _rollToken) return;

      await _svc.reserve(candidate);
      if (!mounted || token != _rollToken) return;

      _ctrl.text = candidate;
      widget.onChanged(candidate);
      _setStatus(checking: false, available: true, text: 'Name frei ✅ sehr gut tippe auf Weiter.');
    } catch (e) {
      if (!mounted || token != _rollToken) return;
      final base = _sanitizeBaseUrl(widget.netcupBaseUrl ?? _defaultBaseUrl);
      _setStatus(
        checking: false,
        available: null,
        text: 'Würfeln fehlgeschlagen\n$base/bikername_generate.php\n$e',
      );
    }
  }


  bool _isUpperLetter(String k) {
    // includes DE umlauts
    return RegExp(r'^[A-ZÄÖÜ]$').hasMatch(k);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameLen = _ctrl.text.trim().length;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _carbonAsset,
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
                // Bubbles are OVER the hero image (Stack) so they don't push the image down.
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
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;

                      final raw = _ctrl.text;
                      final trimmed = raw.trim();
                      final len = trimmed.length;

                      final display = bikergramDisplayName(trimmed);
                      final nameForText = display.isEmpty ? trimmed : display;

                      final ok = _isValidName(trimmed);

                      final bool showRed =
                          (_showError && trimmed.isEmpty) ||
                          (trimmed.isNotEmpty && len < 3) ||
                          (trimmed.isNotEmpty && !ok) ||
                          (_available == false);

                      String bubbleText;
                      if (_showError && trimmed.isEmpty) {
                        bubbleText = 'Hey! Name leer 😅\nWie sollen wir dich nennen, Biker?';
                      } else if (trimmed.isEmpty) {
                        bubbleText = '${bikergramGreet(widget.userName)} Wie sollen wir dich nennen, Biker?';
                      } else if (len < 3) {
                        bubbleText = 'Mindestens 3 Zeichen, Biker!';
                      } else if (!ok) {
                        bubbleText = 'Erlaubt: Buchstaben, Zahlen, Leerzeichen, _ - #\n(3-18 Zeichen)';
                      } else if (_available == false) {
                        bubbleText = 'Der Name ist schon vergeben ❌\nWürfel nochmal oder ändere ihn.';
                      } else if (_checking) {
                        bubbleText = 'Hey $nameForText! Checke kurz…';
                      } else {
                        bubbleText = 'Hey $nameForText! Wow, sehr schöner Name 😎\n${_bikerCommentFor(nameForText)}';
                      }

                      final bubble = ComicSpeechBubble(
                        text: bubbleText,
                        tailOnRight: true,
                        opacity: showRed ? 0.98 : 0.95,
                        overlayShiftY: 0,
                        bubbleColor: showRed ? const Color(0xFFFFE8E8) : null,
                        borderColor: showRed ? const Color(0xFFE53935) : null,
                      );

                      final leftPad = (w * 0.06).clamp(18.0, 56.0);
                      final topPad = (w * 0.02).clamp(4.0, 18.0);
                      final maxBubbleW = (w * 0.62).clamp(220.0, 520.0);

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(_heroAsset, fit: BoxFit.cover),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.28),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bubble (same position for white/red; adapts to text length)
                          Positioned(
                            left: leftPad,
                            top: topPad,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxBubbleW),
                              child: IntrinsicWidth(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeIn,
                                  child: KeyedSubtree(
                                    key: ValueKey(bubbleText),
                                    child: bubble,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 2.2.h),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              // Always keep the OS keyboard hidden on this step.
                              readOnly: true,
                              showCursor: true,
                              onTap: () => FocusScope.of(context).unfocus(),
                              onChanged: (v) {
                                widget.onChanged(v);
                                _maybeCheck(v);
                              },
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {},
                              decoration: InputDecoration(
                                hintText: 'z.B. ShadowRider_777',
                                filled: true,
                                fillColor: theme.colorScheme.surface.withOpacity(0.96),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          _DiceButton(
                            enabled: true,
                            onTap: _rollName,
                          ),
                        ],
                      ),
                      SizedBox(height: 1.6.h),

                      // Slightly bigger mini keyboard + keys (more comfy on tablet)
                      _MiniKeyboard(
                        shift: _shift,
                        onToggleShift: () => setState(() => _shift = !_shift),
                        onKey: (k) {
                          _insertText(k);

                          // Phone-like: Shift disables automatically after ONE uppercase letter.
                          if (_shift && _isUpperLetter(k)) {
                            setState(() => _shift = false);
                          }
                        },
                        onSpace: _space,
                        onBackspace: _backspace,
                        onClear: _clear,
                      ),

                      SizedBox(height: 1.4.h),
                      if ((_statusText ?? '').isNotEmpty)
                        Text(
                          _statusText!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: (_available == true)
                                ? Colors.greenAccent
                                : (_available == false)
                                    ? Colors.redAccent
                                    : theme.colorScheme.onSurfaceVariant,
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

class _DiceButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _DiceButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.20),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: -0.12,
              child: Icon(
                Icons.casino_rounded,
                size: 34,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
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

class _MiniKeyboard extends StatelessWidget {
  final bool shift;
  final VoidCallback onToggleShift;
  final ValueChanged<String> onKey;
  final VoidCallback onSpace;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _MiniKeyboard({
    required this.shift,
    required this.onToggleShift,
    required this.onKey,
    required this.onSpace,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.22),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(
            keys: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
            shift: shift,
            onKey: onKey,
          ),
          const SizedBox(height: 10),
          _KeyRow(
            keys: const ['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p'],
            shift: shift,
            onKey: onKey,
          ),
          const SizedBox(height: 10),
          _KeyRow(
            keys: const ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ö', 'ä'],
            shift: shift,
            onKey: onKey,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: shift ? 'SHIFT' : 'shift',
                  icon: Icons.arrow_upward_rounded,
                  isAction: true,
                  active: shift,
                  onTap: onToggleShift,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 8,
                child: _KeyRow(
                  keys: const ['y', 'x', 'c', 'v', 'b', 'n', 'm', 'ü', '_', '-', '#'],
                  shift: shift,
                  onKey: onKey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'CLR',
                  icon: Icons.restart_alt_rounded,
                  isAction: true,
                  onTap: onClear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _KeyButton(
                  label: 'SPACE',
                  icon: Icons.space_bar_rounded,
                  isAction: true,
                  onTap: onSpace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  icon: Icons.backspace_rounded,
                  isAction: true,
                  onTap: onBackspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> keys;
  final bool shift;
  final ValueChanged<String> onKey;

  const _KeyRow({
    required this.keys,
    required this.onKey,
    this.shift = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          Expanded(
            child: _KeyButton(
              label: shift ? keys[i].toUpperCase() : keys[i],
              onTap: () => onKey(shift ? keys[i].toUpperCase() : keys[i]),
            ),
          ),
          if (i != keys.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isAction;
  final bool active;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isAction = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = active ? theme.colorScheme.primary.withOpacity(0.18) : theme.colorScheme.surface.withOpacity(0.92);

    final baseSize = theme.textTheme.labelLarge?.fontSize ?? 14.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.14),
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: isAction ? 0.6 : 0.2,
                  fontSize: baseSize + 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
