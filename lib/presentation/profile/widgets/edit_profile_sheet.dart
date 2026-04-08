import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

// ── Länder-Liste ──
class _CountryOption {
  final String code;
  final String label;
  final String flag;
  const _CountryOption({required this.code, required this.label, required this.flag});
}

const List<_CountryOption> _countries = [
  _CountryOption(code: 'de', label: 'Deutschland', flag: '🇩🇪'),
  _CountryOption(code: 'at', label: 'Österreich', flag: '🇦🇹'),
  _CountryOption(code: 'ch', label: 'Schweiz', flag: '🇨🇭'),
  _CountryOption(code: 'it', label: 'Italien', flag: '🇮🇹'),
  _CountryOption(code: 'pl', label: 'Polen', flag: '🇵🇱'),
  _CountryOption(code: 'fr', label: 'Frankreich', flag: '🇫🇷'),
  _CountryOption(code: 'nl', label: 'Niederlande', flag: '🇳🇱'),
  _CountryOption(code: 'be', label: 'Belgien', flag: '🇧🇪'),
  _CountryOption(code: 'cz', label: 'Tschechien', flag: '🇨🇿'),
  _CountryOption(code: 'es', label: 'Spanien', flag: '🇪🇸'),
  _CountryOption(code: 'gb', label: 'Großbritannien', flag: '🇬🇧'),
  _CountryOption(code: 'us', label: 'USA', flag: '🇺🇸'),
  _CountryOption(code: 'tr', label: 'Türkei', flag: '🇹🇷'),
  _CountryOption(code: 'hr', label: 'Kroatien', flag: '🇭🇷'),
  _CountryOption(code: 'gr', label: 'Griechenland', flag: '🇬🇷'),
];

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

  // ── Neue Felder ──
  String? _selectedCountry;
  int? _birthYear;
  int? _motoStartAge;
  int? _carStartAge;
  bool _hasTrackExperience = false;
  String? _selectedGender;

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
      // Neue Felder laden
      _selectedCountry = authState.user.country;
      _birthYear = authState.user.birthYear;
      _motoStartAge = authState.user.motoStartAge;
      _carStartAge = authState.user.carStartAge;
      _hasTrackExperience = authState.user.hasTrackExperience;
      _selectedGender = authState.user.gender;
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

      // GPS-Position automatisch erfassen für Karten-Standort
      double? homeLat;
      double? homeLng;
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          homeLat = pos.latitude;
          homeLng = pos.longitude;
        } else {
          final freshPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
          homeLat = freshPos.latitude;
          homeLng = freshPos.longitude;
        }
      } catch (_) {
        // GPS nicht verfügbar — kein Problem, PLZ-Fallback bleibt
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
        country: _selectedCountry,
        birthYear: _birthYear,
        motoStartAge: _motoStartAge,
        carStartAge: _carStartAge,
        hasTrackExperience: _hasTrackExperience,
        gender: _selectedGender,
        homeLat: homeLat,
        homeLng: homeLng,
      );

      // Auth-State neu laden damit die Werte überall aktualisiert sind
      await ref.read(authNotifierProvider.notifier).checkAuth();

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

    final currentYear = DateTime.now().year;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
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
                  _label('Info'),
                  const SizedBox(height: 8),
                  _input(_bioController, 'Erzähl etwas über dich...', maxLines: 3, accentColor: accentColor),

                  const SizedBox(height: 20),
                  _label('PLZ'),
                  const SizedBox(height: 8),
                  _input(_postalCodeController, 'z.B. 50667',
                      keyboardType: TextInputType.number, accentColor: accentColor),

                  // ═══════════════════════════════════════════
                  // ── Über dich ──
                  // ═══════════════════════════════════════════
                  const SizedBox(height: 28),
                  _sectionHeader('Über dich', textOnCard),
                  const SizedBox(height: 16),

                  // ── Land ──
                  _label('Land'),
                  const SizedBox(height: 8),
                  _dropdown<String>(
                    value: _selectedCountry,
                    hint: 'Land wählen',
                    items: _countries.map((c) => DropdownMenuItem<String>(
                      value: c.code,
                      child: Text('${c.flag}  ${c.label}',
                          style: GoogleFonts.inter(fontSize: 15, color: textOnCard)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCountry = v),
                    accentColor: accentColor,
                    textOnCard: textOnCard,
                  ),

                  const SizedBox(height: 20),

                  // ── Geschlecht ──
                  _label('Geschlecht'),
                  const SizedBox(height: 8),
                  _dropdown<String>(
                    value: _selectedGender,
                    hint: 'Nicht angeben',
                    items: [
                      DropdownMenuItem<String>(value: 'male', child: Text('Männlich', style: GoogleFonts.inter(fontSize: 15, color: textOnCard))),
                      DropdownMenuItem<String>(value: 'female', child: Text('Weiblich', style: GoogleFonts.inter(fontSize: 15, color: textOnCard))),
                      DropdownMenuItem<String>(value: 'other', child: Text('Divers', style: GoogleFonts.inter(fontSize: 15, color: textOnCard))),
                    ],
                    onChanged: (v) => setState(() => _selectedGender = v),
                    accentColor: accentColor,
                    textOnCard: textOnCard,
                  ),

                  const SizedBox(height: 20),

                  // ── Geburtsjahr ──
                  _label('Geburtsjahr'),
                  const SizedBox(height: 8),
                  _dropdown<int>(
                    value: _birthYear,
                    hint: 'Geburtsjahr wählen',
                    items: List.generate(
                      currentYear - 1940 - 7,
                      (i) {
                        final year = currentYear - 8 - i;
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year',
                              style: GoogleFonts.inter(fontSize: 15, color: textOnCard)),
                        );
                      },
                    ),
                    onChanged: (v) => setState(() => _birthYear = v),
                    accentColor: accentColor,
                    textOnCard: textOnCard,
                  ),

                  // ═══════════════════════════════════════════
                  // ── Erfahrung ──
                  // ═══════════════════════════════════════════
                  const SizedBox(height: 28),
                  _sectionHeader('Erfahrung', textOnCard),
                  const SizedBox(height: 16),

                  // ── Motorrad-Erfahrung ──
                  _label('Motorrad fahre ich seit ich ... bin'),
                  const SizedBox(height: 8),
                  _dropdown<int>(
                    value: _motoStartAge,
                    hint: 'Alter wählen',
                    items: List.generate(82, (i) {
                      final age = i + 14;
                      return DropdownMenuItem<int>(
                        value: age,
                        child: Text('$age Jahre',
                            style: GoogleFonts.inter(fontSize: 15, color: textOnCard)),
                      );
                    }),
                    onChanged: (v) => setState(() => _motoStartAge = v),
                    accentColor: accentColor,
                    textOnCard: textOnCard,
                  ),
                  if (_motoStartAge != null && _birthYear != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '→ ${currentYear - _birthYear! - _motoStartAge! > 0 ? currentYear - _birthYear! - _motoStartAge! : 0} Jahre Erfahrung',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Auto-Erfahrung ──
                  _label('Auto fahre ich seit ich ... bin'),
                  const SizedBox(height: 8),
                  _dropdown<int>(
                    value: _carStartAge,
                    hint: 'Alter wählen',
                    items: List.generate(82, (i) {
                      final age = i + 14;
                      return DropdownMenuItem<int>(
                        value: age,
                        child: Text('$age Jahre',
                            style: GoogleFonts.inter(fontSize: 15, color: textOnCard)),
                      );
                    }),
                    onChanged: (v) => setState(() => _carStartAge = v),
                    accentColor: accentColor,
                    textOnCard: textOnCard,
                  ),
                  if (_carStartAge != null && _birthYear != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '→ ${currentYear - _birthYear! - _carStartAge! > 0 ? currentYear - _birthYear! - _carStartAge! : 0} Jahre Erfahrung',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Rennstrecke ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: textOnCard.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: textOnCard.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          color: _hasTrackExperience ? accentColor : textMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rennstrecke',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textOnCard,
                                  )),
                              const SizedBox(height: 2),
                              Text('Schon auf der Rennstrecke gefahren?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textMuted,
                                  )),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _hasTrackExperience,
                          activeColor: accentColor,
                          onChanged: (v) => setState(() => _hasTrackExperience = v),
                        ),
                      ],
                    ),
                  ),

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

  // ── Section Header ──
  Widget _sectionHeader(String text, Color textColor) {
    return Row(
      children: [
        Expanded(child: Divider(color: textColor.withValues(alpha: 0.12))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              )),
        ),
        Expanded(child: Divider(color: textColor.withValues(alpha: 0.12))),
      ],
    );
  }

  // ── Dropdown Builder ──
  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color accentColor,
    required Color textOnCard,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: textOnCard.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textOnCard.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.any((item) => item.value == value) ? value : null,
          hint: Text(hint,
              style: GoogleFonts.inter(
                  fontSize: 15, color: textOnCard.withValues(alpha: 0.3))),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: textOnCard.withValues(alpha: 0.4)),
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
          items: items,
          onChanged: onChanged,
        ),
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
