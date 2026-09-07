/// Adaptive cache strategy selection and management
enum EvictionStrategy {
  lru,           // Least Recently Used
  lfu,           // Least Frequently Used
  fifo,          // First In First Out
  adaptive,      // Automatically chosen based on access patterns
}

enum CacheSizingPolicy {
  fixed,         // Fixed maximum size
  dynamic,       // Adjusts based on available memory
  aggressive,    // Minimize memory usage
  liberal,       // Maximize cache effectiveness
}

/// Cache access pattern analysis for strategy selection
class AccessPattern {
  final int totalAccesses;
  final int uniqueKeys;
  final double temporalLocality; // 0.0-1.0: how concentrated accesses are over time
  final double spatialLocality;  // 0.0-1.0: how concentrated accesses are to related keys
  final double zipfianCoefficient; // Popularity distribution skewness
  final DateTime startTime;
  final DateTime endTime;

  AccessPattern({
    required this.totalAccesses,
    required this.uniqueKeys,
    required this.temporalLocality,
    required this.spatialLocality,
    required this.zipfianCoefficient,
    required this.startTime,
    required this.endTime,
  });

  /// Get duration of pattern analysis
  Duration get duration => endTime.difference(startTime);

  /// Calculate access rate (accesses per minute)
  double get accessRate {
    final minutes = duration.inMinutes;
    return minutes > 0 ? totalAccesses / minutes : 0.0;
  }

  Map<String, dynamic> toMap() => {
    'totalAccesses': totalAccesses,
    'uniqueKeys': uniqueKeys,
    'temporalLocality': temporalLocality.toStringAsFixed(2),
    'spatialLocality': spatialLocality.toStringAsFixed(2),
    'zipfianCoefficient': zipfianCoefficient.toStringAsFixed(2),
    'accessRate': accessRate.toStringAsFixed(2),
    'duration': duration.inSeconds,
  };
}

/// Strategy recommendation based on workload characteristics
class StrategyRecommendation {
  final EvictionStrategy recommendedStrategy;
  final CacheSizingPolicy recommendedSizing;
  final int suggestedCacheSize;
  final double confidenceScore; // 0.0-1.0
  final String reasoning;
  final List<String> alternativeStrategies;

  StrategyRecommendation({
    required this.recommendedStrategy,
    required this.recommendedSizing,
    required this.suggestedCacheSize,
    required this.confidenceScore,
    required this.reasoning,
    this.alternativeStrategies = const [],
  });

  Map<String, dynamic> toMap() => {
    'recommendedStrategy': recommendedStrategy.toString().split('.').last,
    'recommendedSizing': recommendedSizing.toString().split('.').last,
    'suggestedCacheSize': suggestedCacheSize,
    'confidenceScore': confidenceScore.toStringAsFixed(2),
    'reasoning': reasoning,
    'alternativeStrategies': alternativeStrategies,
  };
}

/// Adaptive cache strategy selector and manager
class AdaptiveCacheStrategy {
  static final AdaptiveCacheStrategy _instance =
      AdaptiveCacheStrategy._internal();

  factory AdaptiveCacheStrategy() {
    return _instance;
  }

  AdaptiveCacheStrategy._internal();

  EvictionStrategy _currentStrategy = EvictionStrategy.lru;
  CacheSizingPolicy _currentSizing = CacheSizingPolicy.fixed;
  int _currentMaxSize = 1000;
  final List<AccessPattern> _accessPatternHistory = [];
  final Map<EvictionStrategy, int> _strategyPerformance = {};
  int _adaptationCount = 0;

  /// Analyze access patterns and recommend strategy
  StrategyRecommendation analyzeAndRecommend(AccessPattern pattern) {
    _accessPatternHistory.add(pattern);

    // Keep history bounded
    if (_accessPatternHistory.length > 100) {
      _accessPatternHistory.removeAt(0);
    }

    // Determine best strategy based on pattern characteristics
    if (pattern.zipfianCoefficient > 1.5) {
      // High skewness: few keys are heavily accessed
      return StrategyRecommendation(
        recommendedStrategy: EvictionStrategy.lfu,
        recommendedSizing: CacheSizingPolicy.dynamic,
        suggestedCacheSize: (pattern.uniqueKeys * 0.3).toInt().clamp(100, 10000),
        confidenceScore: 0.95,
        reasoning: 'High access skewness detected: LFU better than LRU for this workload',
        alternativeStrategies: ['adaptive', 'lru'],
      );
    } else if (pattern.temporalLocality > 0.7) {
      // Strong temporal locality: recent accesses are good predictors
      return StrategyRecommendation(
        recommendedStrategy: EvictionStrategy.lru,
        recommendedSizing: CacheSizingPolicy.fixed,
        suggestedCacheSize: (pattern.uniqueKeys * 0.5).toInt().clamp(100, 10000),
        confidenceScore: 0.90,
        reasoning: 'Strong temporal locality: LRU is optimal',
        alternativeStrategies: ['adaptive', 'lfu'],
      );
    } else if (pattern.accessRate > 100) {
      // High access rate: prioritize speed
      return StrategyRecommendation(
        recommendedStrategy: EvictionStrategy.fifo,
        recommendedSizing: CacheSizingPolicy.aggressive,
        suggestedCacheSize: (pattern.uniqueKeys * 0.2).toInt().clamp(100, 5000),
        confidenceScore: 0.85,
        reasoning: 'High access rate: FIFO minimizes eviction overhead',
        alternativeStrategies: ['lru', 'adaptive'],
      );
    } else {
      // Balanced: use adaptive strategy
      return StrategyRecommendation(
        recommendedStrategy: EvictionStrategy.adaptive,
        recommendedSizing: CacheSizingPolicy.dynamic,
        suggestedCacheSize: (pattern.uniqueKeys * 0.4).toInt().clamp(100, 10000),
        confidenceScore: 0.75,
        reasoning: 'Mixed access pattern: Adaptive strategy adjusts dynamically',
        alternativeStrategies: ['lru', 'lfu'],
      );
    }
  }

  /// Apply strategy recommendation
  void applyRecommendation(StrategyRecommendation recommendation) {
    _currentStrategy = recommendation.recommendedStrategy;
    _currentSizing = recommendation.recommendedSizing;
    _currentMaxSize = recommendation.suggestedCacheSize;
    _adaptationCount++;
  }

  /// Get current strategy
  EvictionStrategy get currentStrategy => _currentStrategy;

  /// Get current sizing policy
  CacheSizingPolicy get currentSizing => _currentSizing;

  /// Get current max cache size
  int get currentMaxSize => _currentMaxSize;

  /// Set strategy manually
  void setStrategy(EvictionStrategy strategy) {
    _currentStrategy = strategy;
  }

  /// Set sizing policy manually
  void setSizingPolicy(CacheSizingPolicy policy) {
    _currentSizing = policy;
  }

  /// Set max cache size manually
  void setMaxSize(int size) {
    if (size > 0) {
      _currentMaxSize = size;
    }
  }

  /// Record strategy performance (0.0-1.0 score)
  void recordStrategyPerformance(EvictionStrategy strategy, double score) {
    if (!_strategyPerformance.containsKey(strategy)) {
      _strategyPerformance[strategy] = 0;
    }
    // Simple moving average
    final current = _strategyPerformance[strategy] ?? 0;
    _strategyPerformance[strategy] = ((current + (score * 100).toInt()) / 2).toInt();
  }

  /// Get strategy performance scores
  Map<EvictionStrategy, int> getStrategyPerformance() {
    return Map.from(_strategyPerformance);
  }

  /// Get access pattern summary
  String getAccessPatternSummary() {
    if (_accessPatternHistory.isEmpty) return 'No patterns recorded yet';

    final recent = _accessPatternHistory.last;
    final avgTemporal = _accessPatternHistory.fold(0.0, (sum, p) => sum + p.temporalLocality) /
        _accessPatternHistory.length;
    final avgSpatial = _accessPatternHistory.fold(0.0, (sum, p) => sum + p.spatialLocality) /
        _accessPatternHistory.length;

    return '''
Access Pattern Analysis:
- Patterns Recorded: ${_accessPatternHistory.length}
- Current Temporal Locality: ${recent.temporalLocality.toStringAsFixed(2)}
- Average Temporal Locality: ${avgTemporal.toStringAsFixed(2)}
- Average Spatial Locality: ${avgSpatial.toStringAsFixed(2)}
- Current Strategy: ${_currentStrategy.toString().split('.').last}
- Adaptations Made: $_adaptationCount
''';
  }

  /// Adaptive size calculation based on system load
  int calculateAdaptiveSize(int baseSize, double systemMemoryPressure) {
    // systemMemoryPressure: 0.0 (low pressure) to 1.0 (high pressure)
    switch (_currentSizing) {
      case CacheSizingPolicy.fixed:
        return _currentMaxSize;
      case CacheSizingPolicy.dynamic:
        // Scale based on memory pressure
        return (baseSize * (1.0 - (systemMemoryPressure * 0.5))).toInt().clamp(100, 100000);
      case CacheSizingPolicy.aggressive:
        // Keep cache small under pressure
        return (baseSize * (1.0 - systemMemoryPressure)).toInt().clamp(50, 5000);
      case CacheSizingPolicy.liberal:
        // Maximize cache size
        return (baseSize * (1.0 + (systemMemoryPressure * 0.3))).toInt().clamp(1000, 100000);
    }
  }

  /// Get all patterns
  List<AccessPattern> getAllPatterns() => List.from(_accessPatternHistory);

  /// Clear history
  void clearHistory() {
    _accessPatternHistory.clear();
    _strategyPerformance.clear();
    _adaptationCount = 0;
  }

  /// Export strategy data as JSON
  String exportStrategyDataAsJson() {
    final patterns = _accessPatternHistory.map((p) => p.toMap()).toList();
    final performance = _strategyPerformance.map(
      (key, value) => MapEntry(key.toString().split('.').last, value),
    );

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "currentStrategy": "${_currentStrategy.toString().split('.').last}",
  "currentSizing": "${_currentSizing.toString().split('.').last}",
  "currentMaxSize": $_currentMaxSize,
  "adaptationCount": $_adaptationCount,
  "strategyPerformance": ${_mapToJson(performance)},
  "recentPatterns": [
    ${patterns.take(10).map((p) => _mapToJson(p)).join(', ')}
  ],
  "patternCount": ${_accessPatternHistory.length}
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
        buffer.write('[${(entry.value as List).map((v) => _mapToJson(v as Map<String, dynamic>)).join(', ')}]');
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
