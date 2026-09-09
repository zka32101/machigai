import 'package:flutter_test/flutter_test.dart';
import 'package:machigai/services/predictive_optimization_service.dart';
import 'package:machigai/services/network_adaptation_service.dart';
import 'package:machigai/services/device_optimization_service.dart';

void main() {
  group('Phase 7 Session 3: Predictive Optimization Tests', () {
    late PredictiveOptimizationService predictiveService;
    late NetworkAdaptationService networkService;
    late DeviceOptimizationService deviceService;

    setUp(() {
      predictiveService = PredictiveOptimizationService();
      networkService = NetworkAdaptationService();
      deviceService = DeviceOptimizationService();
    });

    group('PredictiveOptimizationService Tests', () {
      test('Records access history', () {
        predictiveService.recordAccess('key1');
        predictiveService.recordAccess('key2');
        predictiveService.recordAccess('key3');

        expect(predictiveService.isTrained, false);
      });

      test('Trains model successfully', () async {
        // Build access history
        for (int i = 0; i < 100; i++) {
          predictiveService.recordAccess('key${i % 10}');
        }

        final result = await predictiveService.trainModel();

        expect(result.modelId, isNotEmpty);
        expect(result.accuracy, greaterThan(0.0));
        expect(result.samplesUsed, 100);
        expect(predictiveService.isTrained, true);
      });

      test('Predicts next accesses', () async {
        // Build pattern: key1 → key2 → key3 → key1 (cycle)
        for (int i = 0; i < 50; i++) {
          predictiveService.recordAccess('key1');
          predictiveService.recordAccess('key2');
          predictiveService.recordAccess('key3');
        }

        await predictiveService.trainModel();

        final predictions = predictiveService.predictNextAccesses('key1', limit: 3);
        expect(predictions.isNotEmpty, true);
      });

      test('Calculates prediction accuracy', () async {
        for (int i = 0; i < 100; i++) {
          predictiveService.recordAccess('key${i % 5}');
        }

        await predictiveService.trainModel();

        predictiveService.recordPredictionResult('key1', true);
        predictiveService.recordPredictionResult('key2', false);
        predictiveService.recordPredictionResult('key3', true);

        expect(predictiveService.getPredictionAccuracy(), greaterThan(0.0));
      });

      test('Applies prefetch predictions', () async {
        for (int i = 0; i < 50; i++) {
          predictiveService.recordAccess('key1');
          predictiveService.recordAccess('key2');
        }

        await predictiveService.trainModel();

        final predictions = predictiveService.predictNextAccesses('key1');
        if (predictions.isNotEmpty) {
          predictiveService.applyPrefetch(predictions[0]);
        }

        expect(true, true); // Prefetch applied without error
      });

      test('Gets model status', () async {
        for (int i = 0; i < 50; i++) {
          predictiveService.recordAccess('key$i');
        }

        final status = predictiveService.getModelStatus();
        expect(status['sampleCount'], 50);
        expect(status['isTrained'], false);
      });

      test('Gets effectiveness metrics', () async {
        for (int i = 0; i < 100; i++) {
          predictiveService.recordAccess('key${i % 10}');
        }

        await predictiveService.trainModel();

        for (int i = 0; i < 10; i++) {
          predictiveService.recordPredictionResult('key$i', true);
        }

        final metrics = predictiveService.getEffectivenessMetrics();
        expect(metrics.containsKey('predictionAccuracy'), true);
        expect(metrics.containsKey('prefetchEfficiency'), true);
      });

      test('Exports predictions as JSON', () async {
        for (int i = 0; i < 50; i++) {
          predictiveService.recordAccess('key$i');
        }

        await predictiveService.trainModel();

        final json = predictiveService.exportPredictionsAsJson();
        expect(json.contains('modelStatus'), true);
        expect(json.contains('effectivenessMetrics'), true);
      });
    });

    group('NetworkAdaptationService Tests', () {
      test('Records network profiles', () {
        final profile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 50,
          bandwidthMbps: 10.0,
          packetLossPercent: 0.1,
          isOnline: true,
          signalStrength: 95,
          connectionType: 'WiFi',
        );

        networkService.recordNetworkProfile(profile);
        expect(networkService.getAllProfiles().length, 1);
      });

      test('Calculates network quality score', () {
        final goodProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 20,
          bandwidthMbps: 20.0,
          packetLossPercent: 0.0,
          isOnline: true,
          signalStrength: 100,
          connectionType: 'WiFi',
        );

        final goodScore = goodProfile.qualityScore;
        expect(goodScore, greaterThan(0.7));
      });

      test('Recommends aggressive strategy for poor network', () {
        final poorProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 500,
          bandwidthMbps: 1.0,
          packetLossPercent: 5.0,
          isOnline: true,
          signalStrength: 30,
          connectionType: '3G',
        );

        final recommendation = networkService.analyzeAndAdapt(poorProfile);
        expect(recommendation.strategy, NetworkAdaptationStrategy.aggressive);
        expect(recommendation.compressionLevel, greaterThan(5));
      });

      test('Recommends conservative strategy for good network', () {
        final goodProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 10,
          bandwidthMbps: 50.0,
          packetLossPercent: 0.0,
          isOnline: true,
          signalStrength: 100,
          connectionType: 'WiFi',
        );

        final recommendation = networkService.analyzeAndAdapt(goodProfile);
        expect(recommendation.strategy, NetworkAdaptationStrategy.conservative);
      });

      test('Detects offline status', () {
        final offlineProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 0,
          bandwidthMbps: 0.0,
          packetLossPercent: 0.0,
          isOnline: false,
          signalStrength: 0,
          connectionType: 'None',
        );

        final recommendation = networkService.analyzeAndAdapt(offlineProfile);
        expect(recommendation.enableOfflineMode, true);
        expect(recommendation.compressionLevel, 9);
      });

      test('Detects network trend', () {
        // Add improving profiles
        for (int i = 0; i < 10; i++) {
          final profile = NetworkProfile(
            recordedAt: DateTime.now(),
            latencyMs: 100 - (i * 5),
            bandwidthMbps: 5.0 + (i * 0.5),
            packetLossPercent: 1.0 - (i * 0.05),
            isOnline: true,
            signalStrength: 50 + (i * 3),
            connectionType: '4G',
          );
          networkService.recordNetworkProfile(profile);
        }

        final trend = networkService.getNetworkTrend();
        expect(['improving', 'stable'].contains(trend), true);
      });

      test('Gets network statistics', () {
        for (int i = 0; i < 5; i++) {
          final profile = NetworkProfile(
            recordedAt: DateTime.now(),
            latencyMs: 30,
            bandwidthMbps: 15.0,
            packetLossPercent: 0.2,
            isOnline: true,
            signalStrength: 90,
            connectionType: 'WiFi',
          );
          networkService.recordNetworkProfile(profile);
        }

        final stats = networkService.getNetworkStatistics();
        expect(stats.containsKey('profileCount'), true);
        expect(stats.containsKey('trend'), true);
      });

      test('Exports adaptation data as JSON', () {
        final profile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 50,
          bandwidthMbps: 10.0,
          packetLossPercent: 0.1,
          isOnline: true,
          signalStrength: 90,
          connectionType: 'WiFi',
        );

        networkService.recordNetworkProfile(profile);
        final json = networkService.exportAdaptationDataAsJson();

        expect(json.contains('currentStrategy'), true);
        expect(json.contains('statistics'), true);
      });
    });

    group('DeviceOptimizationService Tests', () {
      test('Registers device capabilities', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 4096,
          storageMb: 64000,
          cpuCores: 6.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        expect(deviceService.getAllDevices().length, 1);
      });

      test('Calculates device capability score', () {
        final highEndCaps = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 8000,
          storageMb: 256000,
          cpuCores: 8.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );

        expect(highEndCaps.capabilityScore, greaterThan(0.7));
      });

      test('Generates optimized profile for low-end device', () {
        final lowEndCaps = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'Android',
          ramMb: 1024,
          storageMb: 16000,
          cpuCores: 2.0,
          gpuType: 'Mali',
          hasNfc: false,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(lowEndCaps);
        final profile = deviceService.getCurrentOptimizationProfile();

        expect(profile, isNotNull);
        expect(profile!.enableGpuAcceleration, false);
        expect(profile.maxConcurrentOperations, lessThan(8));
      });

      test('Generates optimized profile for high-end device', () {
        final highEndCaps = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 8000,
          storageMb: 256000,
          cpuCores: 8.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(highEndCaps);
        final profile = deviceService.getCurrentOptimizationProfile();

        expect(profile, isNotNull);
        expect(profile!.enableGpuAcceleration, true);
        expect(profile.targetFramerate, 60.0);
      });

      test('Updates and detects memory pressure', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 2048,
          storageMb: 32000,
          cpuCores: 4.0,
          gpuType: 'Mali',
          hasNfc: false,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        deviceService.updatePerformanceMetrics(
          'device_1',
          memoryUsage: 90,
          cpuUsage: 50,
          thermicLoad: 40,
        );

        expect(deviceService.isUnderMemoryPressure('device_1'), true);
      });

      test('Detects thermal stress', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'Android',
          ramMb: 4096,
          storageMb: 64000,
          cpuCores: 6.0,
          gpuType: 'Adreno',
          hasNfc: true,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        deviceService.updatePerformanceMetrics(
          'device_1',
          memoryUsage: 50,
          cpuUsage: 50,
          thermicLoad: 85,
        );

        expect(deviceService.isUnderThermalStress('device_1'), true);
      });

      test('Generates optimization recommendations', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'Android',
          ramMb: 1024,
          storageMb: 8000,
          cpuCores: 2.0,
          gpuType: 'None',
          hasNfc: false,
          hasBluetooth: false,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        deviceService.updatePerformanceMetrics(
          'device_1',
          memoryUsage: 95,
          cpuUsage: 95,
          thermicLoad: 90,
        );

        final recommendations = deviceService.getOptimizationRecommendations('device_1');
        expect(recommendations.isNotEmpty, true);
      });

      test('Gets device statistics', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 4096,
          storageMb: 64000,
          cpuCores: 6.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        final stats = deviceService.getDeviceStatistics('device_1');

        expect(stats.containsKey('deviceId'), true);
        expect(stats.containsKey('capabilities'), true);
      });

      test('Exports optimization data as JSON', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 4096,
          storageMb: 64000,
          cpuCores: 6.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);
        final json = deviceService.exportOptimizationDataAsJson();

        expect(json.contains('devices'), true);
        expect(json.contains('registeredDevices'), true);
      });
    });

    group('Integration Tests: Predictive + Network + Device', () {
      test('Full optimization workflow', () async {
        // Register device
        final deviceCaps = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 4096,
          storageMb: 64000,
          cpuCores: 6.0,
          gpuType: 'Apple Neural',
          hasNfc: true,
          hasBluetooth: true,
        );
        deviceService.registerDeviceCapabilities(deviceCaps);

        // Record network profile
        final networkProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 30,
          bandwidthMbps: 20.0,
          packetLossPercent: 0.1,
          isOnline: true,
          signalStrength: 90,
          connectionType: 'WiFi',
        );
        final recommendation = networkService.analyzeAndAdapt(networkProfile);

        // Train predictive model
        for (int i = 0; i < 100; i++) {
          predictiveService.recordAccess('key${i % 10}');
        }
        await predictiveService.trainModel();

        // Verify all services working
        expect(deviceService.getAllDevices().isNotEmpty, true);
        expect(recommendation.strategy, isNotNull);
        expect(predictiveService.isTrained, true);
      });

      test('Network degradation triggers optimization', () async {
        // Train with good network
        final goodProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 10,
          bandwidthMbps: 50.0,
          packetLossPercent: 0.0,
          isOnline: true,
          signalStrength: 100,
          connectionType: 'WiFi',
        );

        var recommendation = networkService.analyzeAndAdapt(goodProfile);
        expect(recommendation.strategy, NetworkAdaptationStrategy.conservative);

        // Simulate network degradation
        final poorProfile = NetworkProfile(
          recordedAt: DateTime.now(),
          latencyMs: 200,
          bandwidthMbps: 2.0,
          packetLossPercent: 5.0,
          isOnline: true,
          signalStrength: 30,
          connectionType: '3G',
        );

        recommendation = networkService.analyzeAndAdapt(poorProfile);
        expect(recommendation.strategy, NetworkAdaptationStrategy.aggressive);
        expect(recommendation.compressionLevel, greaterThan(5));
      });

      test('Device pressure adjusts optimization settings', () {
        final capabilities = DeviceCapabilities(
          deviceId: 'device_1',
          platform: 'iOS',
          ramMb: 2048,
          storageMb: 32000,
          cpuCores: 4.0,
          gpuType: 'Mali',
          hasNfc: false,
          hasBluetooth: true,
        );

        deviceService.registerDeviceCapabilities(capabilities);

        // Normal load
        deviceService.updatePerformanceMetrics(
          'device_1',
          memoryUsage: 50,
          cpuUsage: 50,
          thermicLoad: 40,
        );

        var recommendations = deviceService.getOptimizationRecommendations('device_1');
        final normalCount = recommendations.length;

        // High load
        deviceService.updatePerformanceMetrics(
          'device_1',
          memoryUsage: 95,
          cpuUsage: 95,
          thermicLoad: 95,
        );

        recommendations = deviceService.getOptimizationRecommendations('device_1');
        expect(recommendations.length, greaterThan(normalCount));
      });
    });

    tearDown(() {
      predictiveService.clearModel();
      networkService.clearHistory();
      deviceService.clearData();
    });
  });
}
