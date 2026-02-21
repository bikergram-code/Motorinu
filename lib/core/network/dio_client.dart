import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import 'auth_interceptor.dart';

class DioClient {
  final Dio dio;
  final Dio refreshDio;

  DioClient._(this.dio, this.refreshDio);

  factory DioClient({
    required String baseUrl,
    required TokenStore tokenStore,
  }) {
    final base = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    );

    final dio = Dio(base);

    // separates Dio ohne AuthInterceptor (Refresh darf nicht in Loop laufen)
    final refreshDio = Dio(base);

    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokenStore: tokenStore,
    ));

    // optional: Logging
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
      error: true,
    ));

    return DioClient._(dio, refreshDio);
  }
}
