part of '../pos.dart';

class _MessageParser {
  _MessageParser(this.message);

  Uint8List message;
  int offset = 10;

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
