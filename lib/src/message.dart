part of '../pos.dart';

/// ISO-8583 Message.
class Message {
  /// Main constructor.
  Message(this.mti);

  /// Parses a [Message] from the input byte-array.
  factory Message.parse(Uint8List data) {
    final mti = hex.encode(data.take(2).toList()).toUpperCase();

    final bitmap = data.sublist(2, 10);
    final hexmap = hex.encode(bitmap);
    final v = int.parse(hexmap, radix: 16);
    final pb = v.toRadixString(2).padLeft(64, '0');
    final message = Message(mti);

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

  /// Creates a connection-test [Message] with Processig Code of 41 00 00.
  factory Message.conntectionTest({DateTime? dateTime}) {
    final now = dateTime ?? DateTime.now().toLocal();

    final x = Message('0300');
    //x.set(1, '0300');
    x.processCode = 0x410000;
    x.dateTime = now;

    x.posConditionCode = 0x14;
    x.currency = 364;

    return x;
  }

  /// Creates a purchase [Message] with Processig Code of 00 00 00.
  factory Message.purchase({required int amount, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    final am = amount.toString().padLeft(12, '0');
    final amb = hex.decode(am);

    x.processCode = 0x000000;
    x.set(4, amb);
    x.dateTime = now;

    x.posConditionCode = 0x14;
    x.set(46, [0x33, 0x30, 0x30]); // '300' in ASCII.
    x.set(48, '200003123001a11003456001c'.codeUnits);
    x.currency = 364;
    x.set(57, '1.4.8.2'.codeUnits);

    return x;
  }

  /// Creates an ack [Message] with Processig Code of 00 00 04.
  factory Message.ack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.processCode = 0x000004;
    x.dateTime = now;

    x.posConditionCode = 0x14;
    x.terminalId = terminalId;

    return x;
  }

  /// Creates a nack [Message] with Processig Code of 00 00 05.
  factory Message.nack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.processCode = 0x000005;
    x.dateTime = now;

    x.posConditionCode = 0x14;
    x.terminalId = terminalId;

    return x;
  }

  /// Creates an eot [Message] with Processig Code of 00 00 07.
  factory Message.eot({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.processCode = 0x000007;
    x.dateTime = now;

    x.set(39, [0x17]);
    x.terminalId = terminalId;

    return x;
  }

  /// Creates a dispose [Message] with Processig Code of 00 00 01.
  factory Message.dispose({DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.processCode = 0x000001;
    x.dateTime = now;

    x.posConditionCode = 0x14;

    return x;
  }

  /// Message Type Indicator.
  final String mti;
  final _data = <int, List<int>>{};
  final _bmp = <int, bool>{};

  /// Clones the message into a new instance.
  Message clone() {
    final copy = Message(mti);
    copy._data.addAll(_data);

    return copy;
  }

  /// Sets a data element with index.
  @Deprecated('Please use the specific property for the field number')
  void set(int field, List<int> value) {
    _data[field] = Uint8List.fromList(value);
  }

  /// Sets a data element with index for a Date field.
  Uint8List _setDate(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');

    final h = '$mm$dd';
    final x = hex.decode(h);

    return Uint8List.fromList(x);
  }

  /// Sets a data element with index for a Time field.
  Uint8List _setTime(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');

    final h = '$hh$mm$ss';
    final x = hex.decode(h);

    return Uint8List.fromList(x);
  }

  /// Gets a data element for index.
  @Deprecated('Please use the specific property for the field number')
  List<int>? get(int field) {
    return _data[field];
  }

  /// Unset a data element for index.
  @Deprecated('Please use the specific property for the field number')
  void unset(int field) {
    _data.remove(field);
  }

  /// Encodes a [Message] object to a [Uint8List]. Optionally adds MAC to the field 64.
  Uint8List encode({Uint8List Function(List<int> message)? algorithm}) {
    if (algorithm != null) {
      final y = calcmac(algorithm);

      mac = hex.encode(y).toUpperCase();
    }

    final bdy = _body();
    final bmp = _bitmap();
    final mt = Uint8List.fromList(hex.decode(mti));

    final xx = mt + bmp + bdy;
    return Uint8List.fromList(xx);
  }

  String? _f02Pan;
  int? _f03ProcessCode;
  int? _f11Stan;
  DateTime? _f1213DateTime;
  int? _f22CardEntryMode;
  String? _f24Nii;
  int? _f25POSConditionCode;
  String? _f35Track2;
  String? _f41TerminalId;
  String? _f42MerchantId;
  DataElement? _f48DataElement;
  int? _f49Currency;

  List<int>? _f52PinBlock;
  String? _mac;

  /// PAN, the Card Number.
  /// Field 2.
  ///
  /// Must be 16 or 19 characters.
  String? get pan => _f02Pan;
  set pan(String? value) {
    final v = value;

    assert(
      v == null || v.length == 16 || v.length == 19,
      'PAN should be null, or 16 or 19 characters long.',
    );

    if (v == null) {
      _bmp[2] = false;
      _f02Pan = null;
    } else {
      _bmp[2] = true;
      _f02Pan = value;
    }
  }

  /// Process Code.
  /// Field 3.
  ///
  /// Must be 6 characters.
  int? get processCode => _f03ProcessCode;
  set processCode(int? value) {
    final v = value;

    assert(
      v == null || v < 0xffffff,
      'Process Code should be null or <= 0xFFFFFF.',
    );

    if (v == null) {
      _bmp[3] = false;
      _f03ProcessCode = null;
    } else {
      _bmp[3] = true;
      _f03ProcessCode = value;
    }
  }

  /// Stan.
  /// Field 11.
  ///
  /// Must be in (1,9999) range.
  int? get stan => _f11Stan;
  set stan(int? value) {
    final v = value;

    assert(
      v == null || v > 0 || v < 9999,
      'Stan should be in [1,9999] range.',
    );

    if (v == null) {
      _bmp[11] = false;
      _f11Stan = null;
    } else {
      _bmp[11] = true;
      _f11Stan = value;
    }
  }

  /// Date & Time.
  /// Field 12 & 13.
  ///
  DateTime? get dateTime => _f1213DateTime;
  set dateTime(DateTime? value) {
    final v = value;

    if (v == null) {
      _bmp[12] = false;
      _bmp[13] = false;

      _f1213DateTime = null;
    } else {
      _bmp[12] = true;
      _bmp[13] = true;

      _f1213DateTime = value;
    }
  }

  /// Card Entry Mode.
  /// Field 22.
  int? get cardEntryMode => _f22CardEntryMode;
  set cardEntryMode(int? value) {
    final v = value;

    assert(
      v == null || v > -1 || v < 0xffff,
      'CardEntryMode should be null or between [0x00, 0xFFFF].',
    );

    if (v == null) {
      _bmp[22] = false;
      _f22CardEntryMode = null;
    } else {
      _bmp[22] = true;
      _f22CardEntryMode = value;
    }
  }

  /// NII.
  /// Field 24.
  ///
  /// Must be 4 characters.
  String? get nii => _f24Nii;
  set nii(String? value) {
    final v = value;

    assert(
      v == null || v.length == 4,
      'NII should be null or 4 characters long.',
    );

    if (v == null) {
      _bmp[24] = false;
      _f24Nii = null;
    } else {
      _bmp[24] = true;
      _f24Nii = value;
    }
  }

  /// POS Condition Code.
  /// Field 25.
  int? get posConditionCode => _f25POSConditionCode;
  set posConditionCode(int? value) {
    final v = value;

    assert(
      v == null || v > -1 || v < 0xff,
      'PosConditionCode should be null or between [0x00, 0xFF].',
    );

    if (v == null) {
      _bmp[25] = false;
      _f25POSConditionCode = null;
    } else {
      _bmp[25] = true;
      _f25POSConditionCode = value;
    }
  }

  /// Track 2.
  /// Field 35.
  ///
  /// Must be 38 characters right padded with '0'.
  String? get track2 => _f35Track2;
  set track2(String? value) {
    final v = value;

    assert(
      v == null || v.length < 39,
      'Track2 must be 38 characers max.',
    );

    if (v == null) {
      _bmp[35] = false;
      _f35Track2 = null;
    } else {
      _bmp[35] = true;
      _f35Track2 = value;
    }
  }

  /// Terminal Id.
  /// Field 41.
  String? get terminalId => _f41TerminalId;
  set terminalId(String? value) {
    final v = value;

    if (v == null) {
      _bmp[41] = false;
      _f41TerminalId = null;
    } else {
      _bmp[41] = true;
      _f41TerminalId = value;
    }
  }

  /// Merchant Id.
  /// Field 42.
  String? get merchantId => _f42MerchantId;
  set merchantId(String? value) {
    final v = value;

    if (v == null) {
      _bmp[42] = false;
      _f42MerchantId = null;
    } else {
      _bmp[42] = true;
      _f42MerchantId = value;
    }
  }

  /// Currency.
  /// Field 48.
  DataElement? get dataElement => _f48DataElement;
  set dataElement(DataElement? value) {
    final v = value;

    if (v == null) {
      _bmp[48] = false;
      _f48DataElement = null;
    } else {
      _bmp[48] = true;
      _f48DataElement = value;
    }
  }

  /// Currency.
  /// Field 49.
  int? get currency => _f49Currency;
  set currency(int? value) {
    final v = value;

    if (v == null) {
      _bmp[49] = false;
      _f49Currency = null;
    } else {
      _bmp[49] = true;
      _f49Currency = value;
    }
  }

  /// Pin Block.
  /// Field 52.
  List<int>? get pinBlock => _f52PinBlock;
  set pinBlock(List<int>? value) {
    final v = value;

    assert(
      v == null || v.length == 8,
      'pinBlock must be null or 8 bytes.',
    );

    if (v == null) {
      _bmp[52] = false;
      _f52PinBlock = null;
    } else {
      _bmp[52] = true;
      _f52PinBlock = value;
    }
  }

  /// MAC.
  /// Field 64 or 128.
  ///
  /// Must be 16 characters.
  String? get mac => _mac;
  set mac(String? value) {
    final v = value;

    assert(
      v == null || v.length == 16,
      'MAC should be null or 16 characters long.',
    );

    if (v == null) {
      _bmp[64] = false;
      _mac = null;
    } else {
      _bmp[64] = true;
      _mac = value;
    }
  }

  Uint8List _body() {
    final bits = <List<int>>[];
    final strBits = <String>[];

    for (var i = 1; i <= 64; i++) {
      if (i == 2) {
        final p = pan;

        if (p != null) {
          final vv = p.length == 19 ? '${p}0' : p;

          final f2 = [..._decimalAsHexBytes(p.length, 2), ...hex.decode(vv)];
          final s2 = '${p.length}$p';

          bits.add(f2);

          strBits.add(s2);
        }

        continue;
      } else if (i == 3) {
        final p = processCode;

        if (p != null) {
          final bt = ByteData(4);
          bt.setUint32(0, p, Endian.big);

          final f3 = bt.buffer.asUint8List().skip(1).toList();
          final h3 = hex.encode(f3);

          bits.add(f3);
          strBits.add(h3);
        }

        continue;
      } else if (i == 11) {
        final p = stan;

        if (p != null) {
          final f2 = hex.decode(p.toString());
          bits.add(f2);

          strBits.add(p.toString());
        }

        continue;
      } else if (i == 12) {
        final p = _f1213DateTime;

        if (p != null) {
          bits.add(_setTime(p));

          final hh = p.hour.toString().padLeft(2, '0');
          final mm = p.minute.toString().padLeft(2, '0');
          final ss = p.second.toString().padLeft(2, '0');

          final h = '$hh$mm$ss';

          strBits.add(h);
        }

        continue;
      } else if (i == 13) {
        final p = _f1213DateTime;

        if (p != null) {
          bits.add(_setDate(p));

          final mm = p.month.toString().padLeft(2, '0');
          final dd = p.day.toString().padLeft(2, '0');

          final h = '$mm$dd';

          strBits.add(h);
        }

        continue;
      } else if (i == 22) {
        final p = cardEntryMode;

        if (p != null) {
          final bt = ByteData(2);
          bt.setUint16(0, p, Endian.big);

          final f22 = bt.buffer.asUint8List();
          final s22 = hex.encode(f22);

          bits.add(f22);
          strBits.add(s22);
        }

        continue;
      } else if (i == 25) {
        final p = posConditionCode;

        if (p != null) {
          final bt = ByteData(1);
          bt.setUint8(0, p);

          final f25 = bt.buffer.asUint8List();
          final s25 = hex.encode(f25);

          bits.add(f25);
          strBits.add(s25);
        }

        continue;
      } else if (i == 24) {
        final p = _f24Nii;

        if (p != null) {
          final f2 = hex.decode(p);
          bits.add(f2);

          strBits.add(p);
        }

        continue;
      } else if (i == 35) {
        final p = track2;

        if (p != null) {
          final vv = p.padRight(38, '0');

          final f35 = [
            ..._decimalAsHexBytes(vv.length - 1, 2),
            ...hex.decode(vv)
          ];
          bits.add(f35);

          final s2 = '${vv.length - 1}$vv';
          strBits.add(s2);
        }

        continue;
      } else if (i == 41) {
        final p = terminalId;

        if (p != null) {
          bits.add(hex.decode(p));
          strBits.add(p);
        }

        continue;
      } else if (i == 42) {
        final p = merchantId;

        if (p != null) {
          bits.add(hex.decode(p));
          strBits.add(p);
        }

        continue;
      } else if (i == 48) {
        final p = dataElement;

        if (p != null) {
          final enc = p._encode();
          bits.add(enc);
          strBits.add(hex.encode(enc).toUpperCase());
        }

        continue;
      } else if (i == 49) {
        final p = currency;

        if (p != null) {
          final h = p.toString().codeUnits;
          final hh = hex.encode(h);

          bits.add(h);
          strBits.add(hh);
        }

        continue;
      } else if (i == 52) {
        final p = pinBlock;

        if (p != null) {
          final h = hex.encode(p);

          bits.add(p);
          strBits.add(h);
        }

        continue;
      } else if (i == 64) {
        final p = mac;

        if (p != null) {
          bits.add(hex.decode(p));
          strBits.add(p);
        }

        continue;
      }

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
      if (_data[i] != null || _bmp[i] == true) {
        bits.add('1');
      } else {
        bits.add('0');
      }
    }
    final v = int.parse(bits.join(), radix: 2);
    return _getBytes(v);
  }

  /// Calculates the MAC for current [Message].
  Uint8List calcmac(Uint8List Function(List<int> message) algorithm) {
    final c = clone();
    c.mac = '0000000000000000';
    final bmp = c._bitmap();
    c.mac = null;

    final List<Uint8List> v = [];

    v.add(Uint8List.fromList(hex.decode(c.mti)));
    v.add(bmp);
    v.add(c._body());

    final vv = v.expand((element) => element).toList();
    final en = algorithm(vv);

    final mc = en.skip((en.length ~/ 8 - 1) * 8).take(8).toList();

    return Uint8List.fromList(mc);
  }

  /// Converts the [Message] object to JSON.
  Map<String, Object> toJson() {
    final map = <String, Object>{};

    map['MTI'] = mti;

    final mPan = pan;
    final mProcessCode = processCode;
    final mStan = stan;
    final mDateTime = dateTime;
    final mCardEntryMode = cardEntryMode;
    final mNii = nii;
    final mPosConditionCode = posConditionCode;
    final mTrack2 = track2;
    final mTerminalId = terminalId;
    final mMerchantId = merchantId;
    final mCurrency = currency;
    final mDataElement = dataElement;
    final mPinBlock = pinBlock;
    final mMac = mac;

    if (mPan != null) {
      map['PAN'] = mPan;
    }

    if (mProcessCode != null) {
      map['ProcessCode'] = mProcessCode;
    }

    if (mStan != null) {
      map['Stan'] = mStan;
    }

    if (mDateTime != null) {
      map['DateTime'] = mDateTime.toIso8601String();
    }

    if (mCardEntryMode != null) {
      map['CardEntryMode'] = mCardEntryMode;
    }

    if (mNii != null) {
      map['NII'] = mNii;
    }

    if (mPosConditionCode != null) {
      map['PosConditionCode'] = mPosConditionCode;
    }

    if (mTrack2 != null) {
      map['Track2'] = mTrack2;
    }

    if (mTerminalId != null) {
      map['TerminalId'] = mTerminalId;
    }

    if (mMerchantId != null) {
      map['MerchantId'] = mMerchantId;
    }

    if (mDataElement != null) {
      map['DataElement'] = mDataElement.toJson();
    }

    if (mCurrency != null) {
      map['Currency'] = mCurrency;
    }

    if (mPinBlock != null) {
      map['PinBlock'] = '0x${hex.encode(mPinBlock).toUpperCase()}';
    }

    for (var i = 1; i < 64; i++) {
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

    if (mMac != null) {
      map['MAC'] = mMac;
    }

    return map;
  }

  @override
  String toString() {
    return _json.convert(toJson());
  }
}

List<int> _decimalAsHexBytes(int v, int l) {
  final y = v.toString().padLeft(l, '0');
  return hex.decode(y);
}
