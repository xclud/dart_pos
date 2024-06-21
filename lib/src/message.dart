part of '../pos.dart';

/// ISO-8583 Message.
class Message {
  /// Main constructor.
  Message(this.mti);

  /// Parses a [Message] from the input byte-array.
  factory Message.parse(String data) {
    final mti = data.substring(0, 4);
    final bitmap = data.substring(4, 20);
    final v = int.parse(bitmap, radix: 16);
    final pb = v.toRadixString(2).padLeft(64, '0');
    final message = Message(mti);
    data = data.substring(20);

    int? month;
    int? day;
    int? hour;
    int? minute;
    int? second;

    for (int i = 1; i < 64; i++) {
      int o = i + 1;
      if (pb[i] != '1') {
        continue;
      }

      if (o == 2) {
        final len = _readLength2(data);
        data = data.substring(2);

        message.pan = data.substring(0, len);
        data = data.substring(len);
      } else if (o == 3) {
        final processCode = data.substring(0, 6);
        data = data.substring(6);

        message.processCode = int.parse(processCode, radix: 16);
      } else if (o == 4) {
        final amountString = data.substring(0, 12);
        data = data.substring(12);

        final amount = int.parse(amountString);

        message.amount = amount;
      } else if (o == 11) {
        final stanString = data.substring(0, 6);
        data = data.substring(6);

        final stan = int.parse(stanString);

        message.stan = stan;
      } else if (o == 12) {
        final timeString = data.substring(0, 6);
        data = data.substring(6);

        final hh = timeString.substring(0, 2);
        final mm = timeString.substring(2, 4);
        final ss = timeString.substring(4, 6);

        hour = int.parse(hh);
        minute = int.parse(mm);
        second = int.parse(ss);
      } else if (o == 13) {
        final dateString = data.substring(0, 4);
        data = data.substring(4);

        final mm = dateString.substring(0, 2);
        final dd = dateString.substring(2, 4);

        month = int.parse(mm);
        day = int.parse(dd);
      } else if (o == 24) {
        final niiString = data.substring(0, 4);
        data = data.substring(4);

        final nii = int.parse(niiString, radix: 16);

        message.nii = nii;
      } else if (o == 37) {
        final rrnString = data.substring(0, 24);
        data = data.substring(24);
        final rrn = String.fromCharCodes(hex.decode(rrnString));

        message.rrn = rrn;
      } else if (o == 38) {
        final irnString = data.substring(0, 12);
        data = data.substring(12);
        final identificationReferenceNumber =
            String.fromCharCodes(hex.decode(irnString));

        message.identificationReferenceNumber = identificationReferenceNumber;
      } else if (o == 39) {
        final rcString = data.substring(0, 4);
        data = data.substring(4);

        final responseCode = String.fromCharCodes(hex.decode(rcString));

        message.responseCode = responseCode;
      } else if (o == 41) {
        final terminalString = data.substring(0, 16);
        data = data.substring(16);

        message.terminalId = terminalString;
      } else if (o == 48) {
        final len = _readLength4Hex(data) * 2;
        data = data.substring(4);

        final f48 = data.substring(0, len);
        data = data.substring(len);

        message._f48DataElement = hex.decode(f48);
      } else if (o == 49) {
        final currencyCodeString = data.substring(0, 6);
        data = data.substring(6);

        final currencyCode =
            int.parse(String.fromCharCodes(hex.decode(currencyCodeString)));
        message.currency = currencyCode;
      } else if (o == 64) {
        final macString = data.substring(0, 16);
        data = data.substring(16);

        message.mac = Uint8List.fromList(hex.decode(macString));
      }
    }

    if (month != null &&
        day != null &&
        hour != null &&
        minute != null &&
        second != null) {
      message.dateTime = DateTime(2024, month, day, hour, minute, second);
    }

    return message;
  }

  /// Message Type Indicator.
  final String mti;
  final _bmp = <int, bool>{};

  /// Clones the message into a new instance.
  Message clone() {
    final copy = Message(mti);

    final f52PinBlock = _f52PinBlock;

    copy._f02Pan = _f02Pan;
    copy._f03ProcessCode = _f03ProcessCode;
    copy._f04Amount = _f04Amount;
    copy._f11Stan = _f11Stan;
    copy._f1213DateTime = _f1213DateTime;
    copy._f22CardEntryMode = _f22CardEntryMode;
    copy._f24Nii = _f24Nii;
    copy._f25POSConditionCode = _f25POSConditionCode;
    copy._f35Track2 = _f35Track2;
    copy._f37RRN = _f37RRN;
    copy._f38IdentificationReferenceNumber = _f38IdentificationReferenceNumber;
    copy._f39ResponseCode = _f39ResponseCode;
    copy._f41TerminalId = _f41TerminalId;
    copy._f42MerchantId = _f42MerchantId;
    copy._f48DataElement = _f48DataElement;
    copy._f49Currency = _f49Currency;
    copy._f52PinBlock =
        f52PinBlock == null ? null : Uint8List.fromList(f52PinBlock);
    copy._mac = _mac;

    copy._bmp.addAll(_bmp);

    return copy;
  }

  /// Encodes a [Message] object to a [Uint8List]. Optionally adds MAC to the field 64.
  String encode({Uint8List Function(List<int> message)? algorithm}) {
    final alg = algorithm;
    final fmac = alg != null ? calcmac(alg) : (mac ?? Uint8List(0));

    final bdy = _body();
    final bmp = _bitmap();

    final xx = mti + hex.encode(bmp) + bdy + hex.encode(fmac);
    return xx;
  }

  String? _f02Pan;
  int? _f03ProcessCode;
  int? _f04Amount;
  int? _f11Stan;
  DateTime? _f1213DateTime;
  int? _f22CardEntryMode;
  int? _f24Nii;
  int? _f25POSConditionCode;
  String? _f35Track2;
  String? _f37RRN;
  String? _f38IdentificationReferenceNumber;
  String? _f39ResponseCode;
  String? _f41TerminalId;
  String? _f42MerchantId;
  List<int>? _f48DataElement;
  int? _f49Currency;

  List<int>? _f52PinBlock;
  List<int>? _mac;

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

  /// Amount.
  /// Field 4.
  ///
  /// Must be null or > 0.',
  int? get amount => _f04Amount;
  set amount(int? value) {
    final v = value;

    assert(
      v == null || v >= 0,
      'Amount should be null or >= 0.',
    );

    if (v == null) {
      _bmp[4] = false;
      _f04Amount = null;
    } else {
      _bmp[4] = true;
      _f04Amount = value;
    }
  }

  /// Systems trace audit number.
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
      'CardEntryMode should be null or between [0x0000, 0xFFFF].',
    );

    if (v == null) {
      _bmp[22] = false;
      _f22CardEntryMode = null;
    } else {
      _bmp[22] = true;
      _f22CardEntryMode = value;
    }
  }

  /// Network International Identifier (NII).
  /// Field 24.
  ///
  /// Must be betweem [0x0000, 0x0FFF] characters.
  int? get nii => _f24Nii;
  set nii(int? value) {
    final v = value;

    assert(
      v == null || v > -1 || v < 0x0fff,
      'NII should be null or between [0x0000, 0xFFFF].',
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

  /// RRN.
  /// Field 37.
  String? get rrn => _f37RRN;
  set rrn(String? value) {
    final v = value;

    if (v == null) {
      _bmp[37] = false;
      _f37RRN = null;
    } else {
      _bmp[37] = true;
      _f37RRN = value;
    }
  }

  /// Identification Reference Number.
  /// Field 38.
  String? get identificationReferenceNumber =>
      _f38IdentificationReferenceNumber;
  set identificationReferenceNumber(String? value) {
    final v = value;

    if (v == null) {
      _bmp[38] = false;
      _f38IdentificationReferenceNumber = null;
    } else {
      _bmp[38] = true;
      _f38IdentificationReferenceNumber = value;
    }
  }

  /// Response Code.
  /// Field 39.
  String? get responseCode => _f39ResponseCode;
  set responseCode(String? value) {
    final v = value;

    if (v == null) {
      _bmp[39] = false;
      _f39ResponseCode = null;
    } else {
      _bmp[39] = true;
      _f39ResponseCode = value;
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
  List<int>? get dataElement => _f48DataElement;
  set dataElement(List<int>? value) {
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
  List<int>? get mac => _mac;
  set mac(List<int>? value) {
    final v = value;

    assert(
      v == null || v.length == 8,
      'MAC should be null or 8 bytes.',
    );

    if (v == null) {
      _bmp[64] = false;
      _mac = null;
    } else {
      _bmp[64] = true;
      _mac = value;
    }
  }

  String _body() {
    final strBits = <String>[];

    for (var i = 1; i < 64; i++) {
      if (i == 2) {
        final p = pan;

        if (p != null) {
          final s2 = '${p.length}$p';
          final trail = p.length.isOdd ? '0' : '';

          strBits.add('$s2$trail');
        }

        continue;
      } else if (i == 3) {
        final p = processCode;

        if (p != null) {
          final bt = ByteData(4);
          bt.setUint32(0, p, Endian.big);

          final f3 = bt.buffer.asUint8List().skip(1).toList();
          final h3 = hex.encode(f3);
          strBits.add(h3);
        }

        continue;
      } else if (i == 4) {
        final p = amount;

        if (p != null) {
          final amountPadded = amount.toString().padLeft(12, '0');

          strBits.add(amountPadded);
        }

        continue;
      } else if (i == 11) {
        final p = stan;

        if (p != null) {
          strBits.add(p.toString());
        }

        continue;
      } else if (i == 12) {
        final p = _f1213DateTime;

        if (p != null) {
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

          strBits.add(s25);
        }

        continue;
      } else if (i == 24) {
        final p = nii;

        if (p != null) {
          final f24 = p.toRadixString(16).padLeft(4, '0');
          strBits.add(f24);
        }

        continue;
      } else if (i == 35) {
        final p = track2;

        if (p != null) {
          final vv = p.padRight(38, '0');

          final s2 = '${vv.length - 1}$vv';
          strBits.add(s2);
        }

        continue;
      } else if (i == 37) {
        final p = rrn;

        if (p != null) {
          strBits.add(p);
        }

        continue;
      } else if (i == 38) {
        final p = identificationReferenceNumber;

        if (p != null) {
          strBits.add(p);
        }

        continue;
      } else if (i == 39) {
        final p = responseCode;

        if (p != null) {
          strBits.add(p);
        }

        continue;
      } else if (i == 41) {
        final p = terminalId;

        if (p != null) {
          final pp = p.padLeft(8, '0');
          strBits.add(hex.encode(pp.codeUnits));
        }

        continue;
      } else if (i == 42) {
        final p = merchantId;

        if (p != null) {
          final pp = p.padRight(15, ' ');
          strBits.add(hex.encode(pp.codeUnits));
        }

        continue;
      } else if (i == 48) {
        final p = dataElement;

        if (p != null) {
          final enc = p;
          strBits.add(hex.encode(enc).toUpperCase());
        }

        continue;
      } else if (i == 49) {
        final p = currency;

        if (p != null) {
          final h = p.toString().codeUnits;
          final hh = hex.encode(h);

          strBits.add(hh);
        }

        continue;
      } else if (i == 52) {
        final p = pinBlock;

        if (p != null) {
          final h = hex.encode(p);

          strBits.add(h);
        }

        continue;
      } else if (i == 64) {
        final p = mac;

        if (p != null) {
          strBits.add(hex.encode(p));
        }

        continue;
      }
    }
    final v = strBits.join();
    return v;
  }

  Uint8List _bitmap() {
    final bits = <String>[];

    for (var i = 1; i <= 64; i++) {
      if (_bmp[i] == true) {
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
    c.mac = Uint8List(8);
    final bmp = c._bitmap();
    c.mac = null;

    final List<Uint8List> v = [];

    v.add(Uint8List.fromList(hex.decode(c.mti)));
    v.add(bmp);
    //v.add(c._body());

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
    final mAmount = amount;
    final mStan = stan;
    final mDateTime = dateTime;
    final mCardEntryMode = cardEntryMode;
    final mNii = nii;
    final mPosConditionCode = posConditionCode;
    final mTrack2 = track2;
    final mRrn = rrn;
    final mIdentificationReferenceNumber = identificationReferenceNumber;
    final mResponseCode = responseCode;
    final mTerminalId = terminalId;
    final mMerchantId = merchantId;
    final mCurrency = currency;
    final mDataElement = dataElement;
    final mPinBlock = pinBlock;
    final mMac = mac;

    if (mPan != null) {
      map['pan'] = mPan;
    }

    if (mProcessCode != null) {
      map['processCode'] = mProcessCode;
    }

    if (mAmount != null) {
      map['amount'] = mAmount;
    }

    if (mStan != null) {
      map['stan'] = mStan;
    }

    if (mDateTime != null) {
      map['dateTime'] = mDateTime.toIso8601String();
    }

    if (mCardEntryMode != null) {
      map['cardEntryMode'] = mCardEntryMode;
    }

    if (mNii != null) {
      map['nii'] = mNii;
    }

    if (mPosConditionCode != null) {
      map['posConditionCode'] = mPosConditionCode;
    }

    if (mTrack2 != null) {
      map['track2'] = mTrack2;
    }

    if (mRrn != null) {
      map['rrn'] = mRrn;
    }

    if (mIdentificationReferenceNumber != null) {
      map['identificationReferenceNumber'] = mIdentificationReferenceNumber;
    }

    if (mResponseCode != null) {
      map['responseCode'] = mResponseCode;
    }

    if (mTerminalId != null) {
      map['terminalId'] = mTerminalId;
    }

    if (mMerchantId != null) {
      map['merchantId'] = mMerchantId;
    }

    if (mDataElement != null) {
      map['dataElement'] = '0x${hex.encode(mDataElement).toUpperCase()}';
    }

    if (mCurrency != null) {
      map['currency'] = mCurrency;
    }

    if (mPinBlock != null) {
      map['pinBlock'] = '0x${hex.encode(mPinBlock).toUpperCase()}';
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

int _readLength2(String data) {
  final sub = data.substring(0, 2);
  final v = int.parse(sub);

  return v;
}

int _readLength4Hex(String data) {
  final sub = data.substring(0, 4);
  final v = int.parse(sub);

  return v;
}
