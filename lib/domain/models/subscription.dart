import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required int id,
    required int userId,
    int? businessId,
    required String stripeSubscriptionId,
    required String stripePriceId,
    required String plan,
    required String status,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    DateTime? canceledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}

@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    required int id,
    required int userId,
    required String stripePaymentId,
    required int amount,
    @Default('eur') String currency,
    required String type,
    required String status,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) = _Payment;

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
}
