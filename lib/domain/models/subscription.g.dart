// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      businessId: (json['businessId'] as num?)?.toInt(),
      stripeSubscriptionId: json['stripeSubscriptionId'] as String,
      stripePriceId: json['stripePriceId'] as String,
      plan: json['plan'] as String,
      status: json['status'] as String,
      currentPeriodStart: DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.parse(json['canceledAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'businessId': instance.businessId,
      'stripeSubscriptionId': instance.stripeSubscriptionId,
      'stripePriceId': instance.stripePriceId,
      'plan': instance.plan,
      'status': instance.status,
      'currentPeriodStart': instance.currentPeriodStart.toIso8601String(),
      'currentPeriodEnd': instance.currentPeriodEnd.toIso8601String(),
      'canceledAt': instance.canceledAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_Payment _$PaymentFromJson(Map<String, dynamic> json) => _Payment(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  stripePaymentId: json['stripePaymentId'] as String,
  amount: (json['amount'] as num).toInt(),
  currency: json['currency'] as String? ?? 'eur',
  type: json['type'] as String,
  status: json['status'] as String,
  metadata: json['metadata'] as Map<String, dynamic>?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$PaymentToJson(_Payment instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'stripePaymentId': instance.stripePaymentId,
  'amount': instance.amount,
  'currency': instance.currency,
  'type': instance.type,
  'status': instance.status,
  'metadata': instance.metadata,
  'createdAt': instance.createdAt?.toIso8601String(),
};
