import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class ProfileSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> formData;
  final VoidCallback onComplete;

  const ProfileSummaryWidget({
    super.key,
    required this.formData,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String s(dynamic v) => (v ?? '').toString();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dein Profil (Vorschau)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 2.h),
          _row('Sprache', s(formData['language'])),
          _row('Name', s(formData['name'])),
          _row('Alter', s(formData['age'])),
          _row('PLZ', s(formData['postalCode'])),
          _row('E‑Mail', s(formData['email'])),
          _row('Bikes', s(formData['bikeCount'])),
          SizedBox(height: 3.h),
          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 1.6.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Profil erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8.h),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(v, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
