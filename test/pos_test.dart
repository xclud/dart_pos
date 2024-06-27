import 'package:test/test.dart';
import 'package:pos/pos.dart' as pos;

const tid = 30011432;
const mid = 30000000509940;
const sid = 'N82W330965';
const aid = '5.0.3';

void main() {
  test('Decode & Encode', () {
    const expected =
        '081020380000028100019200001234560329530627303230202020202020200016155032303234303632373033323935353631344139364443';
    final data =
        '081020380000028100019200001234560329530627303230202020202020200016155032303234303632373033323935353631344139364443';

    final msg = pos.Message.parse(data);

    final actual = msg.encode().toUpperCase();
    expect(actual, expected);
  });
}
