import 'dart:async';

/// Cache entry with metadata
class CacheEntry<T> {
  final String key;
  final T value;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  int accessCount;
  final Duration? ttl;

  CacheEntry({
    required this.key,
    required this.value,
    this.ttl,
  })  : createdAt = DateTime.now(),
        lastAccessedAt = DateTime.now(),
        accessCount = 0;

  /// Check if entry is expired
  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(createdAt) > ttl!;
  }

  /// Get age of entry in milliseconds
  int get ageMs => DateTime.now().difference(createdAt).inMilliseconds;

  /// Get time since last access
  int get timeSinceLastAccessMs =>
      DateTime.now().difference(lastAccessedAt).inMilliseconds;

  /// Update access time and count
  void recordAccess() {
    lastAccessedAt = DateTime.now();
    accessCount++;
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'accessCount': accessCount,
    'ageMs': ageMs,
    'ttl': ttl?.inSeconds,
    'isExpired': isExpired,
  };
}

/// Cache statistics
class CacheStats {
  final int totalItems;
  final int hits;
  final int misses;
  final int evictions;
  final int expirations;
  final DateTime timestamp;

  CacheStats({
    required this.totalItems,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.expirations,
  }) : timestamp = DateTime.now();

  /// Calculate hit rate percentage
  double get hitRate =>
      (hits + misses) > 0 ? (hits / (hits + misses)) * 100 : 0;

  /// Calculate miss rate percentage
  double get missRate => 100 - hitRate;

  Map<String, dynamic> toMap() => {
    'totalItems': totalItems,
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'expirations': expirations,
    'hitRate': hitRate,
    'missRate': missRate,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// LRU (Least Recently Used) Cache implementation
class SmartCacheService {
  static final SmartCacheService _instance =
      SmartCacheService._internal();

  factory SmartCacheService() {
    return _instance;
  }

  SmartCacheService._internal();

  // Cache storage
  final Map<String, CacheEntry<dynamic>> _cache = {};
  final int maxSize;

  // Statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;
  final List<CacheStats> _statsHistory = [];

  // Memory tracking
  int _estimatedMemoryUsage = 0;

  SmartCacheService.withSize(this.maxSize);

  /// Initialize with default size (1000 entries)
  SmartCacheService._internal() : maxSize = 1000;

  /// Get value from cache
  T? get<T>(String key) {
    // Remove expired entries
    _removeExpiredEntries();

    if (!_cache.containsKey(key)) {
      _misses++;
      return null;
    }

    final entry = _cache[key]! as CacheEntry<T>;

    if (entry.isExpired) {
      _cache.remove(key);
      _expirations++;
      _misses++;
      return null;
    }

    entry.recordAccess();
    _hits++;
    return entry.value;
  }

  /// Put value in cache
  void put<T>(
    String key,
    T value, {
    Duration? ttl,
  }) {
    // Check if we need to evict
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      _evictLRU();
    }

    final estimatedSize = _estimateSize(value);
    _cache[key] = CacheEntry(
      key: key,
      value: value,
      ttl: ttl,
    );

    _estimatedMemoryUsage += estimatedSize;
  }

  /// Check if key exists in cache
  bool containsKey(String key) {
    _removeExpiredEntries();
    return _cache.containsKey(key) && !(_cache[key]?.isExpired ?? false);
  }

  /// Remove entry from cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
    _estimatedMemoryUsage = 0;
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  /// Evict least recently used entry
  void _evictLRU() {
    if (_cache.isEmpty) return;

    String? lruKey;
    int? minAccessTime;

    for (final entry in _cache.entries) {
      if (minAccessTime == null ||
          entry.value.timeSinceLastAccessMs > minAccessTime) {
        minAccessTime = entry.value.timeSinceLastAccessMs;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      _evictions++;
    }
  }

  /// Remove all expired entries
  void _removeExpiredEntries() {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
        _expirations++;
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  /// Estimate size of value in bytes
  int _estimateSize(dynamic value) {
    if (value is String) {
      return value.length * 2; // UTF-16
    } else if (value is int) {
      return 8;
    } else if (value is double) {
      return 8;
    } else if (value is bool) {
      return 1;
    } else if (value is List) {
      return value.length * 16; // Estimate per item
    } else if (value is Map) {
      return value.length * 24; // Estimate per entry
    }
    return 100; // Default estimate
  }

  /// Get cache statistics
  CacheStats getStats() {
    return CacheStats(
      totalItems: _cache.length,
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      expirations: _expirations,
    );
  }

  /// Get cache entry metadata
  CacheEntry? getEntryMetadata(String key) {
    return _cache[key];
  }

  /// Get all keys in cache
  List<String> getAllKeys() {
    _removeExpiredEntries();
    return _cache.keys.toList();
  }

  /// Get cache size
  int getSize() => _cache.length;

  /// Get estimated memory usage
  int getEstimatedMemoryUsage() => _estimatedMemoryUsage;

  /// Record statistics snapshot
  void recordStats() {
    _statsHistory.add(getStats());

    // Keep only last 1000 snapshots
    if (_statsHistory.length > 1000) {
      _statsHistory.removeAt(0);
    }
  }

  /// Get stats history
  List<CacheStats> getStatsHistory() => List.from(_statsHistory);

  /// Get stats trend (improving/degrading/stable)
  String getStatsTrend() {
    if (_statsHistory.length < 2) return 'stable';

    final recent = _statsHistory.sublist(
      (_statsHistory.length ~/ 2).clamp(0, _statsHistory.length),
    );
    final old = _statsHistory.take(_statsHistory.length ~/ 2).toList();

    if (recent.isEmpty || old.isEmpty) return 'stable';

    final recentAvgHitRate =
        recent.fold(0.0, (sum, s) => sum + s.hitRate) / recent.length;
    final oldAvgHitRate =
        old.fold(0.0, (sum, s) => sum + s.hitRate) / old.length;

    if (recentAvgHitRate > oldAvgHitRate * 1.1) {
      return 'improving';
    } else if (recentAvgHitRate < oldAvgHitRate * 0.9) {
      return 'degrading';
    } else {
      return 'stable';
    }
  }

  /// Get hot keys (most accessed)
  List<String> getHotKeys(int limit) {
    _removeExpiredEntries();

    final entries = _cache.values.toList();
    entries.sort((a, b) => b.accessCount.compareTo(a.accessCount));

    return entries
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  /// Get cold keys (least accessed)
  List<String> getColdKeys(int limit) {
    _removeExpiredEntries();

    final entries = _cache.values.toList();
    entries.sort((a, b) => a.accessCount.compareTo(b.accessCount));

    return entries
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  /// Export cache data as JSON
  String exportCacheDataAsJson() {
    _removeExpiredEntries();

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "size": ${_cache.length},
  "maxSize": $maxSize,
  "estimatedMemoryUsage": $_estimatedMemoryUsage,
  "statistics": ${_mapToJson(getStats().toMap())},
  "trend": "${getStatsTrend()}",
  "hotKeys": [
    ${getHotKeys(10).map((k) => '"$k"').join(', ')}
  ],
  "coldKeys": [
    ${getColdKeys(10).map((k) => '"$k"').join(', ')}
  ]
}
''';
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
      } else if (entry.value is bool) {
        buffer.write('${entry.value}');
      } else if (entry.value is num) {
        if (entry.value is double) {
          buffer.write('${(entry.value as double).toStringAsFixed(2)}');
        } else {
          buffer.write('${entry.value}');
        }
      } else if (entry.value is Map) {
        buffer.write(_mapToJson(entry.value as Map<String, dynamic>));
      } else {
        buffer.write('"${entry.value}"');
      }

      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }
}
