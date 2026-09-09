/// Device capability profile
class DeviceCapabilities {
  final String deviceId;
  final String platform; // iOS, Android, Web
  final int ramMb;
  final int storageMb;
  final double cpuCores;
  final String gpuType; // Mali, Adreno, Apple Neural, None
  final bool hasNfc;
  final bool hasBluetooth;

  DeviceCapabilities({
    required this.deviceId,
    required this.platform,
    required this.ramMb,
    required this.storageMb,
    required this.cpuCores,
    required this.gpuType,
    required this.hasNfc,
    required this.hasBluetooth,
  });

  /// Get device capability score (0.0-1.0)
  double get capabilityScore {
    double score = 0.0;

    // RAM score (0-8GB)
    score += (ramMb / 8000).clamp(0.0, 1.0) * 0.25;

    // Storage score (0-256GB)
    score += (storageMb / 256000).clamp(0.0, 1.0) * 0.25;

    // CPU score
    score += (cpuCores / 8).clamp(0.0, 1.0) * 0.25;

    // GPU/Features score
    score += (gpuType != 'None' ? 1.0 : 0.5) * 0.1;
    score += ((hasNfc ? 1 : 0) + (hasBluetooth ? 1 : 0)) / 2 * 0.1;

    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'platform': platform,
    'ramMb': ramMb,
    'storageMb': storageMb,
    'cpuCores': cpuCores.toStringAsFixed(1),
    'gpuType': gpuType,
    'hasNfc': hasNfc,
    'hasBluetooth': hasBluetooth,
    'capabilityScore': capabilityScore.toStringAsFixed(2),
  };
}

/// Device optimization profile
class OptimizedProfile {
  final String deviceId;
  final int maxConcurrentOperations;
  final int cacheSizeMb;
  final Duration minCompressionThreshold;
  final int maxThreadPoolSize;
  final Duration animationDuration;
  final double targetFramerate;
  final bool enableGpuAcceleration;
  final bool enableBackgroundOptimization;

  OptimizedProfile({
    required this.deviceId,
    required this.maxConcurrentOperations,
    required this.cacheSizeMb,
    required this.minCompressionThreshold,
    required this.maxThreadPoolSize,
    required this.animationDuration,
    required this.targetFramerate,
    required this.enableGpuAcceleration,
    required this.enableBackgroundOptimization,
  });

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'maxConcurrentOperations': maxConcurrentOperations,
    'cacheSizeMb': cacheSizeMb,
    'minCompressionThresholdMs': minCompressionThreshold.inMilliseconds,
    'maxThreadPoolSize': maxThreadPoolSize,
    'animationDurationMs': animationDuration.inMilliseconds,
    'targetFramerate': targetFramerate.toStringAsFixed(1),
    'enableGpuAcceleration': enableGpuAcceleration,
    'enableBackgroundOptimization': enableBackgroundOptimization,
  };
}

/// Device optimization service for hardware-specific tuning
class DeviceOptimizationService {
  static final DeviceOptimizationService _instance =
      DeviceOptimizationService._internal();

  factory DeviceOptimizationService() {
    return _instance;
  }

  DeviceOptimizationService._internal();

  final Map<String, DeviceCapabilities> _deviceCapabilities = {};
  final Map<String, OptimizedProfile> _optimizedProfiles = {};
  final Map<String, Map<String, int>> _performanceMetrics = {};
  String? _currentDeviceId;

  /// Register device capabilities
  void registerDeviceCapabilities(DeviceCapabilities capabilities) {
    _deviceCapabilities[capabilities.deviceId] = capabilities;
    _currentDeviceId = capabilities.deviceId;

    // Generate optimized profile
    final profile = _generateOptimizedProfile(capabilities);
    _optimizedProfiles[capabilities.deviceId] = profile;

    // Initialize metrics
    _performanceMetrics[capabilities.deviceId] = {
      'memoryUsage': 0,
      'cpuUsage': 0,
      'thermicLoad': 0,
    };
  }

  /// Generate optimized profile for device
  OptimizedProfile _generateOptimizedProfile(DeviceCapabilities caps) {
    // Scale operations based on RAM
    final maxOps = (caps.ramMb / 512).toInt().clamp(2, 16);

    // Scale cache based on available storage
    final cacheSize = (caps.storageMb * 0.1).toInt().clamp(50, 2000);

    // Thread pool based on CPU cores
    final threadPoolSize = (caps.cpuCores).toInt().clamp(2, 8);

    // Animation duration based on capability
    final animSpeed = caps.capabilityScore > 0.7
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 500);

    // Target framerate based on GPU
    final fps = caps.gpuType == 'None' ? 30.0 : 60.0;

    // GPU acceleration only on high-end devices
    final useGpu = caps.capabilityScore > 0.6;

    return OptimizedProfile(
      deviceId: caps.deviceId,
      maxConcurrentOperations: maxOps,
      cacheSizeMb: cacheSize,
      minCompressionThreshold: const Duration(milliseconds: 100),
      maxThreadPoolSize: threadPoolSize,
      animationDuration: animSpeed,
      targetFramerate: fps,
      enableGpuAcceleration: useGpu,
      enableBackgroundOptimization: caps.capabilityScore > 0.5,
    );
  }

  /// Update device performance metrics
  void updatePerformanceMetrics(
    String deviceId, {
    required int memoryUsage,
    required int cpuUsage,
    required int thermicLoad,
  }) {
    if (!_performanceMetrics.containsKey(deviceId)) {
      _performanceMetrics[deviceId] = {};
    }

    _performanceMetrics[deviceId]!.addAll({
      'memoryUsage': memoryUsage,
      'cpuUsage': cpuUsage,
      'thermicLoad': thermicLoad,
    });
  }

  /// Get current device optimization profile
  OptimizedProfile? getCurrentOptimizationProfile() {
    if (_currentDeviceId == null) return null;
    return _optimizedProfiles[_currentDeviceId];
  }

  /// Get device capabilities
  DeviceCapabilities? getDeviceCapabilities(String deviceId) {
    return _deviceCapabilities[deviceId];
  }

  /// Get performance metrics
  Map<String, int>? getPerformanceMetrics(String deviceId) {
    return _performanceMetrics[deviceId];
  }

  /// Check if device is under thermal stress
  bool isUnderThermalStress(String deviceId) {
    final metrics = _performanceMetrics[deviceId];
    if (metrics == null) return false;
    return (metrics['thermicLoad'] ?? 0) > 80;
  }

  /// Check if device is under memory pressure
  bool isUnderMemoryPressure(String deviceId) {
    final metrics = _performanceMetrics[deviceId];
    if (metrics == null) return false;
    return (metrics['memoryUsage'] ?? 0) > 85;
  }

  /// Check if device is under CPU pressure
  bool isUnderCpuPressure(String deviceId) {
    final metrics = _performanceMetrics[deviceId];
    if (metrics == null) return false;
    return (metrics['cpuUsage'] ?? 0) > 90;
  }

  /// Get device optimization recommendations
  List<String> getOptimizationRecommendations(String deviceId) {
    final recommendations = <String>[];
    final caps = _deviceCapabilities[deviceId];
    final metrics = _performanceMetrics[deviceId];

    if (caps == null || metrics == null) return recommendations;

    // Memory recommendations
    if (isUnderMemoryPressure(deviceId)) {
      recommendations.add('Reduce cache size to save memory');
      recommendations.add('Disable background optimization');
    }

    // CPU recommendations
    if (isUnderCpuPressure(deviceId)) {
      recommendations.add('Reduce max concurrent operations');
      recommendations.add('Increase task scheduling intervals');
    }

    // Thermal recommendations
    if (isUnderThermalStress(deviceId)) {
      recommendations.add('Disable GPU acceleration temporarily');
      recommendations.add('Reduce animation frame rates');
      recommendations.add('Defer non-critical operations');
    }

    // Storage recommendations
    if (caps.storageMb < 1000) {
      recommendations.add('Enable aggressive compression');
      recommendations.add('Enable automatic cache cleanup');
    }

    // Low-end device recommendations
    if (caps.capabilityScore < 0.5) {
      recommendations.add('Keep GPU acceleration disabled');
      recommendations.add('Use simpler animations');
      recommendations.add('Reduce prefetch operations');
    }

    return recommendations;
  }

  /// Get device statistics
  Map<String, dynamic> getDeviceStatistics(String deviceId) {
    final caps = _deviceCapabilities[deviceId];
    final profile = _optimizedProfiles[deviceId];
    final metrics = _performanceMetrics[deviceId];

    return {
      'deviceId': deviceId,
      'capabilities': caps?.toMap(),
      'optimizedProfile': profile?.toMap(),
      'currentMetrics': metrics,
      'memoryPressure': isUnderMemoryPressure(deviceId),
      'cpuPressure': isUnderCpuPressure(deviceId),
      'thermalStress': isUnderThermalStress(deviceId),
    };
  }

  /// Get all registered devices
  List<String> getAllDevices() => List.from(_deviceCapabilities.keys);

  /// Clear all data
  void clearData() {
    _deviceCapabilities.clear();
    _optimizedProfiles.clear();
    _performanceMetrics.clear();
    _currentDeviceId = null;
  }

  /// Export optimization data as JSON
  String exportOptimizationDataAsJson() {
    final allDevices = <String, dynamic>{};

    for (final deviceId in _deviceCapabilities.keys) {
      final caps = _deviceCapabilities[deviceId];
      final profile = _optimizedProfiles[deviceId];
      final stats = getDeviceStatistics(deviceId);

      allDevices[deviceId] = {
        'capabilities': caps?.toMap(),
        'optimizedProfile': profile?.toMap(),
        'recommendations': getOptimizationRecommendations(deviceId),
        'statistics': stats,
      };
    }

    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "registeredDevices": ${_deviceCapabilities.length},
  "currentDevice": "$_currentDeviceId",
  "devices": ${_mapToJson(allDevices)}
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

  /// Get current device ID
  String? get currentDeviceId => _currentDeviceId;
}
