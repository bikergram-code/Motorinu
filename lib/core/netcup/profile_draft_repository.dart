import '../api_client.dart';

/// Profile Draft Repository (PHP endpoints)
///
/// Endpoints:
/// POST /profile/draft/start.php
/// GET  /profile/draft/get.php?id=...
/// POST /profile/draft/step.php?id=...&step=...
/// POST /profile/draft/submit.php?id=...
///
/// Notes:
/// - Uses the lightweight `ApiClient` (http) instead of Dio.
/// - `getDraft()` treats HTTP 404 as a normal "draft_not_found" result.
class ProfileDraftRepository {
  final ApiClient _api;

  ProfileDraftRepository(this._api);

  /// Start (or resume) a draft for this device.
  Future<Map<String, dynamic>> startDraft({
    required String deviceId,
    bool debug = false,
  }) async {
    final path = '/profile/draft/start.php${debug ? '?debug=1' : ''}';
    final res = await _api.postJson(path, body: {'deviceId': deviceId});
    return _ensureMap(res);
  }

  /// Load a draft by id.
  /// Returns {"error":"draft_not_found"} when the draft does not exist.
  Future<Map<String, dynamic>> getDraft({
    required String draftId,
    bool debug = false,
  }) async {
    final path = '/profile/draft/get.php?id=${Uri.encodeQueryComponent(draftId)}${debug ? '&debug=1' : ''}';
    final res = await _api.getJson(path);

    // ApiClient returns an error-map for non-2xx, including "_status"
    if (res is Map && res['_status'] == 404) {
      return {'error': 'draft_not_found'};
    }

    return _ensureMap(res);
  }

  /// Save step payload.
  Future<Map<String, dynamic>> saveStep({
    required String draftId,
    required int step,
    required Map<String, dynamic> body,
    bool markCompleted = true,
    bool debug = false,
  }) async {
    final path =
        '/profile/draft/step.php?id=${Uri.encodeQueryComponent(draftId)}&step=$step${debug ? '&debug=1' : ''}';

    final res = await _api.postJson(
      path,
      body: {
        'data': body,
        'markCompleted': markCompleted,
      },
    );
    return _ensureMap(res);
  }

  /// Submit draft and create the final profile/user.
  Future<Map<String, dynamic>> submit({
    required String draftId,
    required Map<String, dynamic> body,
    bool debug = false,
  }) async {
    final path = '/profile/draft/submit.php?id=${Uri.encodeQueryComponent(draftId)}${debug ? '&debug=1' : ''}';
    final res = await _api.postJson(path, body: body);
    return _ensureMap(res);
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return {'error': 'invalid_response', 'data': data};
  }
}
