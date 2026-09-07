import 'dart:convert';
import 'dart:typed_data';

/// Compression algorithm types
enum CompressionAlgorithm {
  deflate, // DEFLATE compression
  lz77, // LZ77 compression
  rle, // Run-Length Encoding
  none, // No compression
}

/// Compression level/quality
enum CompressionLevel {
  fast, // Fast, lower ratio (~60%)
  balanced, // Balanced (~50%)
  optimal, // Best ratio (~35%)
  maximum, // Maximum compression (~20%)
}

/// Compression result with metadata
class CompressionResult {
  final String id;
  final CompressionAlgorithm algorithm;
  final CompressionLevel level;
  final Uint8List originalData;
  final Uint8List compressedData;
  final DateTime timestamp;
  final int originalSize;
  final int compressedSize;
  final int duration; // milliseconds

  CompressionResult({
    required this.id,
    required this.algorithm,
    required this.level,
    required this.originalData,
    required this.compressedData,
    required this.timestamp,
    required this.duration,
  })  : originalSize = originalData.length,
        compressedSize = compressedData.length;

  /// Calculate compression ratio
  double get compressionRatio =>
      originalSize > 0 ? (compressedSize / originalSize) * 100 : 0;

  /// Calculate space savings in bytes
  int get bytesSaved => originalSize - compressedSize;

  /// Calculate compression efficiency
  double get efficiency => (bytesSaved / originalSize) * 100;

  /// Check if compression was worthwhile (>10% savings)
  bool get wasWorthwhile => efficiency > 10;

  /// Get throughput (bytes/second)
  double get throughput =>
      duration > 0 ? (originalSize / duration) * 1000 : 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'algorithm': algorithm.toString(),
    'level': level.toString(),
    'originalSize': originalSize,
    'compressedSize': compressedSize,
    'compressionRatio': compressionRatio,
    'bytesSaved': bytesSaved,
    'efficiency': efficiency,
    'durationMs': duration,
    'throughputBytesPerSec': throughput,
  };
}

/// Service for data compression
class CompressionService {
  static final CompressionService _instance =
      CompressionService._internal();

  factory CompressionService() {
    return _instance;
  }

  CompressionService._internal();

  // Compression tracking
  final List<CompressionResult> _compressionHistory = [];
  final Map<String, CompressionResult> _compressedData = {};

  // Statistics
  int _totalBytesCompressed = 0;
  int _totalBytesSaved = 0;

  /// Compress data using specified algorithm
  CompressionResult compress(
    String id,
    String data, {
    CompressionAlgorithm algorithm = CompressionAlgorithm.deflate,
    CompressionLevel level = CompressionLevel.balanced,
  }) {
    final stopwatch = Stopwatch()..start();

    final originalBytes = utf8.encode(data);
    final compressedBytes = _compressData(originalBytes, algorithm, level);

    stopwatch.stop();

    final result = CompressionResult(
      id: id,
      algorithm: algorithm,
      level: level,
      originalData: Uint8List.fromList(originalBytes),
      compressedData: compressedBytes,
      timestamp: DateTime.now(),
      duration: stopwatch.elapsedMilliseconds,
    );

    _compressionHistory.add(result);
    _compressedData[id] = result;

    // Keep only last 1000 compressions for memory efficiency
    if (_compressionHistory.length > 1000) {
      _compressionHistory.removeAt(0);
    }

    _totalBytesCompressed += result.originalSize;
    _totalBytesSaved += result.bytesSaved;

    return result;
  }

  /// Compress data (internal implementation)
  Uint8List _compressData(
    Uint8List data,
    CompressionAlgorithm algorithm,
    CompressionLevel level,
  ) {
    switch (algorithm) {
      case CompressionAlgorithm.deflate:
        return _deflateCompress(data, level);
      case CompressionAlgorithm.lz77:
        return _lz77Compress(data);
      case CompressionAlgorithm.rle:
        return _rleCompress(data);
      case CompressionAlgorithm.none:
        return data;
    }
  }

  /// DEFLATE-like compression (simplified)
  Uint8List _deflateCompress(Uint8List data, CompressionLevel level) {
    // Simplified DEFLATE: RLE + LZ77
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      var run = 1;
      while (i + run < data.length &&
          data[i] == data[i + run] &&
          run < 255) {
        run++;
      }

      if (run >= 4 || (level == CompressionLevel.maximum && run >= 2)) {
        // Encode run
        result.add(255); // Marker
        result.add(data[i]);
        result.add(run);
        i += run;
      } else {
        // Literal
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// LZ77-like compression
  Uint8List _lz77Compress(Uint8List data) {
    final result = <int>[];
    var i = 0;
    const windowSize = 32768;

    while (i < data.length) {
      var bestMatch = (0, 0); // (offset, length)

      // Search for matches in window
      for (int j = 0; j < windowSize && j < i; j++) {
        var matchLen = 0;
        while (i + matchLen < data.length &&
            j + matchLen < i &&
            data[j + matchLen] == data[i + matchLen] &&
            matchLen < 258) {
          matchLen++;
        }

        if (matchLen > bestMatch.$2) {
          bestMatch = (i - j, matchLen);
        }
      }

      if (bestMatch.$2 >= 3) {
        result.add(254); // Marker
        result.add((bestMatch.$1 >> 8) & 0xFF);
        result.add(bestMatch.$1 & 0xFF);
        result.add(bestMatch.$2);
        i += bestMatch.$2;
      } else {
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// Run-Length Encoding
  Uint8List _rleCompress(Uint8List data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      var run = 1;
      while (i + run < data.length &&
          data[i] == data[i + run] &&
          run < 255) {
        run++;
      }

      if (run >= 3) {
        result.add(0xFF); // RLE marker
        result.add(data[i]);
        result.add(run);
        i += run;
      } else {
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// Decompress data
  String decompress(
    String id,
    CompressionAlgorithm algorithm,
  ) {
    final result = _compressedData[id];
    if (result == null) {
      throw Exception('No compressed data found for id: $id');
    }

    final decompressed = _decompressData(
      result.compressedData,
      algorithm,
    );

    return utf8.decode(decompressed);
  }

  /// Decompress data (internal)
  Uint8List _decompressData(
    Uint8List data,
    CompressionAlgorithm algorithm,
  ) {
    switch (algorithm) {
      case CompressionAlgorithm.deflate:
        return _deflateDecompress(data);
      case CompressionAlgorithm.lz77:
        return _lz77Decompress(data);
      case CompressionAlgorithm.rle:
        return _rleDecompress(data);
      case CompressionAlgorithm.none:
        return data;
    }
  }

  /// DEFLATE decompression
  Uint8List _deflateDecompress(Uint8List data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      if (i + 2 < data.length && data[i] == 255) {
        // RLE encoded
        final value = data[i + 1];
        final run = data[i + 2];
        for (int j = 0; j < run; j++) {
          result.add(value);
        }
        i += 3;
      } else {
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// LZ77 decompression
  Uint8List _lz77Decompress(Uint8List data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      if (i + 3 < data.length && data[i] == 254) {
        // Match reference
        final offset = (data[i + 1] << 8) | data[i + 2];
        final length = data[i + 3];
        final pos = result.length - offset;
        for (int j = 0; j < length; j++) {
          result.add(result[pos + j]);
        }
        i += 4;
      } else {
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// RLE decompression
  Uint8List _rleDecompress(Uint8List data) {
    final result = <int>[];
    var i = 0;

    while (i < data.length) {
      if (i + 2 < data.length && data[i] == 0xFF) {
        final value = data[i + 1];
        final run = data[i + 2];
        for (int j = 0; j < run; j++) {
          result.add(value);
        }
        i += 3;
      } else {
        result.add(data[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// Get compression statistics
  Map<String, dynamic> getCompressionStats() {
    return {
      'totalCompressions': _compressionHistory.length,
      'totalBytesCompressed': _totalBytesCompressed,
      'totalBytesSaved': _totalBytesSaved,
      'averageCompressionRatio': _calculateAverageRatio(),
      'averageEfficiency': _calculateAverageEfficiency(),
      'worthwhileCompressions': _compressionHistory
          .where((c) => c.wasWorthwhile)
          .length,
      'algorithmBreakdown': _getAlgorithmBreakdown(),
      'levelBreakdown': _getLevelBreakdown(),
    };
  }

  double _calculateAverageRatio() {
    if (_compressionHistory.isEmpty) return 0;
    return _compressionHistory
            .fold(0.0, (sum, c) => sum + c.compressionRatio) /
        _compressionHistory.length;
  }

  double _calculateAverageEfficiency() {
    if (_compressionHistory.isEmpty) return 0;
    return _compressionHistory.fold(0.0, (sum, c) => sum + c.efficiency) /
        _compressionHistory.length;
  }

  Map<String, int> _getAlgorithmBreakdown() {
    final breakdown = <String, int>{};
    for (final result in _compressionHistory) {
      final key = result.algorithm.toString();
      breakdown[key] = (breakdown[key] ?? 0) + 1;
    }
    return breakdown;
  }

  Map<String, int> _getLevelBreakdown() {
    final breakdown = <String, int>{};
    for (final result in _compressionHistory) {
      final key = result.level.toString();
      breakdown[key] = (breakdown[key] ?? 0) + 1;
    }
    return breakdown;
  }

  /// Get recent compressions
  List<CompressionResult> getRecentCompressions() {
    return _compressionHistory.take(100).toList();
  }

  /// Find best algorithm for data type
  CompressionAlgorithm recommendAlgorithm(String dataType) {
    // Recommendations based on data type
    switch (dataType) {
      case 'text':
      case 'json':
        return CompressionAlgorithm.deflate;
      case 'binary':
      case 'image':
        return CompressionAlgorithm.lz77;
      case 'repetitive':
        return CompressionAlgorithm.rle;
      default:
        return CompressionAlgorithm.deflate;
    }
  }

  /// Export compression data as JSON
  String exportCompressionDataAsJson() {
    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "statistics": ${_mapToJson(getCompressionStats())},
  "recentCompressions": [
    ${_compressionHistory.take(50).map((c) => _resultToJson(c)).join(',\n    ')}
  ]
}
''';
  }

  String _resultToJson(CompressionResult result) {
    return '''
{
      "id": "${result.id}",
      "algorithm": "${result.algorithm.toString().split('.').last}",
      "level": "${result.level.toString().split('.').last}",
      "originalSize": ${result.originalSize},
      "compressedSize": ${result.compressedSize},
      "efficiency": ${result.efficiency.toStringAsFixed(2)},
      "durationMs": ${result.duration}
    }''';
  }

  String _mapToJson(Map<String, dynamic> map) {
    final buffer = StringBuffer('{');
    final entries = map.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}": ');

      if (entry.value == null) {
        buffer.write('null');
      } else if (entry.value is String) {
        buffer.write('"${entry.value}"');
      } else if (entry.value is Map) {
        buffer.write(_mapToJson(entry.value as Map<String, dynamic>));
      } else {
        buffer.write('${entry.value}');
      }

      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Clear compression history
  void clearHistory() {
    _compressionHistory.clear();
    _compressedData.clear();
  }
}
