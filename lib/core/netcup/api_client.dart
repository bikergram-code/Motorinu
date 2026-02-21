export '../api_client.dart' show ApiClient;

import '../api_client.dart';

/// Compatibility helper: some parts of the project import
/// `package:bikergram/core/netcup/api_client.dart`.
/// This wrapper simply exposes the shared [ApiClient.instance].
class NetcupApiClient {
  static ApiClient get instance => ApiClient.instance;
}
