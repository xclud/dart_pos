import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;
import 'package:iso9797/iso9797.dart' as iso9797;

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

  test('PAN', () {
    final message = pos.Message('0100');
    message.pan = '4761739001010119';

    final messageData = message.encode();

    expect(messageData, '01004000000000000000164761739001010119');
  });

  test('NII', () {
    final message = pos.Message('0100');
    message.nii = 0x0300;

    final messageData = message.encode();

    expect(messageData, '010000000100000000000300');
  });
  // test('Terminal Id', () {
  //   final message = pos.Message('0100');
  //   message.terminalId = '31327676';

  //   final messageData = message.encode();

  //   expect(messageData, '0100000000000080000031327676');
  // });

  // test('Merchant Id', () {
  //   final message = pos.Message('0100');
  //   message.merchantId = 'MOTITILL_000001';

  //   final messageData = message.encode();

  //   expect(messageData, '01000000000000400000MOTITILL_000001');
  // });

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
    ).encode();

    message.mac = Uint8List(8);

    final messageData = message.encode();

    final messageHex = messageData.toUpperCase();

    expect(messageHex,
        '0800203801000001000192000012345614240306100300002511014E3832573333303936350602352E302E330203300215320000000000000000');
  });

  test('Parse', () {
    final data =
        '0110703801000E8180001656207623412209433100000000000000001234570431280621006630303030303030303030303020202020202033303001143230000000001615503230323430363231303433313238333634';

    final msg = pos.Message.parse(data);

    expect(msg.mti, '0110');
    expect(msg.pan, '5620762341220943');
    expect(msg.processCode, 0x310000);
    expect(msg.amount, 0);
    expect(msg.stan, 123457);
    expect(msg.nii, 0x0066);
    expect(msg.rrn, '000000000000');
    expect(msg.identificationReferenceNumber, '      ');
    expect(msg.terminalId, '3001143230000000');
    print(msg);
  });
}
