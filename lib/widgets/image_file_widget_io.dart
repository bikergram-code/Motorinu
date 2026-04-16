import 'dart:io';

import 'package:flutter/material.dart';

/// Native implementation — display local file image.
Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
  Color? color,
  String? semanticLabel,
}) {
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit ?? BoxFit.cover,
    color: color,
    semanticLabel: semanticLabel,
  );
}
