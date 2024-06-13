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
    x.set(3, [0x41, 0x00, 0x00]);
    x.dateTime = now;

    x.set(25, [0x14]);
    x.set(49, [0x33, 0x36, 0x34]); // '364' in ASCII.

    return x;
  }

  /// Creates a purchase [Message] with Processig Code of 00 00 00.
  factory Message.purchase({required int amount, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    final am = amount.toString().padLeft(12, '0');
    final amb = hex.decode(am);

    x.set(3, [0, 0, 0]);
    x.set(4, amb);
    x.dateTime = now;

    x.set(25, [0x14]);
    x.set(46, [0x33, 0x30, 0x30]); // '300' in ASCII.
    x.set(48, '200003123001a11003456001c'.codeUnits);
    x.set(49, [0x33, 0x36, 0x34]); // '364' in ASCII.
    x.set(57, '1.4.8.2'.codeUnits);

    return x;
  }

  /// Creates an ack [Message] with Processig Code of 00 00 04.
  factory Message.ack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x04]);
    x.dateTime = now;

    x.set(25, [0x14]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  /// Creates a nack [Message] with Processig Code of 00 00 05.
  factory Message.nack({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x05]);
    x.dateTime = now;

    x.set(25, [0x14]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  /// Creates an eot [Message] with Processig Code of 00 00 07.
  factory Message.eot({required String terminalId, DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x07]);

    x.dateTime = now;

    x.set(39, [0x17]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  /// Creates a dispose [Message] with Processig Code of 00 00 01.
  factory Message.dispose({DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x01]);
    x.dateTime = now;

    x.set(25, [0x14]);

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

  /// Gets the pos device terminal id (field 41).
  String? get terminalId {
    final f = get(41);
    if (f == null) return null;

    return String.fromCharCodes(f);
  }

  /// Gets a data element for index.
  List<int>? get(int field) {
    return _data[field];
  }

  /// Unset a data element for index.
  void unset(int field) {
    _data.remove(field);
  }

  /// Encodes a [Message] object to a [Uint8List]. Optionally adds MAC to the field 64.
  Uint8List encode({Uint8List Function(List<int> message)? algorithm}) {
    if (algorithm != null) {
      final y = calcmac(algorithm);
      set(64, y);
    }

    final bdy = _body();
    final bmp = _bitmap();
    final mt = Uint8List.fromList(hex.decode(mti));

    final xx = mt + bmp + bdy;
    return Uint8List.fromList(xx);
  }

  String? _f02Pan;
  String? _f03ProcessCode;
  int? _f11Stan;
  DateTime? _f1213DateTime;
  String? _f24Nii;
  String? _f35Track2;

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
  String? get processCode => _f03ProcessCode;
  set processCode(String? value) {
    final v = value;

    assert(
      v == null || v.length == 6,
      'Process Code should be null or 6 characters long.',
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

  /// MAC.
  /// Field 64 or 128.
  ///
  /// Must be 4 characters.
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
          final f2 = hex.decode(p);
          bits.add(f2);

          strBits.add(p);
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
    c.set(64, List<int>.filled(8, 0));
    final bmp = c._bitmap();
    c.unset(64);

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
    final mNii = nii;
    final mTrack2 = track2;
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

    if (mNii != null) {
      map['NII'] = mNii;
    }

    if (mTrack2 != null) {
      map['Track2'] = mTrack2;
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
