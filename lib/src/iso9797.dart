part of '../pos.dart';

// Defines ISO/IEC 9797-1 MAC algorithm 3 and padding method 2.

// First possible Alg3 MAC key len is 16 bytes.
const int _macAlg3Key1Len = 16;
// Second possible Alg3 MAC key len is 16 bytes.
const int _macAlg3Key2Len = 24;

/// Function returns CMAC result according to ISO9797-1 Algorithm 3 scheme
/// using DES encryption algorithm.
///
/// The size of [key] should be 16 or 24 bytes.
/// The [message] if [padMessage] is set to false should be padded to the nearest multiple of 8.
/// When [padMessage] is true, the [message] is padded according to the ISO/IEC 9797-1, padding method 2.
///
Uint8List iso9797MacAlgorithm3(
  Uint8List key,
  Uint8List message, {
  bool padMessage = true,
}) {
  if (key.length != _macAlg3Key1Len && key.length != _macAlg3Key2Len) {
    throw ArgumentError.value(key, 'key length must be 16 or 24');
  }

  final ka = key.sublist(0, 8);
  final kb = key.sublist(8, 16);
  final kc = key.length == _macAlg3Key1Len ? ka : key.sublist(16, 24);

  final cipher = _DESCipher(key: ka, iv: Uint8List(_blockSize));
  var mac = cipher.encrypt(message, padData: padMessage);
  mac = mac.sublist(mac.length - _blockSize);

  cipher.key = kb;
  mac = cipher.decryptBlock(mac);

  cipher.key = kc;
  mac = cipher.encryptBlock(mac);

  return mac;
}

/// Mac algorithm for 6th bit.
String iso9797MacAlgorithm3String(Uint8List key, Uint8List message) {
  if (message.length % 8 != 0) {
    final copyOfData = message.toList();
    while (copyOfData.length % 8 != 0) {
      copyOfData.add(0);
    }

    message = Uint8List.fromList(copyOfData);
  }

  final mac = iso9797MacAlgorithm3(key, message, padMessage: false);
  final macU = mac.map((e) => e.toRadixString(16)).join().toUpperCase();

  final result = macU.codeUnits.take(8).map((e) => e.toRadixString(16)).join();
  return result;
}

/// Returns padded data according to ISO/IEC 9797-1, padding method 2 scheme.
Uint8List iso9797Pad(Uint8List data, int n) {
  final Uint8List padBlock = Uint8List(n);
  padBlock[0] = 0x80;
  final padSize = n - (data.length % n);
  final padded = Uint8List.fromList(data + padBlock.sublist(0, padSize));
  return padded;
}

/// Returns unpadded data according to ISO/IEC 9797-1, padding method 2 scheme.
Uint8List iso9797Unpad(Uint8List data) {
  var i = data.length - 1;
  while (data[i] == 0x00) {
    i -= 1;
  }
  if (data[i] == 0x80) {
    return data.sublist(0, i);
  }
  return data;
}
