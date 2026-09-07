import 'dart:async';

/// Network condition types
enum NetworkCondition {
  excellent, // > 10 Mbps
  good, // 5-10 Mbps
  fair, // 1-5 Mbps
  poor, // < 1 Mbps
  offline, // No connection
}

/// Network profile
class NetworkProfile {
  final String id;
  final NetworkCondition condition;
  final double bandwidth; // Mbps
  final double latency; // ms
  final double packetLoss; // percentage
  final DateTime timestamp;

  NetworkProfile({
    required this.id,
    required this.condition,
    required this.bandwidth,
    required this.latency,
    required this.packetLoss,
  }) : timestamp = DateTime.now();

  /// Get recommended quality level (0-100)
  int get recommendedQuality {
    switch (condition) {
      case NetworkCondition.excellent:
        return 100;
      case NetworkCondition.good:
        return 80;
      case NetworkCondition.fair:
        return 60;
      case NetworkCondition.poor:
        return 30;
      case NetworkCondition.offline:
        return 0;
    }
  }

  /// Check if network is suitable for sync
  bool get isSuitableForSync =>
      condition != NetworkCondition.poor &&
      condition != NetworkCondition.offline;

  Map<String, dynamic> toMap() => {
    'id': id,
    'condition': condition.toString(),
    'bandwidth': bandwidth,
    'latency': latency,
    'packetLoss': packetLoss,
    'timestamp': timestamp.toIso8601String(),
    'recommendedQuality': recommendedQuality,
  };
}

/// Optimization recommendation
class OptimizationRecommendation {
  final String id;
  final String title;
  final String description;
  final double estimatedImprovement; // percentage
  final Map<String, dynamic> parameters;
  final DateTime createdAt;

  OptimizationRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedImprovement,
    required this.parameters,
  }) : createdAt = DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'estimatedImprovement': estimatedImprovement,
    'parameters': parameters,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Service for optimizing bandwidth usage
class BandwidthOptimizer {
  static final BandwidthOptimizer _instance =
      BandwidthOptimizer._internal();

  factory BandwidthOptimizer() {
    return _instance;
  }

  BandwidthOptimizer._internal();

  // Network monitoring
  final List<NetworkProfile> _networkProfiles = [];
  NetworkProfile? _currentProfile;

  // Optimization
  final List<OptimizationRecommendation> _recommendations = [];
  final Map<String, dynamic> _optimizationState = {};

  // Statistics
  int _totalBandwidthUsed = 0;
  int _totalBandwidthSaved = 0;
  DateTime? _lastOptimization;

  /// Record network profile
  void recordNetworkProfile(NetworkProfile profile) {
    _networkProfiles.add(profile);
    _currentProfile = profile;

    // Keep only last 1000 profiles
    if (_networkProfiles.length > 1000) {
      _networkProfiles.removeAt(0);
    }

    _totalBandwidthUsed += (profile.bandwidth * 10).toInt();
  }

  /// Detect current network condition
  NetworkCondition detectNetworkCondition({
    required double bandwidth,
    required double latency,
    required double packetLoss,
  }) {
    if (bandwidth == 0) {
      return NetworkCondition.offline;
    } else if (bandwidth < 1) {
      return NetworkCondition.poor;
    } else if (bandwidth < 5) {
      return NetworkCondition.fair;
    } else if (bandwidth < 10) {
      return NetworkCondition.good;
    } else {
      return NetworkCondition.excellent;
    }
  }

  /// Get current network condition
  NetworkCondition? getCurrentCondition() {
    return _currentProfile?.condition;
  }

  /// Generate optimization recommendations
  List<OptimizationRecommendation> generateRecommendations() {
    _recommendations.clear();

    if (_currentProfile == null) {
      return [];
    }

    final profile = _currentProfile!;

    // Bandwidth-based recommendations
    if (profile.condition == NetworkCondition.poor) {
      _recommendations.add(
        OptimizationRecommendation(
          id: 'reduce_quality',
          title: 'Reduce Quality',
          description: 'Lower sync data quality to reduce bandwidth',
          estimatedImprovement: 40,
          parameters: {
            'quality': 30,
            'compressionLevel': 'maximum',
            'batchSize': 10,
          },
        ),
      );
    }

    if (profile.condition == NetworkCondition.fair) {
      _recommendations.add(
        OptimizationRecommendation(
          id: 'defer_non_essential',
          title: 'Defer Non-Essential Syncs',
          description: 'Defer analytics and prefetch until better conditions',
          estimatedImprovement: 35,
          parameters: {
            'deferAnalytics': true,
            'deferPrefetch': true,
            'prioritizeCore': true,
          },
        ),
      );
    }

    // Latency-based recommendations
    if (profile.latency > 500) {
      _recommendations.add(
        OptimizationRecommendation(
          id: 'batch_operations',
          title: 'Batch Operations',
          description: 'Batch multiple operations to reduce round trips',
          estimatedImprovement: 30,
          parameters: {
            'batchSize': 50,
            'batchTimeout': 5000,
          },
        ),
      );
    }

    // Packet loss recommendations
    if (profile.packetLoss > 5) {
      _recommendations.add(
        OptimizationRecommendation(
          id: 'increase_retries',
          title: 'Increase Retry Logic',
          description: 'Enable aggressive retry and recovery',
          estimatedImprovement: 25,
          parameters: {
            'maxRetries': 5,
            'retryBackoffMs': 1000,
            'enableRedundancy': true,
          },
        ),
      );
    }

    _lastOptimization = DateTime.now();
    return _recommendations;
  }

  /// Apply optimization
  void applyOptimization(String recommendationId) {
    final recommendation =
        _recommendations.firstWhere((r) => r.id == recommendationId);

    _optimizationState.addAll(recommendation.parameters);
    _totalBandwidthSaved +=
        (recommendation.estimatedImprovement.toInt() * 1000);
  }

  /// Get network statistics
  Map<String, dynamic> getNetworkStatistics() {
    return {
      'profileCount': _networkProfiles.length,
      'currentCondition': _currentProfile?.condition.toString(),
      'averageBandwidth': _calculateAverageBandwidth(),
      'averageLatency': _calculateAverageLatency(),
      'averagePacketLoss': _calculateAveragePacketLoss(),
      'totalBandwidthUsed': _totalBandwidthUsed,
      'totalBandwidthSaved': _totalBandwidthSaved,
      'optimizationCount': _optimizationState.length,
    };
  }

  double _calculateAverageBandwidth() {
    if (_networkProfiles.isEmpty) return 0;
    return _networkProfiles.fold(0.0, (sum, p) => sum + p.bandwidth) /
        _networkProfiles.length;
  }

  double _calculateAverageLatency() {
    if (_networkProfiles.isEmpty) return 0;
    return _networkProfiles.fold(0.0, (sum, p) => sum + p.latency) /
        _networkProfiles.length;
  }

  double _calculateAveragePacketLoss() {
    if (_networkProfiles.isEmpty) return 0;
    return _networkProfiles.fold(0.0, (sum, p) => sum + p.packetLoss) /
        _networkProfiles.length;
  }

  /// Get optimization state
  Map<String, dynamic> getOptimizationState() {
    return Map.from(_optimizationState);
  }

  /// Get recent network profiles
  List<NetworkProfile> getRecentProfiles() {
    return _networkProfiles.take(100).toList();
  }

  /// Get network trend
  String getNetworkTrend() {
    if (_networkProfiles.length < 2) return 'stable';

    final recent = _networkProfiles.skip(_networkProfiles.length ~/ 2).toList();
    final old = _networkProfiles.take(_networkProfiles.length ~/ 2).toList();

    final recentAvg =
        recent.fold(0.0, (sum, p) => sum + p.bandwidth) / recent.length;
    final oldAvg =
        old.fold(0.0, (sum, p) => sum + p.bandwidth) / old.length;

    if (recentAvg > oldAvg * 1.2) {
      return 'improving';
    } else if (recentAvg < oldAvg * 0.8) {
      return 'degrading';
    } else {
      return 'stable';
    }
  }

  /// Estimate sync time
  int estimateSyncTime(int dataSize) {
    if (_currentProfile == null || _currentProfile!.bandwidth == 0) {
      return -1; // Cannot estimate
    }

    final megabits = dataSize / (1024 * 1024) * 8;
    final seconds = megabits / _currentProfile!.bandwidth;
    return (seconds * 1000).toInt();
  }

  /// Should defer sync
  bool shouldDeferSync() {
    if (_currentProfile == null) return false;
    return _currentProfile!.condition == NetworkCondition.poor ||
        _currentProfile!.condition == NetworkCondition.offline;
  }

  /// Export optimizer data as JSON
  String exportOptimizerDataAsJson() {
    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "currentProfile": ${_currentProfile != null ? _mapToJson(_currentProfile!.toMap()) : 'null'},
  "statistics": ${_mapToJson(getNetworkStatistics())},
  "recentProfiles": [
    ${_networkProfiles.take(20).map((p) => _mapToJson(p.toMap())).join(',\n    ')}
  ],
  "recommendations": [
    ${_recommendations.take(10).map((r) => _mapToJson(r.toMap())).join(',\n    ')}
  ],
  "networkTrend": "${getNetworkTrend()}"
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
        buffer.write('${entry.value}');
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

  /// Clear all data
  void clearData() {
    _networkProfiles.clear();
    _recommendations.clear();
    _optimizationState.clear();
  }
}
