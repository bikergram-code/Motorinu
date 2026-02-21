import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile_draft_repository.dart';

class ProfileDraftStore {
  final ProfileDraftRepository _repo;

  String? _draftId;
  int _lastCompletedStep = 0;
  Map<String, dynamic> _steps = {};

  ProfileDraftStore(this._repo);
  ProfileDraftStore.named({required ProfileDraftRepository repo}) : _repo = repo;

  String? get draftId => _draftId;
  int get lastCompletedStep => _lastCompletedStep;
  Map<String, dynamic> get steps => _steps;

  static const String _kDraftIdKey = 'bg_profile_draft_id';
  static const String _kDeviceIdKey = 'bg_device_id';

  String _makeLocalDraftId(String deviceId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'local-$deviceId-$ts';
  }

  Future<String> _ensureDeviceId() async {
    final sp = await SharedPreferences.getInstance();
    final existing = sp.getString(_kDeviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final rnd = Random.secure();
    final buf = List<int>.generate(12, (_) => rnd.nextInt(256));
    final hex = buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final deviceId = 'dev-${DateTime.now().millisecondsSinceEpoch}-$hex';

    await sp.setString(_kDeviceIdKey, deviceId);
    return deviceId;
  }

  Future<void> _clearCachedDraftId() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kDraftIdKey);
    _draftId = null;
  }

  /// Ensures we have a draftId.
  ///
  /// If the backend draft endpoints are not deployed yet (e.g. HTTP 404),
  /// we fall back to a **local** draft id so the wizard can continue.
  Future<void> ensureDraft() async {
    // 1) if we already have a draftId in memory, try to load it
    if (_draftId != null && _draftId!.trim().isNotEmpty) {
      final loaded = await _repo.getDraft(draftId: _draftId!, debug: false);
      if (loaded['error'] == 'draft_not_found') {
        await _clearCachedDraftId();
      } else {
        _applyDraftResponse(loaded);
        return;
      }
    }

    // 2) try cached draftId from prefs
    final sp = await SharedPreferences.getInstance();
    final cached = sp.getString(_kDraftIdKey);
    if (cached != null && cached.trim().isNotEmpty) {
      _draftId = cached;
      final loaded = await _repo.getDraft(draftId: _draftId!, debug: false);
      if (loaded['error'] == 'draft_not_found') {
        await _clearCachedDraftId();
      } else {
        _applyDraftResponse(loaded);
        return;
      }
    }

    // 3) create new
    final deviceId = await _ensureDeviceId();
    final created = await _repo.startDraft(deviceId: deviceId, debug: false);
    final newId = (created['draftId'] ?? created['id'] ?? '').toString().trim();

    if (newId.isNotEmpty) {
      _draftId = newId;
      await sp.setString(_kDraftIdKey, _draftId!);
      _applyDraftResponse(created);
      return;
    }

    // Fallback: backend not ready -> keep local draft.
    _draftId = _makeLocalDraftId(deviceId);
    await sp.setString(_kDraftIdKey, _draftId!);
  }

  Future<void> saveStep(int step, Map<String, dynamic> data, {bool markCompleted = true}) async {
    await ensureDraft();
    final id = _draftId!;

    final body = <String, dynamic>{};
    for (final e in data.entries) {
      body[e.key] = _sanitize(e.value);
    }

    // Always update local cache, even if backend endpoints are not deployed yet.
    _steps['$step'] = body;
    if (markCompleted && step > _lastCompletedStep) _lastCompletedStep = step;

    final res = await _repo.saveStep(
      draftId: id,
      step: step,
      body: body,
      markCompleted: markCompleted,
      debug: false,
    );

    // Only apply backend response when it looks like a real draft.
    if ((res['draftId'] ?? res['id']) != null) {
      _applyDraftResponse(res);
    }
  }

  /// Submit draft and return backend response.
  ///
  /// Backwards/forwards compatible:
  /// - Older callers may pass `extraBody:`
  /// - Newer callers (wizard) pass `body:`
  Future<Map<String, dynamic>> submitAndReturn({
    Map<String, dynamic>? body,
    Map<String, dynamic> extraBody = const {},
  }) async {
    await ensureDraft();
    final id = _draftId!;

    final merged = <String, dynamic>{};
    if (extraBody.isNotEmpty) merged.addAll(extraBody);
    if (body != null && body.isNotEmpty) merged.addAll(body);

    final res = await _repo.submit(
      draftId: id,
      body: merged,
      debug: false,
    );

    return res;
  }

  void _applyDraftResponse(Map<String, dynamic> json) {
    // tolerate different shapes
    final did = (json['draftId'] ?? json['id'])?.toString();
    if (did != null && did.trim().isNotEmpty) _draftId = did;

    final lcs = json['lastCompletedStep'];
    if (lcs is int) _lastCompletedStep = lcs;
    if (lcs is String) _lastCompletedStep = int.tryParse(lcs) ?? _lastCompletedStep;

    final steps = json['steps'];
    if (steps is Map<String, dynamic>) {
      _steps = steps;
    } else if (steps is Map) {
      _steps = steps.map((k, v) => MapEntry(k.toString(), v));
    } else {
      _steps = {};
    }
  }

  dynamic _sanitize(dynamic v) {
    if (v == null) return null;
    if (v is num || v is bool || v is String) return v;
    if (v is List) return v.map(_sanitize).toList();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _sanitize(val)));
    }
    // fallback: JSON string
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }
}
