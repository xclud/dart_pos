// ignore_for_file: public_member_api_docs

part of '../../pos.dart';

abstract class _Engine {
  List<int> process(List<int?> dataWords);
  void reset();
}

/// BufferedBlockAlgorithm.process()
abstract class _BaseEngine implements _Engine {
  const _BaseEngine(this.forEncryption, this.key);

  final bool forEncryption;
  final List<int> key;

  int processBlock(List<int?> M, int offset);

  @override
  List<int> process(List<int?> dataWords) {
    var blockSize = 2;

    if (forEncryption == true) {
      pkcs7Pad(dataWords.toList(), blockSize);
    }
    var dataSigBytes = dataWords.length;
    var blockSizeBytes = blockSize * 4;
    var minBufferSize = 0;

    // Count blocks ready
    var nBlocksReady = dataSigBytes ~/ blockSizeBytes;

    // Round down to include only full blocks,
    // less the number of blocks that must remain in the buffer
    nBlocksReady = max((nBlocksReady | 0) - minBufferSize, 0);

    // Count words ready
    var nWordsReady = nBlocksReady * blockSize;

    // Count bytes ready
    var nBytesReady = min(nWordsReady * 4, dataSigBytes);

    // Process blocks
    List<int?>? processedWords;
    if (nWordsReady != 0) {
      for (var offset = 0; offset < nWordsReady; offset += blockSize) {
        // Perform concrete-algorithm logic
        processBlock(dataWords, offset);
      }

      // Remove processed words
      processedWords = dataWords.getRange(0, nWordsReady).toList();
      dataWords.removeRange(0, nWordsReady);
    }

    var result = List<int>.generate(nBytesReady, (i) {
      if (i < processedWords!.length) {
        return processedWords[i]!;
      }
      return 0;
    });

    if (forEncryption == false) {
      pkcs7Unpad(result, blockSize);
    }

    return result;
  }
}
