part of '../pos.dart';

/// Data Element (DE) for field 48 used for Private Additional data in all original specifications from 1987, 1993 and 2003 years.
class DataElement {
  /// Constructor.
  const DataElement({
    this.serialNumber,
    //this.protocolVersion,
    this.appVersion,
    this.language,
    this.connectionType,
  });

  // Version of the protocol specifications.
  //final String? protocolVersion;

  /// Serial number of a component.
  final String? serialNumber;

  /// App version.
  final String? appVersion;

  /// Connection type.
  final int? connectionType;

  /// Language
  final int? language;

  /// Encode data.
  List<int> encode() {
    final buffer = <int>[];

    final s = serialNumber;

    if (s != null) {
      final sub = [0x01, ...s.codeUnits];

      buffer.addAll(_decimalAsHexBytes(sub.length, 2));
      buffer.addAll(sub);
    }

    final v = appVersion;
    if (v != null) {
      final sub = [0x02, ...v.codeUnits];

      buffer.addAll(_decimalAsHexBytes(sub.length, 2));
      buffer.addAll(sub);
    }

    final l = language;
    if (l != null) {
      final sub = [0x03, l];
      buffer.addAll(_decimalAsHexBytes(sub.length, 2));
      buffer.addAll(sub);
    }

    final c = connectionType;
    if (c != null) {
      final sub = [0x15, c];

      buffer.addAll(_decimalAsHexBytes(sub.length, 2));
      buffer.addAll(sub);
    }

    buffer.insertAll(0, _decimalAsHexBytes(buffer.length, 4));

    return buffer;
  }

  /// Converts this object into JSON.
  Map<String, Object> toJson() {
    final m = <String, Object>{};

    return m;
  }
}
