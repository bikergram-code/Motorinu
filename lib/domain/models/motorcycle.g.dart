// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motorcycle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Motorcycle _$MotorcycleFromJson(Map<String, dynamic> json) => _Motorcycle(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  make: json['make'] as String,
  model: json['model'] as String,
  year: (json['year'] as num).toInt(),
  imageUrl: json['imageUrl'] as String?,
  category: json['category'] as String?,
  isPrimary: json['isPrimary'] as bool? ?? false,
  specifications:
      (json['specifications'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  modifications:
      (json['modifications'] as List<dynamic>?)
          ?.map((e) => Modification.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$MotorcycleToJson(_Motorcycle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'make': instance.make,
      'model': instance.model,
      'year': instance.year,
      'imageUrl': instance.imageUrl,
      'category': instance.category,
      'isPrimary': instance.isPrimary,
      'specifications': instance.specifications,
      'modifications': instance.modifications,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_Modification _$ModificationFromJson(Map<String, dynamic> json) =>
    _Modification(
      id: (json['id'] as num).toInt(),
      motorcycleId: (json['motorcycleId'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      date: json['date'] == null
          ? null
          : DateTime.parse(json['date'] as String),
      beforeImageUrl: json['beforeImageUrl'] as String?,
      afterImageUrl: json['afterImageUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ModificationToJson(_Modification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'motorcycleId': instance.motorcycleId,
      'title': instance.title,
      'description': instance.description,
      'cost': instance.cost,
      'date': instance.date?.toIso8601String(),
      'beforeImageUrl': instance.beforeImageUrl,
      'afterImageUrl': instance.afterImageUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
