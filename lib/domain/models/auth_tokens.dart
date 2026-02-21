import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

@freezed
abstract class AuthTokenPair with _$AuthTokenPair {
  const factory AuthTokenPair({
    required String accessToken,
    required String refreshToken,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
  }) = _AuthTokenPair;

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenPairFromJson(json);
}
