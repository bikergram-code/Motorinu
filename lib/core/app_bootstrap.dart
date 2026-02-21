import 'api_client.dart';
import 'api_config.dart';
import 'auth/token_store.dart';

class AppBootstrap {
  static Future<void> init() async {
    // Single source of truth: TokenStore (bikergram_tokens_v1)
    ApiClient.configure(
      baseUrl: ApiConfig.apiBaseUrl,
      sessionTokenProvider: () async {
        final pair = await TokenStore().read();
        return pair?.accessToken;
      },
    );

    // Warm up token into ApiClient cache.
    final pair = await TokenStore().read();
    final token = pair?.accessToken;
    if (token != null && token.isNotEmpty) {
      await ApiClient.instance.setToken(token);
    } else {
      await ApiClient.instance.setToken(null);
    }
  }
}
