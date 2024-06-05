part of '../pos.dart';

/// Calculates MAC (Message Authentication Code) for 64th field.
Uint8List calculateMac(List<int> key, List<int> data) {
  if (data.length % 8 != 0) {
    final copyOfData = data.toList();
    while (copyOfData.length % 8 != 0) {
      copyOfData.add(0);
    }

    data = Uint8List.fromList(copyOfData);
  }

  final des = DES(
    key: key,
    mode: DESMode.CBC,
    paddingType: DESPaddingType.None,
  );

  final x = des.encrypt(data);

  return Uint8List.fromList(x);
}
