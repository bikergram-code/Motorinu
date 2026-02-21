class ProfileDraft {
  final String draftId;
  final int lastCompletedStep; // 0..13
  final Map<int, Map<String, dynamic>> steps; // step -> payload
  final DateTime updatedAt;

  ProfileDraft({
    required this.draftId,
    required this.lastCompletedStep,
    required this.steps,
    required this.updatedAt,
  });

  static ProfileDraft fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as Map?)?.cast<String, dynamic>() ?? {};
    final map = <int, Map<String, dynamic>>{};

    for (final e in rawSteps.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null) continue;
      map[k] = (e.value as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    }

    return ProfileDraft(
      draftId: (json['draftId'] ?? '').toString(),
      lastCompletedStep: ((json['lastCompletedStep'] ?? 0) as num).toInt(),
      steps: map,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
