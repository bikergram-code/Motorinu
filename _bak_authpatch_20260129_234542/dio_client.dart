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
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    // separates Dio ohne AuthInterceptor (Refresh darf nicht in Loop laufen)
    final refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

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
