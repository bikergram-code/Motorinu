import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/community.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import '../../../theme/app_theme.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileSheet(),
    );
  }
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _displayNameController = TextEditingController();
  final _bikernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _postalCodeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  // Avatar
  Uint8List? _selectedAvatarBytes;
  String? _selectedAvatarName;
  String? _existingAvatarUrl;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      _displayNameController.text = authState.user.displayName ?? '';
      _bikernameController.text = authState.user.bikername ?? '';
      _bioController.text = authState.user.bio ?? '';
      _postalCodeController.text = authState.user.postalCode ?? '';
      // Show the avatar for the current community
      final community = ref.read(communityProvider);
      if (community == Community.cargram) {
        _existingAvatarUrl = authState.user.avatarUrlCargram ??
            authState.user.avatarUrl;
      } else {
        _existingAvatarUrl = authState.user.avatarUrl;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bikernameController.dispose();
    _bioController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedAvatarBytes = bytes;
      _selectedAvatarName = picked.name;
    });
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(profileRepositoryProvider);

      // Upload avatar for the current community
      if (_selectedAvatarBytes != null && _selectedAvatarName != null) {
        final community = ref.read(communityProvider);
        await repo.uploadAvatar(
          _selectedAvatarBytes!,
          _selectedAvatarName!,
          community: community?.name ?? 'bikergram',
        );
      }

      await repo.updateProfile(
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        bikername: _bikernameController.text.trim().isNotEmpty
            ? _bikernameController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        postalCode: _postalCodeController.text.trim().isNotEmpty
            ? _postalCodeController.text.trim()
            : null,
      );

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
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06));

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
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textOnCard.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text('Profil bearbeiten',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textOnCard)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: faint),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar Upload ──
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildAvatarContent(accentColor),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: community?.cardFor(brightness) ?? (brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white),
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      community == Community.cargram
                          ? 'Cargram-Profilbild ändern'
                          : 'Bikergram-Profilbild ändern',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _label('Anzeigename'),
                  const SizedBox(height: 8),
                  _input(_displayNameController, 'Dein Name', accentColor: accentColor),

                  const SizedBox(height: 20),
                  _label('Bikername'),
                  const SizedBox(height: 8),
                  _input(_bikernameController, 'Dein Spitzname', accentColor: accentColor),

                  const SizedBox(height: 20),
                  _label('Bio'),
                  const SizedBox(height: 8),
                  _input(_bioController, 'Erzähl etwas über dich...', maxLines: 3, accentColor: accentColor),

                  const SizedBox(height: 20),
                  _label('PLZ'),
                  const SizedBox(height: 8),
                  _input(_postalCodeController, 'z.B. 50667',
                      keyboardType: TextInputType.number, accentColor: accentColor),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style:
                            GoogleFonts.inter(fontSize: 13, color: Colors.red)),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text('Speichern',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(Color accentColor) {
    // Show newly selected image
    if (_selectedAvatarBytes != null) {
      return Image.memory(
        _selectedAvatarBytes!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
      );
    }

    // Show existing avatar from server
    if (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty) {
      return Image.network(
        _existingAvatarUrl!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialsAvatar(accentColor),
      );
    }

    // Fallback: initials
    return _buildInitialsAvatar(accentColor);
  }

  Widget _buildInitialsAvatar(Color accentColor) {
    final authState = ref.read(authNotifierProvider);
    final username = authState is Authenticated
        ? (authState.user.displayName ?? authState.user.username)
        : '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textMuted = community?.textMutedColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6C757D));
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textMuted));
  }

  Widget _input(TextEditingController controller, String hint,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      required Color accentColor}) {
    final brightness = Theme.of(context).brightness;
    final community = ref.watch(communityProvider);
    final textOnCard = community?.textColor(brightness) ??
        (brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: textOnCard),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 15, color: textOnCard.withValues(alpha: 0.2)),
        filled: true,
        fillColor: textOnCard.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: textOnCard.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: textOnCard.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: accentColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
