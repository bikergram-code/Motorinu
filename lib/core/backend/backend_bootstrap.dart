import '../api_config.dart';
import 'backend_token_store.dart';
import 'bikergram_backend_api.dart';

/// One-liner factory so you can use:
/// final api = BackendBootstrap.api;
class BackendBootstrap {
  BackendBootstrap._();

  static final BackendTokenStore tokenStore = BackendTokenStore();

  static final BikergramBackendApi api = BikergramBackendApi(
    tokens: tokenStore,
    baseUrl: ApiConfig.baseUrl(),
  );
}
