/// Memory allocation and fragmentation tracking
class MemoryAllocation {
  final String key;
  final int allocatedBytes;
  final int usedBytes;
  final DateTime allocatedAt;
  DateTime lastAccessedAt;

  MemoryAllocation({
    required this.key,
    required this.allocatedBytes,
    required this.usedBytes,
    required this.allocatedAt,
  }) : lastAccessedAt = DateTime.now();

  /// Get fragmentation (wasted space)
  int get fragmentationBytes => allocatedBytes - usedBytes;

  /// Get fragmentation percentage
  double get fragmentationPercent {
    return allocatedBytes > 0 ? (fragmentationBytes / allocatedBytes) * 100 : 0.0;
  }

  /// Get age in seconds
  int get ageSeconds => DateTime.now().difference(allocatedAt).inSeconds;

  Map<String, dynamic> toMap() => {
    'key': key,
    'allocatedBytes': allocatedBytes,
    'usedBytes': usedBytes,
    'fragmentationBytes': fragmentationBytes,
    'fragmentationPercent': fragmentationPercent.toStringAsFixed(2),
    'ageSeconds': ageSeconds,
  };
}

/// Memory snapshot at a point in time
class MemorySnapshot {
  final DateTime timestamp;
  final int totalAllocated;
  final int totalUsed;
  final int totalFragmented;
  final double fragmentation;
  final int allocationCount;
  final double avgAllocationSize;

  MemorySnapshot({
    required this.timestamp,
    required this.totalAllocated,
    required this.totalUsed,
    required this.totalFragmented,
    required this.fragmentation,
    required this.allocationCount,
    required this.avgAllocationSize,
  });

  /// Get efficiency score (0.0-1.0)
  double get efficiencyScore {
    return totalAllocated > 0 ? (totalUsed / totalAllocated).clamp(0.0, 1.0) : 0.0;
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'totalAllocated': totalAllocated,
    'totalUsed': totalUsed,
    'totalFragmented': totalFragmented,
    'fragmentation': fragmentation.toStringAsFixed(2),
    'efficiencyScore': efficiencyScore.toStringAsFixed(2),
    'allocationCount': allocationCount,
    'avgAllocationSize': avgAllocationSize.toStringAsFixed(0),
  };
}

/// Cache memory profiler for tracking and optimization
class CacheMemoryProfiler {
  static final CacheMemoryProfiler _instance =
      CacheMemoryProfiler._internal();

  factory CacheMemoryProfiler() {
    return _instance;
  }

  CacheMemoryProfiler._internal();

  final Map<String, MemoryAllocation> _allocations = {};
  final List<MemorySnapshot> _snapshots = [];
  int _totalAllocations = 0;
  int _totalDeallocations = 0;
  int _peakMemoryUsage = 0;
  DateTime _profilerStartTime = DateTime.now();

  /// Record memory allocation
  void recordAllocation(String key, int allocatedBytes, int usedBytes) {
    _allocations[key] = MemoryAllocation(
      key: key,
      allocatedBytes: allocatedBytes,
      usedBytes: usedBytes,
      allocatedAt: DateTime.now(),
    );
    _totalAllocations++;
    _updatePeakMemory();
  }

  /// Update an allocation
  void updateAllocation(String key, int usedBytes) {
    if (_allocations.containsKey(key)) {
      final alloc = _allocations[key]!;
      _allocations[key] = MemoryAllocation(
        key: key,
        allocatedBytes: alloc.allocatedBytes,
        usedBytes: usedBytes.clamp(0, alloc.allocatedBytes),
        allocatedAt: alloc.allocatedAt,
      );
      _updatePeakMemory();
    }
  }

  /// Record deallocation
  void recordDeallocation(String key) {
    _allocations.remove(key);
    _totalDeallocations++;
  }

  /// Get total memory used
  int getTotalMemoryUsed() {
    return _allocations.values.fold(0, (sum, a) => sum + a.usedBytes);
  }

  /// Get total memory allocated
  int getTotalMemoryAllocated() {
    return _allocations.values.fold(0, (sum, a) => sum + a.allocatedBytes);
  }

  /// Get total fragmentation
  int getTotalFragmentation() {
    return _allocations.values.fold(0, (sum, a) => sum + a.fragmentationBytes);
  }

  /// Get fragmentation percentage
  double getFragmentationPercent() {
    final total = getTotalMemoryAllocated();
    return total > 0 ? (getTotalFragmentation() / total) * 100 : 0.0;
  }

  /// Update peak memory tracking
  void _updatePeakMemory() {
    final current = getTotalMemoryAllocated();
    if (current > _peakMemoryUsage) {
      _peakMemoryUsage = current;
    }
  }

  /// Get peak memory usage
  int getPeakMemoryUsage() => _peakMemoryUsage;

  /// Find most fragmented allocations
  List<MemoryAllocation> getMostFragmentedAllocations(int limit) {
    final allocations = _allocations.values.toList();
    allocations.sort((a, b) => b.fragmentationPercent.compareTo(a.fragmentationPercent));
    return allocations.take(limit).toList();
  }

  /// Find largest allocations
  List<MemoryAllocation> getLargestAllocations(int limit) {
    final allocations = _allocations.values.toList();
    allocations.sort((a, b) => b.allocatedBytes.compareTo(a.allocatedBytes));
    return allocations.take(limit).toList();
  }

  /// Create memory snapshot
  MemorySnapshot createSnapshot() {
    final totalAllocated = getTotalMemoryAllocated();
    final totalUsed = getTotalMemoryUsed();
    final totalFragmented = getTotalFragmentation();
    final allocationCount = _allocations.length;
    final avgSize = allocationCount > 0 ? totalAllocated / allocationCount : 0.0;

    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      totalAllocated: totalAllocated,
      totalUsed: totalUsed,
      totalFragmented: totalFragmented,
      fragmentation: getFragmentationPercent(),
      allocationCount: allocationCount,
      avgAllocationSize: avgSize,
    );

    _snapshots.add(snapshot);

    // Keep only last 500 snapshots
    if (_snapshots.length > 500) {
      _snapshots.removeAt(0);
    }

    return snapshot;
  }

  /// Get memory trend (improving/degrading/stable)
  String getMemoryTrend() {
    if (_snapshots.length < 2) return 'stable';

    final recent = _snapshots.sublist(
      (_snapshots.length ~/ 2).clamp(0, _snapshots.length),
    );
    final old = _snapshots.take(_snapshots.length ~/ 2).toList();

    if (recent.isEmpty || old.isEmpty) return 'stable';

    final recentAvgFragmentation =
        recent.fold(0.0, (sum, s) => sum + s.fragmentation) / recent.length;
    final oldAvgFragmentation =
        old.fold(0.0, (sum, s) => sum + s.fragmentation) / old.length;

    if (recentAvgFragmentation < oldAvgFragmentation * 0.9) {
      return 'improving';
    } else if (recentAvgFragmentation > oldAvgFragmentation * 1.1) {
      return 'degrading';
    } else {
      return 'stable';
    }
  }

  /// Suggest cleanup opportunities
  List<String> suggestCleanupOpportunities(double fragmentationThreshold) {
    final suggestions = <String>[];

    // Find highly fragmented allocations
    final fragmented = getMostFragmentedAllocations(10);
    for (final alloc in fragmented) {
      if (alloc.fragmentationPercent > fragmentationThreshold) {
        suggestions.add(
          'Consider reducing allocated size for "${alloc.key}" '
          '(fragmentation: ${alloc.fragmentationPercent.toStringAsFixed(1)}%)',
        );
      }
    }

    // Check overall trend
    if (getMemoryTrend() == 'degrading') {
      suggestions.add('Memory fragmentation is increasing. Consider garbage collection.');
    }

    // Find unused allocations
    final now = DateTime.now();
    for (final alloc in _allocations.values) {
      final ageMinutes = now.difference(alloc.allocatedAt).inMinutes;
      if (ageMinutes > 60 && alloc.usedBytes == 0) {
        suggestions.add('Allocation "${alloc.key}" is old and unused. Consider removing it.');
      }
    }

    return suggestions;
  }

  /// Get profiler statistics
  Map<String, dynamic> getProfilerStats() {
    final currentSnapshot = createSnapshot();
    return {
      'profilerStartTime': _profilerStartTime.toIso8601String(),
      'uptime': DateTime.now().difference(_profilerStartTime).inSeconds,
      'totalAllocations': _totalAllocations,
      'totalDeallocations': _totalDeallocations,
      'currentAllocations': _allocations.length,
      'peakMemoryUsage': _peakMemoryUsage,
      'currentMemoryUsed': currentSnapshot.totalUsed,
      'currentMemoryAllocated': currentSnapshot.totalAllocated,
      'totalFragmentation': currentSnapshot.totalFragmented,
      'fragmentationPercent': currentSnapshot.fragmentation.toStringAsFixed(2),
      'efficiencyScore': currentSnapshot.efficiencyScore.toStringAsFixed(2),
      'memoryTrend': getMemoryTrend(),
      'snapshotCount': _snapshots.length,
    };
  }

  /// Get all snapshots
  List<MemorySnapshot> getAllSnapshots() => List.from(_snapshots);

  /// Clear profiler data
  void clearData() {
    _allocations.clear();
    _snapshots.clear();
    _totalAllocations = 0;
    _totalDeallocations = 0;
    _peakMemoryUsage = 0;
    _profilerStartTime = DateTime.now();
  }

  /// Export profiler data as JSON
  String exportProfilerDataAsJson() {
    final stats = getProfilerStats();
    final currentSnapshot = _snapshots.isNotEmpty ? _snapshots.last : createSnapshot();
    final mostFragmented = getMostFragmentedAllocations(10)
        .map((a) => a.toMap())
        .toList();

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "profilerStats": ${_mapToJson(stats)},
  "currentSnapshot": ${_mapToJson(currentSnapshot.toMap())},
  "mostFragmentedAllocations": [
    ${mostFragmented.map((a) => _mapToJson(a)).join(', ')}
  ],
  "cleanupSuggestions": [
    ${suggestCleanupOpportunities(30.0).map((s) => '"$s"').join(', ')}
  ],
  "snapshotCount": ${_snapshots.length}
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
      } else if (entry.value is List) {
        buffer.write('[${(entry.value as List).map((v) {
          if (v is Map) return _mapToJson(v as Map<String, dynamic>);
          if (v is String) return '"$v"';
          return '$v';
        }).join(', ')}]');
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
