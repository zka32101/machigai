/// Network adaptation strategies based on connection quality
enum NetworkAdaptationStrategy {
  aggressive,    // Maximum optimization for poor networks
  moderate,      // Balanced approach
  conservative,  // Minimal optimization for good networks
  dynamic,       // Automatically adjust based on conditions
}

/// Network profile with metrics
class NetworkProfile {
  final DateTime recordedAt;
  final int latencyMs;
  final double bandwidthMbps;
  final double packetLossPercent;
  final bool isOnline;
  final int signalStrength; // 0-100
  final String connectionType; // WiFi, 4G, 5G, etc.

  NetworkProfile({
    required this.recordedAt,
    required this.latencyMs,
    required this.bandwidthMbps,
    required this.packetLossPercent,
    required this.isOnline,
    required this.signalStrength,
    required this.connectionType,
  });

  /// Get network quality score (0.0-1.0)
  double get qualityScore {
    if (!isOnline) return 0.0;

    // Latency score: lower is better (inverted)
    final latencyScore = (1.0 - (latencyMs / 1000).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    // Bandwidth score: higher is better
    final bandwidthScore = (bandwidthMbps / 10).clamp(0.0, 1.0);

    // Packet loss score: lower is better (inverted)
    final packetLossScore = (1.0 - (packetLossPercent / 100).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    // Signal strength score: higher is better
    final signalScore = signalStrength / 100;

    // Weighted average
    return (latencyScore * 0.25 + bandwidthScore * 0.35 + packetLossScore * 0.25 + signalScore * 0.15)
        .clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() => {
    'recordedAt': recordedAt.toIso8601String(),
    'latencyMs': latencyMs,
    'bandwidthMbps': bandwidthMbps.toStringAsFixed(2),
    'packetLossPercent': packetLossPercent.toStringAsFixed(2),
    'isOnline': isOnline,
    'signalStrength': signalStrength,
    'connectionType': connectionType,
    'qualityScore': qualityScore.toStringAsFixed(2),
  };
}

/// Adaptation recommendation
class AdaptationRecommendation {
  final NetworkAdaptationStrategy strategy;
  final int compressionLevel; // 0-9
  final int prefetchAggression; // 0-10
  final int cacheSize;
  final Duration ttl;
  final bool enableOfflineMode;
  final double estimatedEfficiency; // 0.0-1.0

  AdaptationRecommendation({
    required this.strategy,
    required this.compressionLevel,
    required this.prefetchAggression,
    required this.cacheSize,
    required this.ttl,
    required this.enableOfflineMode,
    required this.estimatedEfficiency,
  });

  Map<String, dynamic> toMap() => {
    'strategy': strategy.toString().split('.').last,
    'compressionLevel': compressionLevel,
    'prefetchAggression': prefetchAggression,
    'cacheSize': cacheSize,
    'ttlSeconds': ttl.inSeconds,
    'enableOfflineMode': enableOfflineMode,
    'estimatedEfficiency': estimatedEfficiency.toStringAsFixed(2),
  };
}

/// Network adaptation service for optimizing based on connection quality
class NetworkAdaptationService {
  static final NetworkAdaptationService _instance =
      NetworkAdaptationService._internal();

  factory NetworkAdaptationService() {
    return _instance;
  }

  NetworkAdaptationService._internal();

  final List<NetworkProfile> _profileHistory = [];
  NetworkAdaptationStrategy _currentStrategy = NetworkAdaptationStrategy.dynamic;
  late AdaptationRecommendation _currentRecommendation;
  int _strategySwitches = 0;
  final Map<NetworkAdaptationStrategy, int> _strategySuccessCount = {};

  NetworkAdaptationService._internalInit() {
    _currentRecommendation = _getDefaultRecommendation();
  }

  /// Record network profile
  void recordNetworkProfile(NetworkProfile profile) {
    _profileHistory.add(profile);

    // Keep only last 1000 profiles
    if (_profileHistory.length > 1000) {
      _profileHistory.removeAt(0);
    }
  }

  /// Detect network condition and generate recommendation
  AdaptationRecommendation analyzeAndAdapt(NetworkProfile currentProfile) {
    recordNetworkProfile(currentProfile);

    final recommendation = _generateRecommendation(currentProfile);

    // Check if strategy needs to change
    if (_currentStrategy == NetworkAdaptationStrategy.dynamic) {
      final oldStrategy = _currentStrategy;
      _currentStrategy = recommendation.strategy;
      if (oldStrategy != _currentStrategy) {
        _strategySwitches++;
      }
    }

    _currentRecommendation = recommendation;
    return recommendation;
  }

  /// Generate recommendation based on network quality
  AdaptationRecommendation _generateRecommendation(NetworkProfile profile) {
    final qualityScore = profile.qualityScore;

    if (!profile.isOnline) {
      // Offline mode
      return AdaptationRecommendation(
        strategy: NetworkAdaptationStrategy.aggressive,
        compressionLevel: 9,
        prefetchAggression: 0,
        cacheSize: 10000,
        ttl: const Duration(days: 7),
        enableOfflineMode: true,
        estimatedEfficiency: 0.3,
      );
    } else if (qualityScore > 0.8) {
      // Excellent connection
      return AdaptationRecommendation(
        strategy: NetworkAdaptationStrategy.conservative,
        compressionLevel: 1,
        prefetchAggression: 3,
        cacheSize: 1000,
        ttl: const Duration(hours: 1),
        enableOfflineMode: false,
        estimatedEfficiency: 0.95,
      );
    } else if (qualityScore > 0.6) {
      // Good connection
      return AdaptationRecommendation(
        strategy: NetworkAdaptationStrategy.moderate,
        compressionLevel: 3,
        prefetchAggression: 5,
        cacheSize: 3000,
        ttl: const Duration(hours: 2),
        enableOfflineMode: false,
        estimatedEfficiency: 0.85,
      );
    } else if (qualityScore > 0.4) {
      // Fair connection
      return AdaptationRecommendation(
        strategy: NetworkAdaptationStrategy.moderate,
        compressionLevel: 6,
        prefetchAggression: 7,
        cacheSize: 5000,
        ttl: const Duration(hours: 4),
        enableOfflineMode: true,
        estimatedEfficiency: 0.70,
      );
    } else {
      // Poor connection
      return AdaptationRecommendation(
        strategy: NetworkAdaptationStrategy.aggressive,
        compressionLevel: 9,
        prefetchAggression: 10,
        cacheSize: 8000,
        ttl: const Duration(days: 1),
        enableOfflineMode: true,
        estimatedEfficiency: 0.50,
      );
    }
  }

  /// Get default recommendation for normal conditions
  AdaptationRecommendation _getDefaultRecommendation() {
    return AdaptationRecommendation(
      strategy: NetworkAdaptationStrategy.moderate,
      compressionLevel: 3,
      prefetchAggression: 5,
      cacheSize: 3000,
      ttl: const Duration(hours: 2),
      enableOfflineMode: false,
      estimatedEfficiency: 0.75,
    );
  }

  /// Get average network quality over time
  double getAverageNetworkQuality() {
    if (_profileHistory.isEmpty) return 0.0;
    final avgScore = _profileHistory.fold(0.0, (sum, p) => sum + p.qualityScore) /
        _profileHistory.length;
    return avgScore.clamp(0.0, 1.0);
  }

  /// Detect network trend (improving/degrading/stable)
  String getNetworkTrend() {
    if (_profileHistory.length < 2) return 'stable';

    final recent = _profileHistory.sublist(
      (_profileHistory.length ~/ 2).clamp(0, _profileHistory.length),
    );
    final old = _profileHistory.take(_profileHistory.length ~/ 2).toList();

    if (recent.isEmpty || old.isEmpty) return 'stable';

    final recentAvgQuality =
        recent.fold(0.0, (sum, p) => sum + p.qualityScore) / recent.length;
    final oldAvgQuality = old.fold(0.0, (sum, p) => sum + p.qualityScore) / old.length;

    if (recentAvgQuality > oldAvgQuality * 1.1) {
      return 'improving';
    } else if (recentAvgQuality < oldAvgQuality * 0.9) {
      return 'degrading';
    } else {
      return 'stable';
    }
  }

  /// Get network statistics
  Map<String, dynamic> getNetworkStatistics() {
    if (_profileHistory.isEmpty) {
      return {
        'profileCount': 0,
        'averageQuality': 0.0,
        'trend': 'unknown',
      };
    }

    final avgLatency = _profileHistory.fold(0, (sum, p) => sum + p.latencyMs) /
        _profileHistory.length;
    final avgBandwidth = _profileHistory.fold(0.0, (sum, p) => sum + p.bandwidthMbps) /
        _profileHistory.length;
    final onlineCount = _profileHistory.where((p) => p.isOnline).length;

    return {
      'profileCount': _profileHistory.length,
      'averageQuality': getAverageNetworkQuality().toStringAsFixed(2),
      'averageLatencyMs': avgLatency.toInt(),
      'averageBandwidthMbps': avgBandwidth.toStringAsFixed(2),
      'uptimePercent': ((onlineCount / _profileHistory.length) * 100).toStringAsFixed(1),
      'trend': getNetworkTrend(),
      'strategySwitches': _strategySwitches,
    };
  }

  /// Get all network profiles
  List<NetworkProfile> getAllProfiles() => List.from(_profileHistory);

  /// Get current strategy
  NetworkAdaptationStrategy get currentStrategy => _currentStrategy;

  /// Get current recommendation
  AdaptationRecommendation get currentRecommendation => _currentRecommendation;

  /// Record strategy success
  void recordStrategySuccess(NetworkAdaptationStrategy strategy, bool wasSuccessful) {
    if (wasSuccessful) {
      _strategySuccessCount[strategy] = (_strategySuccessCount[strategy] ?? 0) + 1;
    }
  }

  /// Get strategy success rates
  Map<String, double> getStrategySuccessRates() {
    final rates = <String, double>{};
    for (final strategy in NetworkAdaptationStrategy.values) {
      rates[strategy.toString().split('.').last] =
          ((_strategySuccessCount[strategy] ?? 0) / 100).clamp(0.0, 1.0);
    }
    return rates;
  }

  /// Clear history
  void clearHistory() {
    _profileHistory.clear();
    _strategySwitches = 0;
    _strategySuccessCount.clear();
  }

  /// Export adaptation data as JSON
  String exportAdaptationDataAsJson() {
    final stats = getNetworkStatistics();
    final recentProfiles = _profileHistory.take(20).map((p) => p.toMap()).toList();

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "currentStrategy": "${_currentStrategy.toString().split('.').last}",
  "currentRecommendation": ${_mapToJson(_currentRecommendation.toMap())},
  "statistics": ${_mapToJson(stats)},
  "recentProfiles": [
    ${recentProfiles.map((p) => _mapToJson(p)).join(', ')}
  ],
  "profileHistorySize": ${_profileHistory.length}
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
