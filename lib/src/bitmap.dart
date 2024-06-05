part of '../pos.dart';

Uint8List _getBytes(int i) {
  final n = ByteData(8);
  n.setUint64(0, i);

  return Uint8List.fromList(n.buffer.asUint8List());
}
