import 'package:flutter/material.dart';

/// Shared mini keyboard used inside wizard steps.
/// Goal: prevent the OS keyboard from opening (TextField should be readOnly).
///
/// Two presets:
/// - MiniNumericKeyboard (PLZ, number fields)
/// - MiniEmailKeyboard (email typing: includes @ and . plus common symbols)
///
/// Usage:
/// - Make TextField readOnly: true, showCursor: true, onTap: unfocus
/// - Keep a TextEditingController and call MiniKeyboardController helpers below.
class MiniKeyboardController {
  final TextEditingController controller;
  final VoidCallback? onChanged;

  MiniKeyboardController(this.controller, {this.onChanged});

  void insert(String text) {
    final value = controller.value;
    final selection = value.selection;

    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;

    final newText = value.text.replaceRange(start, end, text);
    final newSelection = TextSelection.collapsed(offset: start + text.length);

    controller.value = value.copyWith(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
    onChanged?.call();
  }

  void dispose() {}

  void backspace() {
    final value = controller.value;
    final selection = value.selection;
    final text = value.text;

    if (text.isEmpty) return;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    // If selection exists, delete selection.
    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      onChanged?.call();
      return;
    }

    if (start == 0) return;

    final newText = text.replaceRange(start - 1, start, '');
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start - 1),
      composing: TextRange.empty,
    );
    onChanged?.call();
  }

  void clear() {
    controller.clear();
    onChanged?.call();
  }
}

class MiniNumericKeyboard extends StatelessWidget {
  final MiniKeyboardController kb;
  final int maxLength; // optional limit
  final bool showOk;
  final VoidCallback? onOk;

  const MiniNumericKeyboard({
    super.key,
    required this.kb,
    this.maxLength = 10,
    this.showOk = false,
    this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    bool canInsert(String s) {
      final t = kb.controller.text;
      return t.length + s.length <= maxLength;
    }

    return _KeyboardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(
            keys: const ['1', '2', '3'],
            onKey: (k) => canInsert(k) ? kb.insert(k) : null,
          ),
          const SizedBox(height: 8),
          _KeyRow(
            keys: const ['4', '5', '6'],
            onKey: (k) => canInsert(k) ? kb.insert(k) : null,
          ),
          const SizedBox(height: 8),
          _KeyRow(
            keys: const ['7', '8', '9'],
            onKey: (k) => canInsert(k) ? kb.insert(k) : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'CLR',
                  icon: Icons.restart_alt_rounded,
                  isAction: true,
                  onTap: kb.clear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _KeyButton(
                  label: '0',
                  onTap: canInsert('0') ? () => kb.insert('0') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  icon: Icons.backspace_rounded,
                  isAction: true,
                  onTap: kb.backspace,
                ),
              ),
              if (showOk) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: 'OK',
                    icon: Icons.check_circle_rounded,
                    isAction: true,
                    onTap: onOk,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bikergram ‑ Tastatur',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniEmailKeyboard extends StatefulWidget {
  final MiniKeyboardController kb;
  final bool showOk;
  final VoidCallback? onOk;

  const MiniEmailKeyboard({
    super.key,
    required this.kb,
    this.showOk = false,
    this.onOk,
  });

  @override
  State<MiniEmailKeyboard> createState() => _MiniEmailKeyboardState();
}

class _MiniEmailKeyboardState extends State<MiniEmailKeyboard> {
  bool _shift = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String resolve(String k) {
      if (k.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(k)) {
        return _shift ? k.toUpperCase() : k.toLowerCase();
      }
      return k;
    }

    return _KeyboardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(
            keys: const ['1','2','3','4','5','6','7','8','9','0'],
            onKey: (k) => widget.kb.insert(k),
          ),
          const SizedBox(height: 8),
          _KeyRow(
            keys: const ['q','w','e','r','t','z','u','i','o','p'],
            onKey: (k) => widget.kb.insert(resolve(k)),
          ),
          const SizedBox(height: 8),
          _KeyRow(
            keys: const ['a','s','d','f','g','h','j','k','l'],
            onKey: (k) => widget.kb.insert(resolve(k)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: _shift ? 'SHIFT' : 'shift',
                  icon: Icons.arrow_upward_rounded,
                  isAction: true,
                  active: _shift,
                  onTap: () => setState(() => _shift = !_shift),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 8,
                child: _KeyRow(
                  keys: const ['y','x','c','v','b','n','m','_','-'],
                  onKey: (k) => widget.kb.insert(resolve(k)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: '@',
                  onTap: () => widget.kb.insert('@'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: '.',
                  onTap: () => widget.kb.insert('.'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _KeyButton(
                  label: '.de',
                  isAction: true,
                  onTap: () => widget.kb.insert('.de'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _KeyButton(
                  label: '.com',
                  isAction: true,
                  onTap: () => widget.kb.insert('.com'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'CLR',
                  icon: Icons.restart_alt_rounded,
                  isAction: true,
                  onTap: widget.kb.clear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _KeyButton(
                  label: 'SPACE',
                  icon: Icons.space_bar_rounded,
                  isAction: true,
                  onTap: () => widget.kb.insert(' '),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  icon: Icons.backspace_rounded,
                  isAction: true,
                  onTap: widget.kb.backspace,
                ),
              ),
              if (widget.showOk) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: 'OK',
                    icon: Icons.check_circle_rounded,
                    isAction: true,
                    onTap: widget.onOk,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mini‑Tastatur aktiv (Systemtastatur bleibt zu)',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}



class MiniPasswordKeyboard extends StatefulWidget {
  final MiniKeyboardController kb;
  final bool showOk;
  final VoidCallback? onOk;

  const MiniPasswordKeyboard({
    super.key,
    required this.kb,
    this.showOk = false,
    this.onOk,
  });

  @override
  State<MiniPasswordKeyboard> createState() => _MiniPasswordKeyboardState();
}

class _MiniPasswordKeyboardState extends State<MiniPasswordKeyboard> {
  bool _shift = false;
  bool _symbols = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String resolve(String k) {
      if (k.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(k)) {
        return _shift ? k.toUpperCase() : k.toLowerCase();
      }
      return k;
    }

    final row1 = const ['1','2','3','4','5','6','7','8','9','0'];

    // IMPORTANT: Dollar sign must be escaped as '\$' in source => '\$' string is WRONG.
    // Correct is '\$' in Dart literal? Actually must be '\$'? No: '\$' yields literal '$'.
    final row2 = _symbols
        ? const ['!','@','#','\$','%','^','&','*','(',')']
        : const ['q','w','e','r','t','z','u','i','o','p'];

    final row3 = _symbols
        ? const ['-','_','.',',',':',';','/','\\']
        : const ['a','s','d','f','g','h','j','k','l'];

    final row4 = _symbols
        ? const ['[',']','{','}','<','>','=','+']
        : const ['y','x','c','v','b','n','m'];

    return _KeyboardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(keys: row1, onKey: (k) => widget.kb.insert(k)),
          const SizedBox(height: 8),
          _KeyRow(keys: row2, onKey: (k) => widget.kb.insert(resolve(k))),
          const SizedBox(height: 8),
          _KeyRow(keys: row3, onKey: (k) => widget.kb.insert(resolve(k))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: _shift ? 'SHIFT' : 'shift',
                  icon: Icons.arrow_upward_rounded,
                  isAction: true,
                  active: _shift,
                  onTap: () => setState(() => _shift = !_shift),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _KeyRow(
                  keys: row4,
                  onKey: (k) => widget.kb.insert(resolve(k)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: _symbols ? 'ABC' : '#+=',
                  icon: Icons.tag,
                  isAction: true,
                  active: _symbols,
                  onTap: () => setState(() => _symbols = !_symbols),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'CLR',
                  icon: Icons.restart_alt_rounded,
                  isAction: true,
                  onTap: widget.kb.clear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: _KeyButton(
                  label: 'SPACE',
                  icon: Icons.space_bar_rounded,
                  isAction: true,
                  onTap: () => widget.kb.insert(' '),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  icon: Icons.backspace_rounded,
                  isAction: true,
                  onTap: widget.kb.backspace,
                ),
              ),
              if (widget.showOk) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _KeyButton(
                    label: 'OK',
                    icon: Icons.check_circle_rounded,
                    isAction: true,
                    onTap: widget.onOk,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mini‑Tastatur aktiv (Systemtastatur bleibt zu)',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardShell extends StatelessWidget {
  final Widget child;
  const _KeyboardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.22),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> keys;
  final ValueChanged<String> onKey;

  const _KeyRow({
    required this.keys,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final k in keys) ...[
          Expanded(child: _KeyButton(label: k, onTap: () => onKey(k))),
          if (k != keys.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isAction;
  final bool active;
  final VoidCallback? onTap;

  const _KeyButton({
    required this.label,
    this.icon,
    this.isAction = false,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = active
        ? theme.colorScheme.primary.withOpacity(0.92)
        : isAction
            ? theme.colorScheme.surfaceVariant.withOpacity(0.95)
            : theme.colorScheme.surface.withOpacity(0.98);

    final fg = active
        ? Colors.white
        : isAction
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.16)),
          ),
          child: Center(
            child: icon == null
                ? Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: fg,
                      letterSpacing: 0.2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: fg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
