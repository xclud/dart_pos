part of '../pos.dart';

final _json = JsonEncoder.withIndent(' ');

/// Mac algorithm for 6th bit.
String iso9797MacAlgorithm3String(Uint8List key, Uint8List message) {
  if (message.length % 8 != 0) {
    final copyOfData = message.toList();
    while (copyOfData.length % 8 != 0) {
      copyOfData.add(0);
    }

    message = Uint8List.fromList(copyOfData);
  }

  final mac = iso9797.algorithm3(key, message, iso9797.PaddingMode.method1);
  final macU = mac.map((e) => e.toRadixString(16)).join().toUpperCase();

  final result = macU.codeUnits.take(8).map((e) => e.toRadixString(16)).join();
  return result;
}
