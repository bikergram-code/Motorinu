import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import 'comic_speech_bubble.dart';

class PictureStepWidget extends StatefulWidget {
  final Uint8List? initialBytes;
  final String userName;
  final ValueChanged<Uint8List?> onImageChanged;

  const PictureStepWidget({
    super.key,
    required this.initialBytes,
    required this.onImageChanged,
    this.userName = '',
  });

  static const String _carbonAsset = 'assets/images/carbon.png';
  static const String _heroAsset = 'assets/images/11bikerin_picture.png';

  @override
  State<PictureStepWidget> createState() => _PictureStepWidgetState();
}

class _PictureStepWidgetState extends State<PictureStepWidget> {
  Uint8List? _bytes;
  bool _busy = false;
  bool _explicitNoImage = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
  }

  Future<void> _pick(ImageSource src) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: src, imageQuality: 85);
      if (file == null) return;
      final b = await file.readAsBytes();
      setState(() {
        _bytes = b;
        _explicitNoImage = false;
      });
      widget.onImageChanged(b);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    setState(() {
      _bytes = null;
      _explicitNoImage = true;
    });
    widget.onImageChanged(null);
  }

  void _setNoImage() {
    _remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            PictureStepWidget._carbonAsset,
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

                const ComicSpeechBubble(
                  text: 'Zeig dich von deiner besten Seite!\nLade ein Profilbild hoch 📸',
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
                    PictureStepWidget._heroAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      alignment: Alignment.center,
                      color: Colors.black.withOpacity(0.2),
                      child: const Text(
                        'Bild fehlt: 11bikerin_picture.png',
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
                        'Profilbild',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 1.4.h),

                      _Preview(bytes: _bytes, busy: _busy),

                      SizedBox(height: 1.6.h),

                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Galerie',
                              icon: Icons.photo_library_outlined,
                              onTap: _busy ? null : () => _pick(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              label: 'Kamera',
                              icon: Icons.photo_camera_outlined,
                              onTap: _busy ? null : () => _pick(ImageSource.camera),
                            ),
                          ),
                        ],
                      ),


                      SizedBox(height: 1.2.h),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _setNoImage,
                        icon: const Icon(Icons.do_not_disturb_alt_outlined),
                        label: const Text('Kein Bild'),
                      ),
                      if (_explicitNoImage && _bytes == null) ...[
                        SizedBox(height: 0.8.h),
                        Text(
                          'Alles klar – du bekommst eine Comic-Puppe als Platzhalter 🙂',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.75),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],

                      if (_bytes != null) ...[
                        SizedBox(height: 1.2.h),
                        _ActionButton(
                          label: 'Entfernen',
                          icon: Icons.delete_outline,
                          danger: true,
                          onTap: _busy ? null : _remove,
                        ),
                      ],

                      SizedBox(height: 1.0.h),

                      Text(
                        'Tipp: Ein klares Gesicht wirkt am besten 😉',
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



class _ComicDollPlaceholder extends StatelessWidget {
  final double size;
  const _ComicDollPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ComicDollPainter(),
      ),
    );
  }
}

class _ComicDollPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outline = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.06).clamp(2.0, 4.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillSkin = Paint()
      ..color = const Color(0xFFF2D6C8)
      ..style = PaintingStyle.fill;

    final fillSuit = Paint()
      ..color = const Color(0xFF3A3F49)
      ..style = PaintingStyle.fill;

    // Head
    final headR = w * 0.22;
    final headC = Offset(w * 0.5, h * 0.30);
    canvas.drawCircle(headC, headR, fillSkin);
    canvas.drawCircle(headC, headR, outline);

    // Eyes
    final eye = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(Offset(w * 0.43, h * 0.28), w * 0.03, eye);
    canvas.drawCircle(Offset(w * 0.57, h * 0.28), w * 0.03, eye);

    // Smile
    final smile = Path()
      ..moveTo(w * 0.44, h * 0.34)
      ..quadraticBezierTo(w * 0.5, h * 0.38, w * 0.56, h * 0.34);
    canvas.drawPath(smile, outline);

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.30, h * 0.46, w * 0.40, h * 0.38),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(body, fillSuit);
    canvas.drawRRect(body, outline);

    // Arms
    final leftArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.52, w * 0.12, h * 0.22),
      Radius.circular(w * 0.08),
    );
    final rightArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.70, h * 0.52, w * 0.12, h * 0.22),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(leftArm, fillSuit);
    canvas.drawRRect(rightArm, fillSuit);
    canvas.drawRRect(leftArm, outline);
    canvas.drawRRect(rightArm, outline);

    // Legs
    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.36, h * 0.82, w * 0.10, h * 0.12),
      Radius.circular(w * 0.05),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.54, h * 0.82, w * 0.10, h * 0.12),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(leftLeg, fillSuit);
    canvas.drawRRect(rightLeg, fillSuit);
    canvas.drawRRect(leftLeg, outline);
    canvas.drawRRect(rightLeg, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Preview extends StatelessWidget {
  final Uint8List? bytes;
  final bool busy;

  const _Preview({required this.bytes, required this.busy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 22.h,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.20),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ComicDollPlaceholder(size: 70),
                    const SizedBox(height: 8),
                    Text(
                      'Noch kein Bild ausgewählt',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            if (busy)
              Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: danger
            ? const Color(0xFFE53935).withOpacity(0.20)
            : Colors.white.withOpacity(0.10),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 1.6.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: danger
              ? const Color(0xFFE53935).withOpacity(0.45)
              : theme.colorScheme.outline.withOpacity(0.18),
          width: 1.6,
        ),
        elevation: 0,
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
