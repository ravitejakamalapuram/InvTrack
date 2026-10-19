import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/document_image_preview.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('decodes a downscaled bitmap, not the full-size photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentImagePreview(
          bytes: _png,
          width: 48,
          height: 48,
          cacheWidth: 144,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 144);
  });
}
