import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Preview of a picked image, decoded at [cacheWidth] pixels instead of full
/// resolution (a 12 MP photo is ~48 MB as a bitmap).
class DocumentImagePreview extends StatelessWidget {
  const DocumentImagePreview({
    super.key,
    required this.bytes,
    required this.cacheWidth,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final Uint8List bytes;
  final int cacheWidth;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    fit: BoxFit.cover,
    semanticLabel: semanticLabel,
  );
}
