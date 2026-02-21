import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../domain/models/post.dart';
import '../../../providers/core/providers.dart';
import '../../../providers/feed/feed_notifier.dart';
import '../../../theme/app_theme.dart';

class EditPostSheet extends ConsumerStatefulWidget {
  const EditPostSheet({super.key, required this.post});

  final Post post;

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPostSheet(post: post),
    );
  }

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  String? _error;

  // Image state
  String? _currentImageUrl;
  Uint8List? _newImageBytes;
  String? _newImageName;
  bool _imageRemoved = false;

  // Video state
  String? _currentVideoUrl;
  Uint8List? _newVideoBytes;
  String? _newVideoName;
  bool _videoRemoved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.body ?? '');
    _currentImageUrl = widget.post.imageUrl;
    _currentVideoUrl = widget.post.videoUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      setState(() {
        _newImageBytes = bytes;
        _newImageName = file.name;
        _imageRemoved = false;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _newImageName = null;
      _currentImageUrl = null;
      _imageRemoved = true;
    });
  }

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

      final sizeMB = bytes.length / (1024 * 1024);
      if (sizeMB > 50) {
        setState(() => _error = 'Video zu gro\u00df (max. 50 MB)');
        return;
      }

      setState(() {
        _newVideoBytes = bytes;
        _newVideoName = file.name;
        _videoRemoved = false;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _removeVideo() {
    setState(() {
      _newVideoBytes = null;
      _newVideoName = null;
      _currentVideoUrl = null;
      _videoRemoved = true;
    });
  }

  bool get _hasChanges {
    final textChanged =
        _controller.text.trim() != (widget.post.body ?? '').trim();
    final imageChanged = _newImageBytes != null || _imageRemoved;
    final videoChanged = _newVideoBytes != null || _videoRemoved;
    return textChanged || imageChanged || videoChanged;
  }

  Future<void> _handleSave() async {
    final body = _controller.text.trim();
    final hasAnyMedia = _newImageBytes != null ||
        (_currentImageUrl != null && !_imageRemoved) ||
        _newVideoBytes != null ||
        (_currentVideoUrl != null && !_videoRemoved);

    if (body.isEmpty && !hasAnyMedia) {
      setState(() => _error = 'Bitte Text, Bild oder Video angeben.');
      return;
    }
    if (!_hasChanges) {
      Navigator.pop(context);
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

      String? imageUrl = _currentImageUrl;
      String? videoUrl = _currentVideoUrl;

      // Upload new image if picked
      if (_newImageBytes != null) {
        final ext = _newImageName?.split('.').last ?? 'jpg';
        final path = '$userId/${timestamp}_img.$ext';
        await supabase.storage.from('posts').uploadBinary(
              path,
              _newImageBytes!,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );
        imageUrl = supabase.storage.from('posts').getPublicUrl(path);
      } else if (_imageRemoved) {
        imageUrl = null;
      }

      // Upload new video if picked
      if (_newVideoBytes != null) {
        final ext = _newVideoName?.split('.').last ?? 'mp4';
        final path = '$userId/${timestamp}_vid.$ext';
        await supabase.storage.from('posts').uploadBinary(
              path,
              _newVideoBytes!,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );
        videoUrl = supabase.storage.from('posts').getPublicUrl(path);
      } else if (_videoRemoved) {
        videoUrl = null;
      }

      // Build update map
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (body != (widget.post.body ?? '').trim()) {
        updateData['body'] = body.isNotEmpty ? body : null;
      }
      if (imageUrl != widget.post.imageUrl) {
        updateData['image_url'] = imageUrl;
      }
      if (videoUrl != widget.post.videoUrl) {
        updateData['video_url'] = videoUrl;
      }

      final data = await supabase
          .from('posts')
          .update(updateData)
          .eq('id', widget.post.id)
          .select('*, profiles!inner(username, display_name, avatar_url, bikername)')
          .single();

      // Refresh feed to show updated post
      await ref.read(feedNotifierProvider.notifier).loadFeed();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    final accentColor = community?.accentColor ?? AppTheme.accentDark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final brightness = Theme.of(context).brightness;
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

    final hasImage = _newImageBytes != null ||
        (_currentImageUrl != null && !_imageRemoved);
    final hasVideo = _newVideoBytes != null ||
        (_currentVideoUrl != null && !_videoRemoved);

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textOnCard.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Flexible(
                  child: Text('Beitrag bearbeiten',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textOnCard),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(
                        onPressed: _hasChanges ? _handleSave : null,
                        child: Text('Speichern',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _hasChanges
                                    ? accentColor
                                    : textOnCard
                                        .withValues(alpha: 0.2))),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: faint),

          // Text field
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                enabled: !_isSubmitting,
                style: GoogleFonts.inter(
                    fontSize: 16, color: textOnCard, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Text eingeben...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: textOnCard.withValues(alpha: 0.2)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Image preview
          if (hasImage)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 180,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 180,
                      child: _newImageBytes != null
                          ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
                          : Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: textOnCard.withValues(alpha: 0.05),
                                child: Center(
                                  child: Icon(Icons.image_outlined,
                                      size: 40,
                                      color: textOnCard
                                          .withValues(alpha: 0.15)),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (!_isSubmitting)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Video preview
          if (hasVideo)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: textOnCard.withValues(alpha: 0.05),
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.videocam_rounded,
                            color: accentColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _newVideoName ?? 'Video',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textOnCard),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_newVideoBytes != null)
                              Text(
                                '${(_newVideoBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textOnCard
                                        .withValues(alpha: 0.4)),
                              )
                            else
                              Text(
                                'Vorhandenes Video',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textOnCard
                                        .withValues(alpha: 0.4)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  if (!_isSubmitting)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeVideo,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (_error != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_error!,
                  style:
                      GoogleFonts.inter(fontSize: 13, color: Colors.red)),
            ),

          const SizedBox(height: 8),

          // Action bar with image + video picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: faint)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  _ActionIcon(
                      icon: Icons.image_outlined,
                      color: accentColor,
                      onTap: _isSubmitting
                          ? () {}
                          : () => _pickImage(ImageSource.gallery)),
                  if (!kIsWeb)
                    _ActionIcon(
                        icon: Icons.camera_alt_outlined,
                        color: accentColor,
                        onTap: _isSubmitting
                            ? () {}
                            : () => _pickImage(ImageSource.camera)),
                  _ActionIcon(
                      icon: Icons.videocam_outlined,
                      color: accentColor,
                      onTap: _isSubmitting ? () {} : _pickVideo),
                  const Spacer(),
                  Text('${_controller.text.length}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textOnCard.withValues(alpha: 0.25))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 24, color: color.withValues(alpha: 0.7)),
      ),
    );
  }
}
