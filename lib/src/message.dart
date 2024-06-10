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
    x.setTime(12, now);
    x.setDate(13, now);
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

    x.setTime(12, now);
    x.setDate(13, now);
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

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);
    x.set(41, terminalId.codeUnits);

    return x;
  }

  /// Creates a nack [Message] with Processig Code of 00 00 05.
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

  /// Creates an eot [Message] with Processig Code of 00 00 07.
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

  /// Creates a dispose [Message] with Processig Code of 00 00 01.
  factory Message.dispose({DateTime? dateTime}) {
    final x = Message('0300');
    final now = dateTime ?? DateTime.now().toLocal();

    x.set(3, [0x00, 0x00, 0x01]);

    x.setTime(12, now);
    x.setDate(13, now);
    x.set(25, [0x14]);

    return x;
  }

  /// Message Type Indicator.
  final String mti;
  final _data = <int, Uint8List>{};

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
  void setDate(int field, DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');

    final h = '$mm$dd';
    final x = hex.decode(h);

    _data[field] = Uint8List.fromList(x);
  }

  /// Sets a data element with index for a Time field.
  void setTime(int field, DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');

    final h = '$hh$mm$ss';
    final x = hex.decode(h);

    _data[field] = Uint8List.fromList(x);
  }

  /// Gets the pos device terminal id (field 41).
  String? get terminalId {
    final f = get(41);
    if (f == null) return null;

    return String.fromCharCodes(f);
  }

  /// Gets a data element for index.
  Uint8List? get(int field) {
    return _data[field];
  }

  /// Unset a data element for index.
  void unset(int field) {
    _data.remove(field);
  }

  /// Encodes a [Message] object to a [Uint8List]. Optionally adds MAC to the field 64.
  Uint8List encode({Uint8List Function(List<int> message)? algorithm}) {
    if (algorithm != null) {
      final y = mac(algorithm);
      set(64, y);
    }

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

  /// Calculates the MAC for current [Message].
  Uint8List mac(Uint8List Function(List<int> message) algorithm) {
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
