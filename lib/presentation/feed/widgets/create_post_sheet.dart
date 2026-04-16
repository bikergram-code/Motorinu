import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';

import '../../../core/community.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/feed/feed_notifier.dart';
import '../../../theme/app_theme.dart';
import '../utils/video_upload_helper.dart' as video_upload;
import 'topic_picker.dart';
import 'video_trim_screen.dart';

// Max file sizes
const _maxImageSizeMB = 10;
const _maxVideoSizeMB = 100;

// Allowed video extensions
const _allowedVideoTypes = ['mp4', 'mov', 'avi', 'mkv', 'webm'];

/// Initial media source to auto-open on screen launch.
enum PostMediaSource { none, photo, video, camera, textOnly }

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.initialSource = PostMediaSource.none, this.initialText});

  final PostMediaSource initialSource;
  final String? initialText;

  /// Opens the fullscreen post creator.
  /// Uses rootNavigator so it opens ABOVE the MainShell (no Global Top Bar overlap).
  static void show(BuildContext context, {PostMediaSource source = PostMediaSource.none, String? initialText}) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => CreatePostScreen(initialSource: source, initialText: initialText),
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
  String? _pickedVideoFilePath; // File path for efficient upload
  double? _pickedVideoSizeMB;
  Uint8List? _videoThumbnailBytes; // Auto-generated thumbnail from first frame

  // Topics
  List<int> _selectedTopicIds = [];

  // Visibility: 'public', 'followers', 'private'
  String _visibility = 'public';

  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill text (e.g. from POI share)
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      _currentStep = 1;
    }
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

  // ── Video Picker (FilePicker — sieht ALLE Dateien inkl. Downloads) ──

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      setState(() => _error = 'Video-Upload ist in der Web-Version nicht verf\u00fcgbar. Bitte die App verwenden.');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null) return;

      final fileName = pickedFile.name;
      final ext = fileName.split('.').last.toLowerCase();

      if (!_allowedVideoTypes.contains(ext)) {
        setState(() => _error =
            'Nicht unterst\u00fctztes Format. Erlaubt: ${_allowedVideoTypes.join(', ')}');
        return;
      }

      // ── Optional: Video trimmen ──
      if (!mounted) return;
      final community = ref.read(communityProvider);
      final accentColor = community?.accentColor ?? AppTheme.accentDark;

      final trimmedFile = await VideoTrimScreen.show(
        context,
        videoFile: filePath,
        accentColor: accentColor,
      );
      // User cancelled trim screen
      if (trimmedFile == null) return;

      var bytes = await trimmedFile.readAsBytes();
      if (bytes.isEmpty) return;

      var sizeMB = bytes.length / (1024 * 1024);
      var finalName = fileName;

      var finalFilePath = trimmedFile.path;

      // If too large → offer compression
      if (sizeMB > _maxVideoSizeMB) {
        if (!mounted) return;
        final shouldCompress = await _showCompressDialog(sizeMB);
        if (shouldCompress != true) return;

        // Compress with progress
        if (!mounted) return;
        final compressed = await _compressVideo(filePath, sizeMB);
        if (compressed == null) return;

        bytes = compressed.$1;
        sizeMB = compressed.$2;
        finalFilePath = compressed.$3;
        finalName = 'compressed_$fileName';

        // Still too big after compression?
        if (sizeMB > _maxVideoSizeMB) {
          setState(() => _error =
              'Video ist nach Komprimierung noch ${sizeMB.toStringAsFixed(1)} MB (max. ${_maxVideoSizeMB}MB)');
          return;
        }
      }

      // Security confirmation
      if (!mounted) return;
      final confirmed = await _showUploadConfirmation(
        title: 'Video hochladen?',
        fileName: finalName,
        sizeMB: sizeMB,
        icon: Icons.videocam_rounded,
      );
      if (confirmed != true) return;

      // Generate video thumbnail (first frame) for preview & upload
      Uint8List? thumbBytes;
      try {
        final thumbFile = await VideoCompress.getFileThumbnail(
          finalFilePath,
          quality: 50,
          position: -1, // first frame
        );
        thumbBytes = await thumbFile.readAsBytes();
      } catch (_) {
        // Thumbnail generation is optional — continue without it
      }

      setState(() {
        _pickedVideoBytes = bytes;
        _pickedVideoName = finalName;
        _pickedVideoFilePath = finalFilePath;
        _pickedVideoSizeMB = sizeMB;
        _videoThumbnailBytes = thumbBytes;
        _pickedImageBytes = null;
        _pickedImageName = null;
        _error = null;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ── Compress Dialog (fragt ob komprimiert werden soll) ──

  Future<bool?> _showCompressDialog(double sizeMB) {
    final community = ref.read(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF222222) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.compress_rounded, color: accentColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Video zu gro\u00df',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Das Video ist ${sizeMB.toStringAsFixed(1)} MB gro\u00df '
                      '(max. ${_maxVideoSizeMB}MB).\n\n'
                      'Soll es automatisch komprimiert werden?',
                      style: GoogleFonts.inter(
                          fontSize: 13,
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
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: accentColor),
            icon: const Icon(Icons.compress_rounded, size: 18, color: Colors.white),
            label: Text('Komprimieren',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Video Compression mit Progress-Overlay ──

  /// Returns (bytes, sizeMB, compressedFilePath) or null on failure
  Future<(Uint8List, double, String)?> _compressVideo(String filePath, double originalMB) async {
    // Pick quality based on file size.
    // IMPORTANT: Always use MediumQuality as minimum to cap resolution
    // at ~1280x720. DefaultQuality does NOT resize, which can produce
    // videos (e.g. 2288x1080) that exceed device decoder capabilities.
    VideoQuality quality;
    if (originalMB > 200) {
      quality = VideoQuality.LowQuality;
    } else {
      quality = VideoQuality.MediumQuality;
    }

    // Show progress overlay
    final progressNotifier = ValueNotifier<double>(0.0);
    final overlayEntry = OverlayEntry(
      builder: (context) => _CompressProgressOverlay(progress: progressNotifier),
    );

    Overlay.of(context).insert(overlayEntry);

    // Listen to compression progress (store subscription for proper cleanup)
    final subscription = VideoCompress.compressProgress$.subscribe((progress) {
      progressNotifier.value = progress / 100.0;
    });

    try {
      final info = await VideoCompress.compressVideo(
        filePath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      subscription.unsubscribe();
      overlayEntry.remove();
      progressNotifier.dispose();

      if (info == null || info.file == null) {
        setState(() => _error = 'Komprimierung fehlgeschlagen');
        return null;
      }

      final compressedFile = info.file!;
      final compressedBytes = await compressedFile.readAsBytes();
      final compressedMB = compressedBytes.length / (1024 * 1024);

      return (compressedBytes, compressedMB, compressedFile.path);
    } catch (e) {
      subscription.unsubscribe();
      overlayEntry.remove();
      progressNotifier.dispose();
      setState(() => _error = 'Komprimierung fehlgeschlagen: $e');
      return null;
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

    final isDark2 = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark2 ? const Color(0xFF222222) : Colors.white,
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

  // ── TUS Resumable Upload (6MB chunks — bypasses 413 payload limit) ──

  /// Map video extension to a valid MIME type with fallback.
  static String _videoContentType(String ext) {
    const types = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      '3gp': 'video/3gpp',
    };
    return types[ext.toLowerCase()] ?? 'video/mp4';
  }

  // _tusUploadFile moved to video_upload_helper.dart (conditional import)

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

      // Upload video via TUS resumable upload (6MB chunks — avoids 413)
      // Shows a progress overlay so the user knows what's happening.
      String? thumbnailUrl;
      if (_pickedVideoBytes != null) {
        final ext = _pickedVideoName?.split('.').last ?? 'mp4';
        final path = '$userId/${timestamp}_vid.$ext';
        final contentType = _videoContentType(ext);

        // ── Upload progress overlay ──
        final uploadProgress = ValueNotifier<double>(0.0);
        final uploadOverlay = OverlayEntry(
          builder: (_) => _UploadProgressOverlay(
            progress: uploadProgress,
            sizeMB: _pickedVideoSizeMB ?? 0,
          ),
        );
        Overlay.of(context).insert(uploadOverlay);

        try {
          if (_pickedVideoFilePath != null) {
            await video_upload.tusUploadFile(
              bucketName: 'posts',
              objectPath: path,
              filePath: _pickedVideoFilePath!,
              contentType: contentType,
              onProgress: (p) => uploadProgress.value = p,
            );
          } else {
            await video_upload.tusUploadBytes(
              bucketName: 'posts',
              objectPath: path,
              bytes: _pickedVideoBytes!,
              ext: ext,
              contentType: contentType,
              onProgress: (p) => uploadProgress.value = p,
            );
          }
        } finally {
          uploadOverlay.remove();
          uploadProgress.dispose();
        }
        videoUrl = supabase.storage.from('posts').getPublicUrl(path);

        // ── Upload video thumbnail ──
        if (_videoThumbnailBytes != null) {
          try {
            final thumbPath = '$userId/${timestamp}_thumb.jpg';
            await supabase.storage.from('posts').uploadBinary(
              thumbPath,
              _videoThumbnailBytes!,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
            thumbnailUrl = supabase.storage.from('posts').getPublicUrl(thumbPath);
          } catch (_) {
            // Thumbnail upload is optional
          }
        }
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
        thumbnailUrl: thumbnailUrl,
        community: community?.name,
        mediaType: mediaType,
        topicIds: _selectedTopicIds.isNotEmpty ? _selectedTopicIds : null,
        attachmentUrls: carouselUrls.length > 1 ? carouselUrls : null,
        visibility: _visibility,
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

        // ── Scrollable content ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Column(
              children: [
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

                const SizedBox(height: 24),

                // ── Media Cards ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Foto + Carousel only when NOT opened from Reels (video source)
                      if (widget.initialSource != PostMediaSource.video) ...[
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
                      ],
                      _MediaCard(
                        icon: Icons.videocam_rounded,
                        title: 'Video',
                        subtitle: 'Bis zu 3 Minuten, max. 100 MB',
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

                const SizedBox(height: 24),

                // ── Text-only link (hide when opened from Reels) ──
                if (widget.initialSource != PostMediaSource.video)
                  TextButton.icon(
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
              ],
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

                    // ── Visibility Picker ──
                    const SizedBox(height: 16),
                    _buildVisibilityPicker(accentColor, textOnBg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Visibility Picker ──

  Widget _buildVisibilityPicker(Color accentColor, Color textColor) {
    const options = [
      ('public', Icons.public_rounded, 'Alle'),
      ('followers', Icons.people_rounded, 'Follower'),
      ('private', Icons.lock_rounded, 'Privat'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final (value, icon, label) = opt;
        final isSelected = _visibility == value;
        return GestureDetector(
          onTap: () => setState(() => _visibility = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : textColor.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: isSelected ? accentColor : textColor.withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? accentColor : textColor.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
        );
      }).toList(),
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

    // If we have a thumbnail, show it as a larger visual preview
    if (_videoThumbnailBytes != null) {
      final screenH = MediaQuery.of(context).size.height;
      final previewHeight = (screenH * 0.25).clamp(140.0, 280.0);

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: previewHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_videoThumbnailBytes!, fit: BoxFit.cover),
                  // Video overlay icon + info
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 14,
                    child: Row(
                      children: [
                        Icon(Icons.videocam_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_pickedVideoSizeMB?.toStringAsFixed(1) ?? '?'} MB',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play icon
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isSubmitting)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() {
                  _pickedVideoBytes = null;
                  _pickedVideoName = null;
                  _pickedVideoSizeMB = null;
                  _videoThumbnailBytes = null;
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

    // Fallback: simple card without thumbnail
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
                _videoThumbnailBytes = null;
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
            color: widget.cardColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
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

// ═══════════════════════════════════════════════════
//  Compress Progress Overlay
// ═══════════════════════════════════════════════════

class _CompressProgressOverlay extends StatelessWidget {
  const _CompressProgressOverlay({required this.progress});

  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.compress_rounded,
                  color: Color(0xFFE040FB), size: 40),
              const SizedBox(height: 16),
              Text(
                'Video wird komprimiert\u2026',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, __) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value > 0 ? value : null,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE040FB)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value > 0
                            ? '${(value * 100).toInt()}%'
                            : 'Wird vorbereitet\u2026',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Upload Progress Overlay (TUS chunked upload)
// ═══════════════════════════════════════════════════

class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay({
    required this.progress,
    required this.sizeMB,
  });

  final ValueNotifier<double> progress;
  final double sizeMB;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_rounded,
                  color: Color(0xFF42A5F5), size: 40),
              const SizedBox(height: 16),
              Text(
                'Video wird hochgeladen\u2026',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${sizeMB.toStringAsFixed(1)} MB',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, __) {
                  final uploadedMB = value * sizeMB;
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value > 0 ? value : null,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF42A5F5)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            value > 0
                                ? '${(value * 100).toInt()}%'
                                : 'Verbinde\u2026',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF42A5F5),
                            ),
                          ),
                          if (value > 0)
                            Text(
                              '${uploadedMB.toStringAsFixed(1)} / ${sizeMB.toStringAsFixed(1)} MB',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
