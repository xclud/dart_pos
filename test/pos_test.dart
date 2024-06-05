import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;

void main() {
  final key = Uint8List.fromList([
    0x46,
    0xB0,
    0xAA,
    0x84,
    0xC9,
    0xAB,
    0x2C,
    0xC8,
    0x7F,
    0xBD,
    0x7C,
    0x73,
    0x6E,
    0x51,
    0x5C,
    0x06
  ]);

  final data4 = Uint8List.fromList([0x12, 0x12, 0x34, 0xff]);
  final data8 =
      Uint8List.fromList([0x12, 0x12, 0x34, 0xff, 0x12, 0x12, 0x34, 0xff]);

  test('MAC Calculation', () {
    expect(pos.iso9797MacAlgorithm3String(key, data4), '4331374535464237');
    expect(pos.iso9797MacAlgorithm3String(key, data8), '4235354235393536');
  });
}
