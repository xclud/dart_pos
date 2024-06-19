import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;

const tid = 30011432;
const mid = 30000000509940;
const sid = 'N82W330965';
const aid = '5.0.3';

// const macKey = [
//   0x3D,
//   0xEA,
//   0x62,
//   0x23,
//   0x53,
//   0x4F,
//   0x33,
//   0x60,
//   0x0C,
//   0x84,
//   0x35,
//   0x01,
//   0x7F,
//   0xC2,
//   0xB5,
//   0xE9
// ];

final macKey = Uint8List.fromList([
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

void main() {
  test('Create LogOn Message', () {
    final message = pos.Message('0800');

    final now = DateTime(2024, 6, 10, 14, 24, 03);

    message.processCode = 0x920000;
    message.stan = 123456;
    message.dateTime = now;
    message.nii = 0x0300;
    message.dataElement = pos.DataElement(
      serialNumber: sid,
      appVersion: aid,
      language: 0x30,
      connectionType: 0x32,
    );

    message.mac = Uint8List(8);

    final messageData = message.encode();

    final messageHex = hex.encode(messageData).toUpperCase();

    expect(messageHex,
        '0800203801000001000192000012345614240306100300002511014E3832573333303936350602352E302E330203300215320000000000000000');
  });
}
