// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dart_des/dart_des.dart';

class Message {
  Message(this.mti);

  factory Message.parse(Uint8List data) {
    final bitmap = data.sublist(2, 10);
    final hexmap = hex.encode(bitmap);
    final v = int.parse(hexmap, radix: 16);
    final pb = v.toRadixString(2).padLeft(64, '0');
    final message = Message('0300');

    final parser = _MessageParser(data);

    for (int i = 1; i < 64; i++) {
      int o = i + 1;
      if (pb[i] != '1') {
        continue;
      }
      final field = _valueOf(o);

      final fieldData = parser.parse(field);
      message.set(field.no, fieldData);
    }

    return message;
  }

  factory Message.conntectionTest({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now().toLocal();

    final x = Message('0300');
    //x.set(1, '0300');
    x.set(3, [0x41, 0x00, 0x00]);
    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);
    x.set(49, [0x33, 0x36, 0x34]); // '364' in ASCII.

    return x;
  }

  factory Message.purchase({required int amount, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    final am = amount.toString().padLeft(12, '0');
    final amb = hex.decode(am);

    x.set(3, [0, 0, 0]);
    x.set(4, amb);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);
    x.set(46, [0x33, 0x30, 0x30]); // '300' in ASCII.
    x.set(48, '200003123001a11003456001c'.codeUnits);
    x.set(49, [0x33, 0x36, 0x34]); // '364' in ASCII.
    x.set(57, '1.4.8.2'.codeUnits);

    return x;
  }
  factory Message.ack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x04]);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  factory Message.nack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x05]);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  factory Message.eot({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x07]);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(39, [0x17]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  factory Message.dispose({DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x01]);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);

    return x;
  }

  final String mti;
  final _data = <int, Uint8List>{};

  Message clone() {
    final copy = Message(mti);
    copy._data.addAll(_data);

    return copy;
  }

  void set(int field, List<int> value) {
    _data[field] = Uint8List.fromList(value);
  }

  void setDate(int field, DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');

    final h = '$mm$dd';
    final x = hex.decode(h);

    _data[field] = Uint8List.fromList(x);
  }

  void setTime(int field, DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');

    final h = '$hh$mm$ss';
    final x = hex.decode(h);

    _data[field] = Uint8List.fromList(x);
  }

  String? get terminalId {
    final f = get(41);
    if (f == null) return null;

    return String.fromCharCodes(f);
  }

  Uint8List? get(int field) {
    return _data[field];
  }

  void unset(int field) {
    _data.remove(field);
  }

  Uint8List encode([bool addmac = true]) {
    var y = mac();

    set(64, y);
    final bdy = _body();
    final bmp = _bitmap();
    final mt = Uint8List.fromList(hex.decode(mti));

    final xx = mt + bmp + bdy;
    return Uint8List.fromList(xx);
  }

  Uint8List _body() {
    final bits = <Uint8List>[];

    for (var i = 1; i <= 64; i++) {
      final f = _data[i];

      if (f == null) {
        continue;
      }

      final fld = _valueOf(i);
      if (fld.fixed) {
        bits.add(f);
      } else {
        final bt = ByteData(4);
        bt.setUint32(0, f.length);

        final uu = bt.buffer
            .asUint8List()
            .reversed
            .take(fld.format!.length - 1)
            .toList()
            .reversed
            .toList()
            .map((e) => e.toString().padLeft(2, '0'))
            .map((e) => int.parse(e, radix: 16))
            .toList();

        bits.add(Uint8List.fromList(uu));
        bits.add(f);
      }
    }
    final v = bits.expand((e) => e).toList();
    return Uint8List.fromList(v);
  }

  Uint8List _bitmap() {
    final bits = <String>[];

    for (var i = 1; i <= 64; i++) {
      if (_data[i] != null) {
        bits.add('1');
      } else {
        bits.add('0');
      }
    }
    final v = int.parse(bits.join(), radix: 2);
    return _getBytes(v);
  }

  Uint8List mac() {
    final c = clone();
    c.set(64, List<int>.filled(8, 0));
    final bmp = c._bitmap();
    c.unset(64);

    final List<Uint8List> v = [];

    v.add(Uint8List.fromList(hex.decode(c.mti)));
    v.add(bmp);
    v.add(c._body());

    final vv = v.expand((element) => element).toList();
    final en = _caculateMAC(vv);

    final mc = en.skip((en.length ~/ 8 - 1) * 8).take(8).toList();

    return Uint8List.fromList(mc);
  }

  Map<String, Object> toJson() {
    final map = <String, Object>{};

    for (var i = 1; i <= 64; i++) {
      final f = _data[i];

      if (f == null) {
        continue;
      }

      final fld = _valueOf(i);

      if (fld.type == 'ans' || fld.type == 'an') {
        final z = f.indexOf(0);
        if (z > 0) {
          map[i.toString()] = String.fromCharCodes(f.take(z));
        } else {
          map[i.toString()] = String.fromCharCodes(f);
        }
      } else if (fld.type == 'n') {
        map[i.toString()] = hex.encode(f);
      } else if (fld.type == 'b') {
        map[i.toString()] = '0x${hex.encode(f).toUpperCase()}';
      }
    }

    return map;
  }

  @override
  String toString() {
    return _json.convert(toJson());
  }
}

final _json = JsonEncoder.withIndent(' ');

const _key = [0x23, 0xab, 0xe1, 0x82, 0xca, 0xb5, 0x64, 0x7d];
Uint8List _caculateMAC(List<int> data) {
  final desired = (data.length / 8.0).ceil() * 8;
  final count = desired - data.length;

  for (var i = 0; i < count; i++) {
    data.add(0);
  }

  final des =
      DES(key: _key, mode: DESMode.CBC, paddingType: DESPaddingType.None);
  final x = des.encrypt(data);

  return Uint8List.fromList(x);
}

Uint8List _getBytes(int i) {
  final n = ByteData(8);
  n.setUint64(0, i);

  return Uint8List.fromList(n.buffer.asUint8List());
}

const _01_Bitmap = _Field(1, 'b', 64, true, null);
const _02_PAN = _Field(2, 'n', 19, false, 'LL');
const _03_ProcessCode = _Field(3, 'n', 6, true, null);
const _04_AmountTransaction = _Field(4, 'n', 12, true, null);
const _05_AmountSettlement = _Field(5, 'n', 12, true, null);
const _06_AmountCardholder = _Field(6, 'n', 12, true, null);
const _07_TransmissionDataTime = _Field(7, 'n', 10, true, null);
const _08_AmountCardholder_BillingFee = _Field(8, 'n', 8, true, null);
const _09_ConversionRate_Settlement = _Field(9, 'n', 8, true, null);
const _10_ConversionRate_Cardholder = _Field(10, 'n', 8, true, null);
const _11_STAN = _Field(11, 'n', 6, true, null);
const _12_LocalTime = _Field(12, 'n', 6, true, null);
const _13_LocalDate = _Field(13, 'n', 4, true, null);
const _14_ExpirationDate = _Field(14, 'n', 4, true, null);
const _15_SettlementDate = _Field(15, 'n', 4, true, null);
const _16_CurrencyConversionDate = _Field(16, 'n', 4, true, null);
const _17_CaptureDate = _Field(17, 'n', 4, true, null);
const _18_MerchantType = _Field(18, 'n', 4, true, null);
const _19_AcquiringInstitution = _Field(19, 'n', 3, true, null);
const _20_PANExtended = _Field(20, 'n', 3, true, null);
const _21_ForwardingInstitution = _Field(21, 'n', 3, true, null);
const _22_EntryMode = _Field(22, 'n', 3, true, null);
const _23_PANSequence = _Field(23, 'n', 3, true, null);
const _24_NII_FunctionCode = _Field(24, 'n', 3, true, null);
const _25_POS_ConditionCode = _Field(25, 'n', 2, true, null);
const _26_POS_CaptureCode = _Field(26, 'n', 2, true, null);
const _27_AuthIdResponseLength = _Field(27, 'n', 1, true, null);
const _28_Amount_TransactionFee = _Field(28, 'x+n', 8, true, null);
const _29_Amount_SettlementFee = _Field(29, 'x+n', 8, true, null);
const _30_Amount_TransactionProcessingFee = _Field(30, 'x+n', 8, true, null);
const _31_Amount_SettlementProcessingFee = _Field(31, 'x+n', 8, true, null);
const _32_AcquiringInstitutionIdCode = _Field(32, 'n', 11, false, 'LL');
const _33_ForwardingInstitutionIdCode = _Field(33, 'n', 11, false, 'LL');
const _34_PAN_Extended = _Field(34, 'ns', 28, false, 'LL');
const _35_Track2 = _Field(35, 'z', 37, false, 'LL');
const _36_Track3 = _Field(36, 'z', 104, false, 'LLL');
const _37_RRN = _Field(37, 'an', 12, true, null);
const _38_AuthIdResponse = _Field(38, 'an', 6, true, null);
const _39_ResponseCode = _Field(39, 'an', 2, true, null);
const _40_ServiceRestrictionCode = _Field(40, 'an', 3, true, null);
const _41_CA_TerminalID = _Field(41, 'ans', 8, true, null);
const _42_CA_ID = _Field(42, 'ans', 15, true, null);
const _43_CardAcceptorInfo = _Field(43, 'ans', 40, true, null);
const _44_AddResponseData = _Field(44, 'an', 25, false, 'LL');
const _45_Track1 = _Field(45, 'an', 76, false, 'LL');
const _46_AddData_ISO = _Field(46, 'an', 999, false, 'LLL');
const _47_AddData_National = _Field(47, 'an', 999, false, 'LLL');
const _48_AddData_Private = _Field(48, 'an', 999, false, 'LLL');
const _49_CurrencyCode_Transactoion = _Field(49, 'a|n', 3, true, null);
const _50_CurrencyCode_Settlement = _Field(50, 'a|n', 3, true, null);
const _51_CurrencyCode_Cardholder = _Field(51, 'a|n', 3, true, null);
const _52_PIN = _Field(52, 'b', 8, true, null);
const _53_SecurityControlInfo = _Field(53, 'n', 16, true, null);
const _54_AddAmount = _Field(54, 'an', 120, false, 'LLL');
const _55_ICC = _Field(55, 'ans', 999, false, 'LLL');
const _56_Reserved_ISO = _Field(56, 'ans', 999, false, 'LLL');
const _57_Reserved_National = _Field(57, 'ans', 999, false, 'LLL');
const _58_Reserved_National = _Field(58, 'ans', 999, false, 'LLL');
const _59_Reserved_National = _Field(59, 'ans', 999, false, 'LLL');
const _60_Reserved_National = _Field(60, 'ans', 999, false, 'LLL');
const _61_Reserved_Private = _Field(61, 'ans', 999, false, 'LLL');
const _62_Reserved_Private = _Field(62, 'ans', 999, false, 'LLL');
const _63_Reserved_Private = _Field(63, 'ans', 999, false, 'LLL');
const _64_MAC = _Field(64, 'b', 8, true, null);

final _map = <int, _Field>{
  1: _01_Bitmap,
  2: _02_PAN,
  3: _03_ProcessCode,
  4: _04_AmountTransaction,
  5: _05_AmountSettlement,
  6: _06_AmountCardholder,
  7: _07_TransmissionDataTime,
  8: _08_AmountCardholder_BillingFee,
  9: _09_ConversionRate_Settlement,
  10: _10_ConversionRate_Cardholder,
  11: _11_STAN,
  12: _12_LocalTime,
  13: _13_LocalDate,
  14: _14_ExpirationDate,
  15: _15_SettlementDate,
  16: _16_CurrencyConversionDate,
  17: _17_CaptureDate,
  18: _18_MerchantType,
  19: _19_AcquiringInstitution,
  20: _20_PANExtended,
  21: _21_ForwardingInstitution,
  22: _22_EntryMode,
  23: _23_PANSequence,
  24: _24_NII_FunctionCode,
  25: _25_POS_ConditionCode,
  26: _26_POS_CaptureCode,
  27: _27_AuthIdResponseLength,
  28: _28_Amount_TransactionFee,
  29: _29_Amount_SettlementFee,
  30: _30_Amount_TransactionProcessingFee,
  31: _31_Amount_SettlementProcessingFee,
  32: _32_AcquiringInstitutionIdCode,
  33: _33_ForwardingInstitutionIdCode,
  34: _34_PAN_Extended,
  35: _35_Track2,
  36: _36_Track3,
  37: _37_RRN,
  38: _38_AuthIdResponse,
  39: _39_ResponseCode,
  40: _40_ServiceRestrictionCode,
  41: _41_CA_TerminalID,
  42: _42_CA_ID,
  43: _43_CardAcceptorInfo,
  44: _44_AddResponseData,
  45: _45_Track1,
  46: _46_AddData_ISO,
  47: _47_AddData_National,
  48: _48_AddData_Private,
  49: _49_CurrencyCode_Transactoion,
  50: _50_CurrencyCode_Settlement,
  51: _51_CurrencyCode_Cardholder,
  52: _52_PIN,
  53: _53_SecurityControlInfo,
  54: _54_AddAmount,
  55: _55_ICC,
  56: _56_Reserved_ISO,
  57: _57_Reserved_National,
  58: _58_Reserved_National,
  59: _59_Reserved_National,
  60: _60_Reserved_National,
  61: _61_Reserved_Private,
  62: _62_Reserved_Private,
  63: _63_Reserved_Private,
  64: _64_MAC,
};

_Field _valueOf(int no) {
  return _map[no]!;
}

class _Field {
  final int no;
  final String type;
  final int length;
  final bool fixed;
  final String? format;

  const _Field(this.no, this.type, this.length, this.fixed, this.format);
}

class _MessageParser {
  Uint8List message;
  int offset = 10;

  _MessageParser(this.message);

  /// <summary>
  ///
  /// </summary>
  /// <param name="field"></param>
  /// <returns></returns>
  Uint8List parse(_Field field) {
    if (field.fixed) {
      return fixedFieldParser(field);
    } else {
      return varFieldParser(field);
    }
  }

  /// <summary>
  /// Fixed length field parser
  /// </summary>
  /// <param name="field"></param>
  /// <returns></returns>
  /// <exception cref="NotImplementedException"></exception>
  Uint8List fixedFieldParser(_Field field) {
    final fieldType = field.type;
    switch (fieldType) {
      case 'n':
        return numericFixedFieldParser(field);
      default:
        return alphaNumericFixedFieldParser(field);
    }
  }

  /// <summary>
  ///
  /// </summary>
  /// <returns></returns>
  Uint8List alphaNumericFixedFieldParser(_Field field) {
    final fieldLength = field.length;
    offset += fieldLength;
    return message.sublist(offset - fieldLength, offset);
  }

  /// <summary>
  ///
  /// </summary>
  /// <returns></returns>
  Uint8List numericFixedFieldParser(_Field field) {
    final fieldLength = field.length;

    var len = fieldLength;
    len = (len / 2).ceil();
    offset += len;
    return message.sublist(offset - len, offset);
  }

  /// <summary>
  /// Variable length field parser
  /// </summary>
  /// <returns></returns>
  /// <exception cref="NotImplementedException"></exception>
  Uint8List varFieldParser(_Field field) {
    final fieldFormat = field.format;

    switch (fieldFormat) {
      case 'LL':
        return varFieldParser2(field, 1);
      case 'LLL':
        return varFieldParser2(field, 2);
    }
    return Uint8List.fromList([]);
  }

  /// <summary>
  /// Variable field parser
  /// </summary>
  /// <param name="formatLength"></param>
  /// <returns></returns>
  Uint8List varFieldParser2(_Field field, int formatLength) {
    final fieldType = field.type;

    int len =
        int.parse(hex.encode(message.sublist(offset, offset + formatLength)));

    if (fieldType == 'z') len ~/= 2;

    offset = offset + formatLength;

    offset += len;

    return message.sublist(offset - len, offset);
  }
}
