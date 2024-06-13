import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;

const sid = 'N82W330965';
const aid = '5.0.3';

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

  test('Create LogOn Message', () {
    final message = pos.Message('0800');

    final now = DateTime(2024, 6, 10, 14, 24, 03);

    message.processCode = '920000';
    message.stan = 123456;
    message.dateTime = now;
    message.nii = '0300';

    message.set(48, createField48ForLogOn(sid, aid));
    message.mac = '0000000000000000';

    final messageData = message.encode();

    final messageHex = hex.encode(messageData).toUpperCase();

    expect(messageHex,
        '0800203801000001000192000012345614240306100300002511014E3832573333303936350602352E302E330203300215320000000000000000');
  });
}

List<int> createField48ForLogOn(String serialNumber, String version,
    [int language = 0x30]) {
  final posSerial = [0x01, ...serialNumber.codeUnits];
  final langugeCode = [0x03, language];
  final appVersion = [0x02, ...version.codeUnits];
  const connectionType = [0x15, 0x32];

  var field48 = _decimalAsHexBytes(posSerial.length, 2) +
      posSerial +
      _decimalAsHexBytes(appVersion.length, 2) +
      appVersion +
      _decimalAsHexBytes(langugeCode.length, 2) +
      langugeCode +
      _decimalAsHexBytes(connectionType.length, 2) +
      connectionType;

  return field48;
}

List<int> _decimalAsHexBytes(int v, int l) {
  final y = v.toString().padLeft(l, '0');
  return hex.decode(y);
}
