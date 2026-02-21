import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/feed/feed_notifier.dart';
import '../../../theme/app_theme.dart';
import 'topic_picker.dart';

// Max file sizes
const _maxImageSizeMB = 10;
const _maxVideoSizeMB = 50;

// Allowed video extensions
const _allowedVideoTypes = ['mp4', 'mov', 'avi', 'mkv', 'webm'];

/// Initial media source to auto-open on screen launch.
enum PostMediaSource { none, photo, video, camera, textOnly }

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.initialSource = PostMediaSource.none});

  final PostMediaSource initialSource;

  /// Opens the fullscreen post creator.
  /// Uses rootNavigator so it opens ABOVE the MainShell (no Global Top Bar overlap).
  static void show(BuildContext context, {PostMediaSource source = PostMediaSource.none}) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => CreatePostScreen(initialSource: source),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  // Steps: 0 = Media selection, 1 = Text + Post
  int _currentStep = 0;

  // Text
  final _textController = TextEditingController();

  // Single Image (backward compat)
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;

  // Carousel (Multi-Image, ≤10)
  List<Uint8List> _carouselImages = [];
  List<String> _carouselImageNames = [];

  // Video
  Uint8List? _pickedVideoBytes;
  String? _pickedVideoName;
  double? _pickedVideoSizeMB;

  // Topics
  List<int> _selectedTopicIds = [];

  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Skip to text step immediately for textOnly
    if (widget.initialSource == PostMediaSource.textOnly) {
      _currentStep = 1;
    }
    // Auto-open media picker based on initial source
    if (widget.initialSource != PostMediaSource.none && widget.initialSource != PostMediaSource.textOnly) {
      Future.microtask(() {
        if (!mounted) return;
        switch (widget.initialSource) {
          case PostMediaSource.photo:
            _pickImage(ImageSource.gallery);
            break;
          case PostMediaSource.video:
            _pickVideo();
            break;
          case PostMediaSource.camera:
            _pickImage(ImageSource.camera);
            break;
          default:
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ── Image Picker ──

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final sizeMB = bytes.length / (1024 * 1024);
      if (sizeMB > _maxImageSizeMB) {
        setState(
            () => _error = 'Bild zu gro\u00df (max. ${_maxImageSizeMB}MB)');
        return;
      }

      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = file.name;
        _carouselImages = [];
        _carouselImageNames = [];
        _pickedVideoBytes = null;
        _pickedVideoName = null;
        _pickedVideoSizeMB = null;
        _error = null;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ── Multi-Image Picker (Carousel) ──

  Future<void> _pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(imageQuality: 85, limit: 10);
      if (files.isEmpty) return;

      final images = <Uint8List>[];
      final names = <String>[];

      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;

        final sizeMB = bytes.length / (1024 * 1024);
        if (sizeMB > _maxImageSizeMB) {
          setState(() => _error = '${file.name} ist zu gro\u00df (max. ${_maxImageSizeMB}MB)');
          return;
        }

        images.add(bytes);
        names.add(file.name);
      }

      if (images.isEmpty) return;

      // If only 1 image selected, treat as single image
      if (images.length == 1) {
        setState(() {
          _pickedImageBytes = images.first;
          _pickedImageName = names.first;
          _carouselImages = [];
          _carouselImageNames = [];
          _pickedVideoBytes = null;
          _pickedVideoName = null;
          _pickedVideoSizeMB = null;
          _error = null;
          _currentStep = 1;
        });
        return;
      }

      setState(() {
        _carouselImages = images;
        _carouselImageNames = names;
        _pickedImageBytes = null;
        _pickedImageName = null;
        _pickedVideoBytes = null;
        _pickedVideoName = null;
        _pickedVideoSizeMB = null;
        _error = null;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ── Video Picker ──

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final ext = file.name.split('.').last.toLowerCase();
      if (!_allowedVideoTypes.contains(ext)) {
        setState(() => _error =
            'Nicht unterst\u00fctztes Format. Erlaubt: ${_allowedVideoTypes.join(', ')}');
        return;
      }

      final sizeMB = bytes.length / (1024 * 1024);
      if (sizeMB > _maxVideoSizeMB) {
        setState(
            () => _error = 'Video zu gro\u00df (max. ${_maxVideoSizeMB}MB)');
        return;
      }

      // Security confirmation
      if (!mounted) return;
      final confirmed = await _showUploadConfirmation(
        title: 'Video hochladen?',
        fileName: file.name,
        sizeMB: sizeMB,
        icon: Icons.videocam_rounded,
      );
      if (confirmed != true) return;

      setState(() {
        _pickedVideoBytes = bytes;
        _pickedVideoName = file.name;
        _pickedVideoSizeMB = sizeMB;
        _pickedImageBytes = null;
        _pickedImageName = null;
        _error = null;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ── Security Confirmation Dialog ──

  Future<bool?> _showUploadConfirmation({
    required String title,
    required String fileName,
    required double sizeMB,
    required IconData icon,
  }) {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security_rounded, color: accentColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(icon, color: accentColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fileName,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${sizeMB.toStringAsFixed(1)} MB',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bitte stelle sicher, dass diese Datei keine '
                      'sch\u00e4dlichen Inhalte enth\u00e4lt. '
                      'Hochgeladene Dateien werden \u00f6ffentlich sichtbar.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange.shade200,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Abbrechen',
                style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: accentColor),
            child: Text('Hochladen',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Submit Post ──

  Future<void> _handlePost() async {
    final body = _textController.text.trim();
    if (body.isEmpty &&
        _pickedImageBytes == null &&
        _carouselImages.isEmpty &&
        _pickedVideoBytes == null) {
      setState(
          () => _error = 'Bitte Text, Bild oder Video hinzuf\u00fcgen.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      String? imageUrl;
      String? videoUrl;

      // Upload image
      if (_pickedImageBytes != null) {
        final ext = _pickedImageName?.split('.').last ?? 'jpg';
        final path = '$userId/${timestamp}_img.$ext';
        await supabase.storage.from('posts').uploadBinary(
              path,
              _pickedImageBytes!,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );
        imageUrl = supabase.storage.from('posts').getPublicUrl(path);
      }

      // Upload video
      if (_pickedVideoBytes != null) {
        final ext = _pickedVideoName?.split('.').last ?? 'mp4';
        final path = '$userId/${timestamp}_vid.$ext';
        await supabase.storage.from('posts').uploadBinary(
              path,
              _pickedVideoBytes!,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );
        videoUrl = supabase.storage.from('posts').getPublicUrl(path);
      }

      // Upload carousel images
      final carouselUrls = <String>[];
      if (_carouselImages.isNotEmpty) {
        for (int i = 0; i < _carouselImages.length; i++) {
          final imgBytes = _carouselImages[i];
          final imgName = i < _carouselImageNames.length ? _carouselImageNames[i] : 'img_$i.jpg';
          final ext = imgName.split('.').last;
          final path = '$userId/${timestamp}_carousel_${i}_$imgName';
          await supabase.storage.from('posts').uploadBinary(
            path,
            imgBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
          carouselUrls.add(supabase.storage.from('posts').getPublicUrl(path));
        }
        // Set the first image as the main image_url for backward compat
        imageUrl ??= carouselUrls.first;
      }

      // Determine media type
      String mediaType = 'text';
      if (videoUrl != null) {
        mediaType = 'video';
      } else if (carouselUrls.length > 1) {
        mediaType = 'carousel';
      } else if (imageUrl != null) {
        mediaType = 'image';
      }

      final community = ref.read(communityProvider);
      final feedRepo = ref.read(feedRepositoryProvider);
      final post = await feedRepo.createPost(
        body: body.isNotEmpty ? body : null,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        community: community?.name,
        mediaType: mediaType,
        topicIds: _selectedTopicIds.isNotEmpty ? _selectedTopicIds : null,
        attachmentUrls: carouselUrls.length > 1 ? carouselUrls : null,
      );

      ref.read(feedNotifierProvider.notifier).addPost(post);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final brightness = Theme.of(context).brightness;
    final scaffoldBg = community?.scaffoldFor(brightness) ?? (brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5));
    final cardBg = community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white);
    final textOnBg = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

    // Step 2 uses its own Scaffold with appBar for guaranteed visible Posten button
    if (_currentStep == 1) {
      return _buildStep2Scaffold(accentColor, scaffoldBg, textOnBg, faint);
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: _buildStep1MediaSelection(accentColor, cardBg, textOnBg, faint),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  STEP 1 — Media Selection (Fullscreen)
  // ═══════════════════════════════════════════════════

  Widget _buildStep1MediaSelection(Color accentColor, Color cardBg, Color textOnBg, Color faint) {
    return Column(
      key: const ValueKey('step1'),
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded,
                    color: textOnBg, size: 26),
              ),
              Expanded(
                child: Text(
                  'Neuer Beitrag',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textOnBg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: Text(
                  '\u00dcberspringen',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textOnBg.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Error ──
        if (_error != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.red.shade200)),
                  ),
                ],
              ),
            ),
          ),

        const Spacer(),

        // ── Media Cards ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _MediaCard(
                icon: Icons.photo_library_rounded,
                title: 'Foto',
                subtitle: 'Aus der Galerie w\u00e4hlen',
                gradient: [accentColor, accentColor.withValues(alpha: 0.6)],
                cardColor: cardBg,
                textColor: textOnBg,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(height: 14),
              _MediaCard(
                icon: Icons.collections_rounded,
                title: 'Carousel',
                subtitle: 'Mehrere Bilder w\u00e4hlen (\u2264 10)',
                gradient: [
                  const Color(0xFF42A5F5),
                  const Color(0xFF42A5F5).withValues(alpha: 0.6),
                ],
                cardColor: cardBg,
                textColor: textOnBg,
                onTap: _pickMultipleImages,
              ),
              const SizedBox(height: 14),
              _MediaCard(
                icon: Icons.videocam_rounded,
                title: 'Video',
                subtitle: 'Bis zu 3 Minuten, max. 50 MB',
                gradient: [
                  const Color(0xFFE040FB),
                  const Color(0xFFE040FB).withValues(alpha: 0.6),
                ],
                cardColor: cardBg,
                textColor: textOnBg,
                onTap: _pickVideo,
              ),
              const SizedBox(height: 14),
              if (!kIsWeb)
                _MediaCard(
                  icon: Icons.camera_alt_rounded,
                  title: 'Kamera',
                  subtitle: 'Jetzt ein Foto aufnehmen',
                  gradient: [
                    const Color(0xFF00E676),
                    const Color(0xFF00E676).withValues(alpha: 0.6),
                  ],
                  cardColor: cardBg,
                  textColor: textOnBg,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
            ],
          ),
        ),

        const Spacer(),

        // ── Text-only link ──
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: TextButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: Icon(Icons.edit_note_rounded,
                color: textOnBg.withValues(alpha: 0.5), size: 20),
            label: Text(
              'Nur Text posten',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: textOnBg.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  STEP 2 — Post Details (Text + Post)
  // ═══════════════════════════════════════════════════

  // ── Step 2: Completely separate Scaffold with AppBar ──
  // This guarantees the "Posten" button is ALWAYS visible, even with keyboard open.
  Widget _buildStep2Scaffold(Color accentColor, Color scaffoldBg, Color textOnBg, Color faint) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is Authenticated ? authState.user : null;
    final username = user?.displayName ?? user?.username ?? 'Rider';
    final community = ref.watch(communityProvider);
    final avatarUrl = community == Community.cargram
        ? (user?.avatarUrlCargram ?? user?.avatarUrl)
        : user?.avatarUrl;

    final canPost = _textController.text.isNotEmpty ||
        _pickedImageBytes != null ||
        _carouselImages.isNotEmpty ||
        _pickedVideoBytes != null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: true,
      // ── AppBar = guaranteed visible header with Posten button ──
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  // If came from textOnly source, just close the whole screen
                  if (widget.initialSource == PostMediaSource.textOnly) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {
                      _currentStep = 0;
                      _error = null;
                    });
                  }
                },
          icon: Icon(Icons.close_rounded, color: textOnBg, size: 26),
        ),
        title: Text(
          'Neuer Beitrag',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textOnBg,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : FilledButton(
                    onPressed: canPost ? _handlePost : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      disabledBackgroundColor:
                          accentColor.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                    ),
                    child: Text(
                      'Posten',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: canPost
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: faint),
        ),
      ),
      // ── Body = scrollable content ──
      body: Column(
        children: [
          // ── Error ──
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: Colors.red))),
                ]),
              ),
            ),

          // ── Scrollable Content ──
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Preview
                    if (_pickedImageBytes != null) _buildImagePreview(),
                    if (_carouselImages.isNotEmpty) _buildCarouselPreview(),
                    if (_pickedVideoBytes != null) _buildVideoPreview(accentColor),

                    if (_pickedImageBytes != null || _carouselImages.isNotEmpty || _pickedVideoBytes != null)
                      const SizedBox(height: 16),

                    // User info + Text input
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: avatarUrl == null
                                ? LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)])
                                : null,
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? Image.network(avatarUrl, width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'R',
                                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ))
                                : Center(
                                    child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'R',
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textOnBg,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _textController,
                                autofocus: true,
                                maxLines: null,
                                // More lines on tablets so it doesn't look cramped
                                minLines: MediaQuery.of(context).size.height > 800 ? 6 : 3,
                                enabled: !_isSubmitting,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: textOnBg,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Was gibt\'s Neues?',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: textOnBg.withValues(alpha: 0.25),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Topic Picker ──
                    const SizedBox(height: 16),
                    TopicPicker(
                      selectedTopicIds: _selectedTopicIds,
                      onChanged: (ids) => setState(() => _selectedTopicIds = ids),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image Preview (Step 2) ──

  Widget _buildImagePreview() {
    // Use screen height to scale image preview — bigger on tablets
    final screenH = MediaQuery.of(context).size.height;
    final previewHeight = (screenH * 0.3).clamp(180.0, 400.0);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: previewHeight,
            child: Image.memory(_pickedImageBytes!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: _isSubmitting
                ? null
                : () => setState(() {
                      _pickedImageBytes = null;
                      _pickedImageName = null;
                    }),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.6),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ── Carousel Preview (Step 2) ──

  Widget _buildCarouselPreview() {
    final screenH = MediaQuery.of(context).size.height;
    final previewHeight = (screenH * 0.25).clamp(150.0, 300.0);
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? const Color(0xFFFF6B35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image count badge
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.collections_rounded, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_carouselImages.length} Bilder',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              if (!_isSubmitting)
                GestureDetector(
                  onTap: () => setState(() {
                    _carouselImages = [];
                    _carouselImageNames = [];
                  }),
                  child: Text(
                    'Alle entfernen',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontal scrollable previews
        SizedBox(
          height: previewHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _carouselImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: previewHeight * 0.75,
                      height: previewHeight,
                      child: Image.memory(
                        _carouselImages[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Position badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Remove button
                  if (!_isSubmitting)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _carouselImages.removeAt(index);
                            _carouselImageNames.removeAt(index);
                            // If only 1 left, convert to single image
                            if (_carouselImages.length == 1) {
                              _pickedImageBytes = _carouselImages.first;
                              _pickedImageName = _carouselImageNames.first;
                              _carouselImages = [];
                              _carouselImageNames = [];
                            } else if (_carouselImages.isEmpty) {
                              // No images left
                            }
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Video Preview (Step 2) ──

  Widget _buildVideoPreview(Color accentColor) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textOnBg = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: textOnBg.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.videocam_rounded,
                color: accentColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedVideoName ?? 'Video',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textOnBg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pickedVideoSizeMB?.toStringAsFixed(1) ?? '?'} MB',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textOnBg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          if (!_isSubmitting)
            GestureDetector(
              onTap: () => setState(() {
                _pickedVideoBytes = null;
                _pickedVideoName = null;
                _pickedVideoSizeMB = null;
              }),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: textOnBg.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.close_rounded,
                    color: textOnBg, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Media Selection Card (Step 1)
// ═══════════════════════════════════════════════════

class _MediaCard extends StatefulWidget {
  const _MediaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.cardColor,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final Color? cardColor;
  final Color? textColor;

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.cardColor ?? const Color(0xFF1A1A1A),
            border: Border.all(
              color: widget.gradient.first.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradient,
                  ),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 18),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor ?? Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: (widget.textColor ?? Colors.white).withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: (widget.textColor ?? Colors.white).withValues(alpha: 0.25),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
