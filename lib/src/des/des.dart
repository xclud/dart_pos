// ignore_for_file: public_member_api_docs

part of '../../pos.dart';

class _DESEngine extends _BaseEngine {
  _DESEngine(bool forEncryption, List<int> key)
      : super(
          forEncryption,
          key,
        );

  List<List<int?>> _subKeys = [];
  late int _lBlock;
  late int _rBlock;

  String get algorithmName => 'DES';

  int get blockSize => 64 ~/ 32;

  void init() {
    // Select 56 bits according to PC1
    var keyBits = List<int>.generate(56, (_) => 0);
    for (var i = 0; i < 56; i++) {
      var keyBitPos = PC1[i] - 1;
      keyBits[i] = (rightShift32(
              key[rightShift32(keyBitPos, 5)], (31 - keyBitPos % 32))) &
          1;
    }

    // Assemble 16 subkeys
    var subKeys = _subKeys = List<List<int>>.generate(16, (_) => []);
    for (var nSubKey = 0; nSubKey < 16; nSubKey++) {
      // Create subkey
      var subKey = subKeys[nSubKey] = List<int>.generate(24, (_) => 0);

      // Shortcut
      var bitShift = BIT_SHIFTS[nSubKey];

      // Select 48 bits according to PC2
      for (var i = 0; i < 24; i++) {
        // Select from the left 28 key bits
        subKey[(i ~/ 6) | 0] = subKey[(i ~/ 6) | 0] |
            leftShift32(keyBits[((PC2[i] - 1) + bitShift) % 28], (31 - i % 6));

        // Select from the right 28 key bits
        subKey[4 + ((i ~/ 6) | 0)] = subKey[4 + ((i ~/ 6) | 0)] |
            leftShift32(keyBits[28 + (((PC2[i + 24] - 1) + bitShift) % 28)],
                (31 - i % 6));
      }

      // Since each subkey is applied to an expanded 32-bit input,
      // the subkey can be broken into 8 values scaled to 32-bits,
      // which allows the key to be used without expansion
      subKey[0] = (subKey[0] << 1).toSigned(32) | rightShift32(subKey[0], 31);
      for (var i = 1; i < 7; i++) {
        subKey[i] = rightShift32(subKey[i], ((i - 1) * 4 + 3));
      }
      subKey[7] = (subKey[7] << 5).toSigned(32) | (rightShift32(subKey[7], 27));
    }
  }

  @override
  int processBlock(List<int?> M, int offset) {
    List<List<int?>> invSubKeys = List.generate(16, (_) => []);
    if (!forEncryption) {
      for (var i = 0; i < 16; i++) {
        invSubKeys[i] = _subKeys[15 - i];
      }
    }

    List<List<int?>> subKeys = forEncryption ? _subKeys : invSubKeys;

    _lBlock = M[offset]!.toSigned(32);
    _rBlock = M[offset + 1]!.toSigned(32);
    // Initial permutation
    exchangeLR(4, 0x0f0f0f0f);
    exchangeLR(16, 0x0000ffff);
    exchangeRL(2, 0x33333333);
    exchangeRL(8, 0x00ff00ff);
    exchangeLR(1, 0x55555555);

    // Rounds
    for (var round = 0; round < 16; round++) {
      // Shortcuts
      var subKey = subKeys[round];
      var lBlock = _lBlock;
      var rBlock = _rBlock;

      // Feistel function
      var f = 0.toSigned(32);
      for (var i = 0; i < 8; i++) {
        (f |= (SBOX_P[i][((rBlock ^ subKey[i]!).toSigned(32) & SBOX_MASK[i])
                    .toUnsigned(32)])!
                .toSigned(32))
            .toSigned(32);
      }
      _lBlock = rBlock.toSigned(32);
      _rBlock = (lBlock ^ f).toSigned(32);
    }

    // Undo swap from last round
    var t = _lBlock;
    _lBlock = _rBlock;
    _rBlock = t;

    // Final permutation
    exchangeLR(1, 0x55555555);
    exchangeRL(8, 0x00ff00ff);
    exchangeRL(2, 0x33333333);
    exchangeLR(16, 0x0000ffff);
    exchangeLR(4, 0x0f0f0f0f);

    // Set output
    M[offset] = _lBlock;
    M[offset + 1] = _rBlock;
    return blockSize;
  }

  @override
  void reset() {
    _subKeys = [];
    _lBlock = 0;
    _rBlock = 0;
  }

  // Swap bits across the left and right words
  void exchangeLR(offset, mask) {
    var t = (((rightShift32(_lBlock, offset)).toSigned(32) ^ _rBlock) & mask)
        .toSigned(32);
    (_rBlock = _rBlock ^ t).toSigned(32);
    _lBlock = _lBlock ^ (t << offset).toSigned(32);
  }

  void exchangeRL(offset, mask) {
    var t = (((rightShift32(_rBlock, offset)).toSigned(32) ^ _lBlock) & mask)
        .toSigned(32);
    (_lBlock = _lBlock ^ t).toSigned(32);
    _rBlock = _rBlock ^ (t << offset).toSigned(32);
  }
}
