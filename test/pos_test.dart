import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;
import 'package:iso9797/iso9797.dart' as iso9797;

const tid = 30011432;
const mid = 30000000509940;
const sid = 'N82W330965';
const aid = '5.0.3';

const macKey = [
  0x3D,
  0xEA,
  0x62,
  0x23,
  0x53,
  0x4F,
  0x33,
  0x60,
  0x0C,
  0x84,
  0x35,
  0x01,
  0x7F,
  0xC2,
  0xB5,
  0xE9
];

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

    message.processCode = 0x920000;
    message.stan = 123456;
    message.dateTime = now;
    message.nii = '0300';
    message.dataElement = pos.DataElement(
      serialNumber: sid,
      appVersion: aid,
      language: 0x30,
      connectionType: 0x32,
    );

    message.mac = '0000000000000000';

    final messageData = message.encode();

    final messageHex = hex.encode(messageData).toUpperCase();

    expect(messageHex,
        '0800203801000001000192000012345614240306100300002511014E3832573333303936350602352E302E330203300215320000000000000000');
  });

  test('Create Balance Message', () {
    final now = DateTime(2024, 6, 10, 14, 24, 03);

    final message = pos.Message('0100');

    message.pan = '6274121195119854';
    message.processCode = 0x310000;
    message.track2 = '6274121195119854d281010052639594340480';
    message.stan = 123456;
    message.dateTime = now;
    message.nii = '0300';
    message.terminalId = tid.toString();
    message.merchantId = mid.toString();
    message.currency = 364;
    message.dataElement = pos.DataElement(
      serialNumber: sid,
      appVersion: aid,
      language: 0x30,
      connectionType: 0x32,
    );

    message.cardEntryMode = '0021';
    message.posConditionCode = '00';

    // Pin Block
    message.pinBlock = [0xB5, 0xB5, 0x2E, 0xB4, 0x10, 0x13, 0x9F, 0xD7];

    message.mac = '0000000000000000';
    final messageData = message.encode(algorithm: _calculateMac);

    final messageHex = hex.encode(messageData).toUpperCase();

    expect(messageHex,
        '01006038058020C1900116627412119511985431000012345614240306100021030000376274121195119854D28101005263959434048033303031313433323330303030303030353039393430002511014E3832573333303936350602352E302E33020330021532333634B5B52EB410139FD73231393042313445');
  });
}

Uint8List _calculateMac(List<int> data) {
  if (data.length % 8 != 0) {
    final copyOfData = data.toList();
    while (copyOfData.length % 8 != 0) {
      copyOfData.add(0);
    }

    data = Uint8List.fromList(copyOfData);
  }

  final mac = iso9797.algorithm3(macKey, data, iso9797.PaddingMode.method1);
  final macU = mac.map((e) => e.toRadixString(16)).join().toUpperCase();

  final result = macU.codeUnits.take(8);
  return Uint8List.fromList(result.toList());
}
