import 'dart:io' show zlib;
import 'dart:typed_data';

/// Encodes straight RGBA pixels as a 24-bit PNG with no alpha channel.
///
/// Transparent and translucent pixels are composited over white. The engine
/// can only write RGBA, which the Play listing check rejects.
Uint8List encodeRgbPng(int width, int height, Uint8List rgba) {
  if (rgba.length != width * height * 4) {
    throw ArgumentError.value(
      rgba.length,
      'rgba',
      'expected ${width * height * 4} bytes for ${width}x$height',
    );
  }

  // Each scanline starts with filter type 0 (none).
  final raw = Uint8List(height * (1 + width * 3));
  var out = 0;
  var src = 0;
  for (var y = 0; y < height; y++) {
    raw[out++] = 0;
    for (var x = 0; x < width; x++) {
      final alpha = rgba[src + 3];
      for (var c = 0; c < 3; c++) {
        raw[out++] = (rgba[src + c] * alpha + 255 * (255 - alpha) + 127) ~/ 255;
      }
      src += 4;
    }
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type 2: RGB, no alpha

  final bytes = BytesBuilder(copy: false)
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _addChunk(bytes, 'IHDR', header.buffer.asUint8List());
  _addChunk(bytes, 'IDAT', Uint8List.fromList(zlib.encode(raw)));
  _addChunk(bytes, 'IEND', Uint8List(0));
  return bytes.takeBytes();
}

void _addChunk(BytesBuilder bytes, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  bytes
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  final crc = ByteData(4)..setUint32(0, _crc32(typeBytes, data));
  bytes.add(crc.buffer.asUint8List());
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(Uint8List type, Uint8List data) {
  var c = 0xffffffff;
  for (final b in type) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xffffffff;
}
