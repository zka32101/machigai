/// Cache access pattern tracking and analysis
class CacheAccessPattern {
  final String key;
  int hitCount;
  int missCount;
  final DateTime firstAccessTime;
  DateTime lastAccessTime;
  final List<int> accessIntervals; // Milliseconds between accesses

  CacheAccessPattern({
    required this.key,
    required this.firstAccessTime,
  })  : hitCount = 0,
        missCount = 0,
        lastAccessTime = DateTime.now(),
        accessIntervals = [];

  /// Get hit rate
  double get hitRate {
    final total = hitCount + missCount;
    return total > 0 ? (hitCount / total) * 100 : 0.0;
  }

  /// Get access frequency (accesses per minute)
  double get accessFrequency {
    final duration = DateTime.now().difference(firstAccessTime).inMinutes;
    return duration > 0 ? (hitCount + missCount) / duration : 0.0;
  }

  /// Get average interval between accesses (milliseconds)
  int get averageAccessInterval {
    return accessIntervals.isNotEmpty
        ? (accessIntervals.fold(0, (sum, i) => sum + i) ~/ accessIntervals.length)
        : 0;
  }

  /// Get age in seconds
  int get ageSeconds => DateTime.now().difference(firstAccessTime).inSeconds;

  void recordHit() {
    hitCount++;
    _recordAccessInterval();
  }

  void recordMiss() {
    missCount++;
    _recordAccessInterval();
  }

  void _recordAccessInterval() {
    final now = DateTime.now();
    final interval = now.difference(lastAccessTime).inMilliseconds;
    accessIntervals.add(interval);

    // Keep only last 100 intervals
    if (accessIntervals.length > 100) {
      accessIntervals.removeAt(0);
    }

    lastAccessTime = now;
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'hitCount': hitCount,
    'missCount': missCount,
    'hitRate': hitRate.toStringAsFixed(2),
    'totalAccesses': hitCount + missCount,
    'accessFrequency': accessFrequency.toStringAsFixed(2),
    'averageAccessInterval': averageAccessInterval,
    'ageSeconds': ageSeconds,
  };
}

/// Optimization recommendation based on access patterns
class OptimizationRecommendation {
  final String key;
  final String recommendation;
  final double estimatedImprovement; // 0.0-1.0
  final String reasoning;
  final List<String> alternativeApproaches;

  OptimizationRecommendation({
    required this.key,
    required this.recommendation,
    required this.estimatedImprovement,
    required this.reasoning,
    this.alternativeApproaches = const [],
  });

  Map<String, dynamic> toMap() => {
    'key': key,
    'recommendation': recommendation,
    'estimatedImprovement': estimatedImprovement.toStringAsFixed(2),
    'reasoning': reasoning,
    'alternativeApproaches': alternativeApproaches,
  };
}

/// Cache analytics for access pattern analysis
class CacheAnalytics {
  static final CacheAnalytics _instance = CacheAnalytics._internal();

  factory CacheAnalytics() {
    return _instance;
  }

  CacheAnalytics._internal();

  final Map<String, CacheAccessPattern> _patterns = {};
  int _totalHits = 0;
  int _totalMisses = 0;
  final List<Map<String, dynamic>> _performanceHistory = [];

  /// Record cache hit
  void recordHit(String key) {
    if (!_patterns.containsKey(key)) {
      _patterns[key] = CacheAccessPattern(
        key: key,
        firstAccessTime: DateTime.now(),
      );
    }
    _patterns[key]!.recordHit();
    _totalHits++;
  }

  /// Record cache miss
  void recordMiss(String key) {
    if (!_patterns.containsKey(key)) {
      _patterns[key] = CacheAccessPattern(
        key: key,
        firstAccessTime: DateTime.now(),
      );
    }
    _patterns[key]!.recordMiss();
    _totalMisses++;
  }

  /// Get overall hit rate
  double getOverallHitRate() {
    final total = _totalHits + _totalMisses;
    return total > 0 ? (_totalHits / total) * 100 : 0.0;
  }

  /// Get most frequently accessed keys
  List<String> getMostFrequentKeys(int limit) {
    final patterns = _patterns.values.toList();
    patterns.sort((a, b) => b.accessFrequency.compareTo(a.accessFrequency));
    return patterns.take(limit).map((p) => p.key).toList();
  }

  /// Get least frequently accessed keys
  List<String> getLeastFrequentKeys(int limit) {
    final patterns = _patterns.values.toList();
    patterns.sort((a, b) => a.accessFrequency.compareTo(b.accessFrequency));
    return patterns.take(limit).map((p) => p.key).toList();
  }

  /// Get keys with best hit rates
  List<String> getKeysWithBestHitRates(int limit) {
    final patterns = _patterns.values.toList();
    patterns.sort((a, b) => b.hitRate.compareTo(a.hitRate));
    return patterns.take(limit).map((p) => p.key).toList();
  }

  /// Get keys with worst hit rates
  List<String> getKeysWithWorstHitRates(int limit) {
    final patterns = _patterns.values.toList();
    patterns.sort((a, b) => a.hitRate.compareTo(b.hitRate));
    return patterns.take(limit).map((p) => p.key).toList();
  }

  /// Analyze patterns and generate optimization recommendations
  List<OptimizationRecommendation> analyzeAndRecommend() {
    final recommendations = <OptimizationRecommendation>[];

    for (final pattern in _patterns.values) {
      // Low hit rate recommendation
      if (pattern.hitRate < 30 && pattern.hitCount + pattern.missCount > 10) {
        recommendations.add(
          OptimizationRecommendation(
            key: pattern.key,
            recommendation: 'Reduce cache size or TTL',
            estimatedImprovement: 0.25,
            reasoning:
                'Low hit rate suggests this key is not valuable for caching (${pattern.hitRate.toStringAsFixed(1)}%)',
            alternativeApproaches: ['Remove from cache', 'Increase TTL', 'Increase cache size'],
          ),
        );
      }

      // High frequency with low hit rate
      if (pattern.accessFrequency > 10 && pattern.hitRate < 50) {
        recommendations.add(
          OptimizationRecommendation(
            key: pattern.key,
            recommendation: 'Increase cache size or extend TTL',
            estimatedImprovement: 0.40,
            reasoning:
                'High access frequency but low hit rate indicates evictions or expiration issues',
            alternativeApproaches: [
              'Increase cache size',
              'Extend TTL',
              'Use different eviction strategy'
            ],
          ),
        );
      }

      // Unused or old keys
      if (pattern.ageSeconds > 3600 && (pattern.hitCount + pattern.missCount) < 5) {
        recommendations.add(
          OptimizationRecommendation(
            key: pattern.key,
            recommendation: 'Remove from cache',
            estimatedImprovement: 0.15,
            reasoning: 'Rarely accessed old entry consuming cache space',
            alternativeApproaches: ['Keep with lower priority', 'Archive to disk'],
          ),
        );
      }

      // Very high hit rate - hot key
      if (pattern.hitRate > 95 && (pattern.hitCount + pattern.missCount) > 100) {
        recommendations.add(
          OptimizationRecommendation(
            key: pattern.key,
            recommendation: 'Prioritize in cache',
            estimatedImprovement: 0.10,
            reasoning: 'Very hot key with excellent hit rate - prioritize retention',
            alternativeApproaches: ['Increase TTL', 'Lock in cache', 'Replicate'],
          ),
        );
      }
    }

    // Sort by estimated improvement
    recommendations.sort((a, b) => b.estimatedImprovement.compareTo(a.estimatedImprovement));

    return recommendations;
  }

  /// Get pattern for specific key
  CacheAccessPattern? getPattern(String key) => _patterns[key];

  /// Get all patterns
  List<CacheAccessPattern> getAllPatterns() => List.from(_patterns.values);

  /// Record performance snapshot
  void recordPerformanceSnapshot() {
    _performanceHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'totalHits': _totalHits,
      'totalMisses': _totalMisses,
      'hitRate': getOverallHitRate(),
      'uniqueKeys': _patterns.length,
      'totalAccesses': _totalHits + _totalMisses,
    });

    // Keep only last 1000 snapshots
    if (_performanceHistory.length > 1000) {
      _performanceHistory.removeAt(0);
    }
  }

  /// Get performance history
  List<Map<String, dynamic>> getPerformanceHistory() => List.from(_performanceHistory);

  /// Get performance trend
  String getPerformanceTrend() {
    if (_performanceHistory.length < 2) return 'stable';

    final recent = _performanceHistory.sublist(
      (_performanceHistory.length ~/ 2).clamp(0, _performanceHistory.length),
    );
    final old = _performanceHistory.take(_performanceHistory.length ~/ 2).toList();

    if (recent.isEmpty || old.isEmpty) return 'stable';

    final recentAvgHitRate =
        recent.fold(0.0, (sum, s) => sum + (s['hitRate'] as num)) / recent.length;
    final oldAvgHitRate = old.fold(0.0, (sum, s) => sum + (s['hitRate'] as num)) / old.length;

    if (recentAvgHitRate > oldAvgHitRate * 1.05) {
      return 'improving';
    } else if (recentAvgHitRate < oldAvgHitRate * 0.95) {
      return 'degrading';
    } else {
      return 'stable';
    }
  }

  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'totalHits': _totalHits,
      'totalMisses': _totalMisses,
      'overallHitRate': getOverallHitRate().toStringAsFixed(2),
      'uniqueKeysTracked': _patterns.length,
      'totalAccesses': _totalHits + _totalMisses,
      'performanceTrend': getPerformanceTrend(),
      'performanceHistorySize': _performanceHistory.length,
    };
  }

  /// Clear analytics data
  void clearData() {
    _patterns.clear();
    _performanceHistory.clear();
    _totalHits = 0;
    _totalMisses = 0;
  }

  /// Export analytics as JSON
  String exportAnalyticsAsJson() {
    final recommendations = analyzeAndRecommend();
    final summary = getAnalyticsSummary();
    final topKeys = getMostFrequentKeys(10);
    final recommendations_json = recommendations.map((r) => r.toMap()).toList();

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "summary": ${_mapToJson(summary)},
  "topFrequentKeys": [
    ${topKeys.map((k) => '"$k"').join(', ')}
  ],
  "recommendations": [
    ${recommendations_json.map((r) => _mapToJson(r)).join(', ')}
  ],
  "performanceTrend": "${getPerformanceTrend()}",
  "recentPerformanceHistory": [
    ${_performanceHistory.take(20).map((h) => _mapToJson(h)).join(', ')}
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
