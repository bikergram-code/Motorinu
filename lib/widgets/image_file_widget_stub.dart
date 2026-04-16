import 'package:flutter/material.dart';

/// Web stub — file:// images don't exist on web, show placeholder.
Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
  Color? color,
  String? semanticLabel,
}) {
  return SizedBox(
    height: height,
    width: width,
    child: const Icon(Icons.image_not_supported_outlined, color: Colors.white24),
  );
}
