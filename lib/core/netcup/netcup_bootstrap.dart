import 'api_client.dart' as netcup;
import 'profile_draft_repository.dart';
import 'profile_draft_store.dart';
import '../api_config.dart';

class NetcupBootstrap {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  static netcup.ApiClient createApiClient({
    Future<String?> Function()? sessionTokenProvider,
  }) {
    netcup.ApiClient.configure(
      baseUrl: baseUrl,
      sessionTokenProvider: sessionTokenProvider,
    );
    return netcup.ApiClient.instance;
  }

  static ProfileDraftStore createDraftStore({
    Future<String?> Function()? sessionTokenProvider,
  }) {
    final api = createApiClient(sessionTokenProvider: sessionTokenProvider);
    final repo = ProfileDraftRepository(api);
    // Supports both old and new ctor styles.
    return ProfileDraftStore(repo);
  }
}
