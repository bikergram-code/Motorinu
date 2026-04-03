import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/community.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/auth/auth_state.dart';
import '../../../providers/core/providers.dart';
import '../../../theme/app_theme.dart';

class EditDatingProfileSheet extends ConsumerStatefulWidget {
  const EditDatingProfileSheet({super.key});

  @override
  ConsumerState<EditDatingProfileSheet> createState() =>
      _EditDatingProfileSheetState();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditDatingProfileSheet(),
    );
  }
}

class _EditDatingProfileSheetState
    extends ConsumerState<EditDatingProfileSheet> {
  final _bioController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _selectedGender;
  int? _birthYear;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  String? _error;

  // Dating photos (up to 6)
  final List<String> _photoUrls = [];
  static const _maxPhotos = 6;

  // Vehicle (picked from garage)
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authNotifierProvider);
    if (authState is Authenticated) {
      final user = authState.user;
      _displayNameController.text =
          user.displayName ?? user.bikername ?? user.username;
      _bioController.text = user.bio ?? '';
      _selectedGender = user.gender;
      _birthYear = user.birthYear;
    }
    _loadVehicles();
    _loadDatingPhotos();
  }

  Future<void> _loadDatingPhotos() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await Supabase.instance.client
          .from('profiles')
          .select('dating_photos, avatar_url, avatar_url_cargram')
          .eq('id', userId)
          .single();
      if (!mounted) return;
      final photos = res['dating_photos'];
      final community = ref.read(communityProvider);
      setState(() {
        if (photos is List && photos.isNotEmpty) {
          _photoUrls.addAll(List<String>.from(photos));
        } else {
          // Fall back to avatar as first photo
          final avatar = community == Community.cargram
              ? (res['avatar_url_cargram'] ?? res['avatar_url'])
              : res['avatar_url'];
          if (avatar != null && (avatar as String).isNotEmpty) {
            _photoUrls.add(avatar);
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadVehicles() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      // Load ALL vehicles (both bikergram + cargram) — no community filter
      final vehicles = await VehicleRepository()
          .getMyVehicles(userId: userId);
      if (mounted) {
        setState(() => _vehicles = vehicles.map((v) => {
          'id': v.id,
          'brand': v.brand,
          'model': v.model,
          'horsepower': v.horsepower,
          'community': v.community,
        }).toList());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bioController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photoUrls.length >= _maxPhotos) return;
    final picker = ImagePicker();
    final remaining = _maxPhotos - _photoUrls.length;
    final files = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
      limit: remaining,
    );
    if (files.isEmpty) return;

    setState(() => _isUploadingPhoto = true);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';

    try {
      for (final picked in files) {
        if (_photoUrls.length >= _maxPhotos) break;
        final bytes = await picked.readAsBytes();
        final ext = picked.path.split('.').last.toLowerCase();
        final fileName =
            'dating/${userId}_${DateTime.now().millisecondsSinceEpoch}_${_photoUrls.length}.$ext';

        await Supabase.instance.client.storage
            .from('posts')
            .uploadBinary(fileName, bytes);

        final url = Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(fileName);

        if (!mounted) return;
        setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload fehlgeschlagen: $e')),
        );
      }
    }
    if (mounted) setState(() => _isUploadingPhoto = false);
  }

  void _removePhoto(int index) {
    setState(() => _photoUrls.removeAt(index));
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ProfileRepository();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      await repo.updateProfile(
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        gender: _selectedGender,
        birthYear: _birthYear,
      );

      // Save dating photos separately (array column)
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'dating_photos': _photoUrls})
            .eq('id', userId);
      }

      // Also set first dating photo as avatar if user has no avatar
      if (_photoUrls.isNotEmpty && userId != null) {
        final community = ref.read(communityProvider);
        final profile = await repo.getProfile(userId);
        final currentAvatar = community == Community.cargram
            ? profile['avatar_url_cargram']
            : profile['avatar_url'];
        if (currentAvatar == null || (currentAvatar as String).isEmpty) {
          await repo.updateProfile(
            avatarUrl: community != Community.cargram ? _photoUrls.first : null,
            avatarUrlCargram:
                community == Community.cargram ? _photoUrls.first : null,
          );
        }
      }

      await ref.read(authNotifierProvider.notifier).checkAuth();

      if (!mounted) return;
      Navigator.pop(context, true); // true = changed
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
    final isDark = brightness == Brightness.dark;
    final textColor = community?.textColor(brightness) ??
        (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final mutedColor = community?.textMutedColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF6C757D));
    final faint = community?.faintColor(brightness) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));
    final cardBg = community?.cardFor(brightness) ??
        (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Dating-Profil',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: faint),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fotos (Grid: 3 Spalten, bis zu 6) ──
                  _label('Fotos (max. $_maxPhotos)', textColor),
                  const SizedBox(height: 4),
                  Text(
                    'Erstes Foto = Hauptbild. Tippe ✕ zum Entfernen.',
                    style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount:
                        (_photoUrls.length < _maxPhotos)
                            ? _photoUrls.length + 1
                            : _photoUrls.length,
                    itemBuilder: (ctx, i) {
                      // Add-button tile
                      if (i >= _photoUrls.length) {
                        return GestureDetector(
                          onTap: _isUploadingPhoto ? null : _pickPhotos,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: _isUploadingPhoto
                                ? Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: accentColor, strokeWidth: 2),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_rounded,
                                          color: accentColor, size: 28),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Hinzufügen',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      }
                      // Photo tile
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: _photoUrls[i],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: accentColor.withValues(alpha: 0.1),
                                child: Icon(Icons.broken_image_rounded,
                                    color: mutedColor),
                              ),
                            ),
                          ),
                          // Main photo badge
                          if (i == 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Haupt',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          // Remove button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
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

                  const SizedBox(height: 20),

                  // ── Name ──
                  _label('Name', textColor),
                  const SizedBox(height: 8),
                  _input(_displayNameController, 'Dein Name', accentColor,
                      textColor, mutedColor),

                  const SizedBox(height: 20),

                  // ── Bio / Über mich ──
                  _label('Über mich', textColor),
                  const SizedBox(height: 8),
                  _input(
                    _bioController,
                    'Erzähl etwas über dich...\nWas fährst du? Was suchst du?',
                    accentColor,
                    textColor,
                    mutedColor,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 20),

                  // ── Geschlecht ──
                  _label('Geschlecht', textColor),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _genderOption('male', '♂ Männlich', accentColor,
                          textColor, mutedColor, isDark),
                      const SizedBox(width: 8),
                      _genderOption('female', '♀ Weiblich', accentColor,
                          textColor, mutedColor, isDark),
                      const SizedBox(width: 8),
                      _genderOption('other', '⚧ Divers', accentColor,
                          textColor, mutedColor, isDark),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Geburtsjahr ──
                  _label('Geburtsjahr', textColor),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: textColor.withValues(alpha: 0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _birthYear,
                        hint: Text('Jahr wählen',
                            style: GoogleFonts.inter(
                                fontSize: 15, color: mutedColor)),
                        dropdownColor: cardBg,
                        isExpanded: true,
                        items: List.generate(
                          DateTime.now().year - 1940 - 7,
                          (i) {
                            final year = DateTime.now().year - 8 - i;
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text('$year',
                                  style: GoogleFonts.inter(
                                      fontSize: 15, color: textColor)),
                            );
                          },
                        ),
                        onChanged: (v) => setState(() => _birthYear = v),
                      ),
                    ),
                  ),
                  if (_birthYear != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '→ ${DateTime.now().year - _birthYear!} Jahre alt',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Meine Fahrzeuge (beide Communities) ──
                  if (_vehicles.isNotEmpty) ...[
                    _label('Meine Fahrzeuge', textColor),
                    const SizedBox(height: 4),
                    Text(
                      'Bikes & Autos — wird auf deiner Karte angezeigt',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: mutedColor),
                    ),
                    const SizedBox(height: 8),
                    ..._vehicles.map((v) {
                      final vid = v['id'].toString();
                      final brand = v['brand'] ?? '';
                      final model = v['model'] ?? '';
                      final hp = v['horsepower'];
                      final vCommunity = v['community'] as String?;
                      final isBike = vCommunity == 'bikergram';
                      final isSelected = _selectedVehicleId == vid;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => setState(() =>
                              _selectedVehicleId = isSelected ? null : vid),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.12)
                                  : textColor.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : textColor.withValues(alpha: 0.08),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBike
                                      ? Icons.two_wheeler_rounded
                                      : Icons.directions_car_rounded,
                                  color: isSelected ? accentColor : mutedColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '$brand $model${hp != null ? ' · ${hp}PS' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? accentColor
                                          : textColor,
                                    ),
                                  ),
                                ),
                                // Community badge
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isBike ? Colors.orange : Colors.blue)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBike ? 'Bike' : 'Auto',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isBike ? Colors.orange : Colors.blue,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: accentColor, size: 22),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.red)),
                  ],

                  const SizedBox(height: 20),

                  // ── Save button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor:
                            accentColor.withValues(alpha: 0.5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Speichern',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint,
    Color accentColor,
    Color textColor,
    Color mutedColor, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: mutedColor),
        filled: true,
        fillColor: textColor.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _genderOption(String value, String label, Color accentColor,
      Color textColor, Color mutedColor, bool isDark) {
    final selected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.15)
                : textColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentColor : textColor.withValues(alpha: 0.08),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accentColor : mutedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
