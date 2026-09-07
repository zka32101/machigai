import 'package:flutter_test/flutter_test.dart';
import 'package:machigai/services/incremental_sync_service.dart';
import 'package:machigai/services/compression_service.dart';
import 'package:machigai/services/bandwidth_optimizer.dart';

void main() {
  group('Phase 7 Session 1: Incremental Sync & Compression', () {
    late IncrementalSyncService incrementalSync;
    late CompressionService compression;
    late BandwidthOptimizer bandwidthOptimizer;

    setUp(() {
      incrementalSync = IncrementalSyncService();
      compression = CompressionService();
      bandwidthOptimizer = BandwidthOptimizer();
    });

    group('Incremental Sync Service Tests', () {
      test('Record single delta', () {
        final delta = DataDelta(
          id: 'delta_1',
          dataType: 'challenge',
          operation: 'create',
          newValue: {'title': 'New Challenge'},
          timestamp: DateTime.now(),
          estimatedSize: 256,
        );

        incrementalSync.recordDelta(delta);

        expect(incrementalSync.getPendingDeltasCount(), 1);
      });

      test('Record multiple deltas', () {
        for (int i = 0; i < 5; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'update',
              fieldPath: 'title',
              oldValue: 'Old $i',
              newValue: 'New $i',
              timestamp: DateTime.now(),
              estimatedSize: 100,
            ),
          );
        }

        expect(incrementalSync.getPendingDeltasCount(), 5);
      });

      test('Get deltas by type', () {
        incrementalSync.recordDelta(
          DataDelta(
            id: 'challenge_1',
            dataType: 'challenge',
            operation: 'create',
            newValue: {},
            timestamp: DateTime.now(),
            estimatedSize: 100,
          ),
        );

        incrementalSync.recordDelta(
          DataDelta(
            id: 'user_1',
            dataType: 'user',
            operation: 'update',
            fieldPath: 'name',
            oldValue: 'Old',
            newValue: 'New',
            timestamp: DateTime.now(),
            estimatedSize: 50,
          ),
        );

        final challengeDeltas =
            incrementalSync.getDeltasByType('challenge');
        expect(challengeDeltas.length, 1);
        expect(challengeDeltas[0].dataType, 'challenge');
      });

      test('Calculate estimated sync size', () {
        for (int i = 0; i < 3; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'create',
              newValue: {},
              timestamp: DateTime.now(),
              estimatedSize: 1000,
            ),
          );
        }

        final estimatedSize = incrementalSync.calculateEstimatedSyncSize();
        expect(estimatedSize, 3000);
      });

      test('Estimate bandwidth savings', () {
        for (int i = 0; i < 5; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'update',
              fieldPath: 'status',
              newValue: 'completed',
              timestamp: DateTime.now(),
              estimatedSize: 500,
            ),
          );
        }

        final savings = incrementalSync.estimateBandwidthSavings();
        expect(savings, greaterThan(0));
        expect(savings, greaterThan(2500 * 5)); // 5x delta size
      });

      test('Create and retrieve sync checkpoint', () {
        final checkpoint = incrementalSync.createCheckpoint(
          'device_1',
          ['sync_1', 'sync_2'],
          10,
          8,
          2,
        );

        expect(checkpoint.successRate, 80.0);

        final retrieved = incrementalSync.getCheckpoint('device_1');
        expect(retrieved, isNotNull);
        expect(retrieved?.successRate, 80.0);
      });

      test('Mark deltas as synced', () {
        incrementalSync.recordDelta(
          DataDelta(
            id: 'delta_1',
            dataType: 'challenge',
            operation: 'create',
            newValue: {},
            timestamp: DateTime.now(),
            estimatedSize: 100,
          ),
        );

        expect(incrementalSync.getPendingDeltasCount(), 1);

        incrementalSync.markDeltasAsSynced(['delta_1']);
        expect(incrementalSync.getPendingDeltasCount(), 0);
      });

      test('Get incremental sync statistics', () {
        for (int i = 0; i < 3; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'create',
              newValue: {},
              timestamp: DateTime.now(),
              estimatedSize: 100,
            ),
          );
        }

        final stats = incrementalSync.getIncrementalSyncStats();
        expect(stats.containsKey('totalDeltas'), true);
        expect(stats.containsKey('pendingDeltas'), true);
        expect(stats['totalDeltas'], 3);
      });

      test('Export deltas as JSON', () {
        incrementalSync.recordDelta(
          DataDelta(
            id: 'delta_1',
            dataType: 'challenge',
            operation: 'create',
            newValue: {},
            timestamp: DateTime.now(),
            estimatedSize: 100,
          ),
        );

        final json = incrementalSync.exportDeltasAsJson();
        expect(json.contains('totalDeltas'), true);
        expect(json.contains('timestamp'), true);
      });
    });

    group('Compression Service Tests', () {
      test('Compress string with DEFLATE', () {
        final original =
            'This is a test string that should be compressed' * 10;

        final result = compression.compress(
          'test_1',
          original,
          algorithm: CompressionAlgorithm.deflate,
          level: CompressionLevel.balanced,
        );

        expect(result.originalSize, greaterThan(0));
        expect(result.compressedSize, greaterThan(0));
      });

      test('Calculate compression ratio', () {
        final original = 'AAAAAABBBBBBCCCCCCDDDDDD';

        final result = compression.compress(
          'test_2',
          original,
          algorithm: CompressionAlgorithm.rle,
        );

        expect(result.compressionRatio, lessThan(100));
      });

      test('Verify compression efficiency', () {
        final original = 'Repetitive repetitive repetitive pattern pattern' * 5;

        final result = compression.compress(
          'test_3',
          original,
          algorithm: CompressionAlgorithm.deflate,
          level: CompressionLevel.optimal,
        );

        expect(result.wasWorthwhile, true);
        expect(result.efficiency, greaterThan(10));
      });

      test('Decompress data correctly', () {
        final original = 'Test data to compress and decompress';

        compression.compress(
          'test_4',
          original,
          algorithm: CompressionAlgorithm.deflate,
        );

        final decompressed =
            compression.decompress('test_4', CompressionAlgorithm.deflate);

        expect(decompressed, original);
      });

      test('Compare compression algorithms', () {
        final original =
            'This is test data' * 20; // Repetitive data

        final deflateResult = compression.compress(
          'deflate_test',
          original,
          algorithm: CompressionAlgorithm.deflate,
        );

        final rleResult = compression.compress(
          'rle_test',
          original,
          algorithm: CompressionAlgorithm.rle,
        );

        // Both should compress, but algorithms differ
        expect(deflateResult.compressedSize, greaterThan(0));
        expect(rleResult.compressedSize, greaterThan(0));
      });

      test('Get compression statistics', () {
        compression.compress(
          'stat_1',
          'Test data 1',
          algorithm: CompressionAlgorithm.deflate,
        );

        compression.compress(
          'stat_2',
          'Test data 2' * 5,
          algorithm: CompressionAlgorithm.rle,
        );

        final stats = compression.getCompressionStats();
        expect(stats['totalCompressions'], 2);
        expect(stats.containsKey('averageCompressionRatio'), true);
      });

      test('Recommend algorithm for data type', () {
        final textAlgo =
            compression.recommendAlgorithm('text');
        expect(textAlgo, CompressionAlgorithm.deflate);

        final binaryAlgo =
            compression.recommendAlgorithm('binary');
        expect(binaryAlgo, CompressionAlgorithm.lz77);

        final repetitiveAlgo =
            compression.recommendAlgorithm('repetitive');
        expect(repetitiveAlgo, CompressionAlgorithm.rle);
      });

      test('Export compression data as JSON', () {
        compression.compress(
          'export_test',
          'Test data for export',
          algorithm: CompressionAlgorithm.deflate,
        );

        final json = compression.exportCompressionDataAsJson();
        expect(json.contains('timestamp'), true);
        expect(json.contains('statistics'), true);
      });
    });

    group('Bandwidth Optimizer Tests', () {
      test('Record network profile', () {
        final profile = NetworkProfile(
          id: 'profile_1',
          condition: NetworkCondition.good,
          bandwidth: 8.5,
          latency: 50.0,
          packetLoss: 0.5,
        );

        bandwidthOptimizer.recordNetworkProfile(profile);

        expect(bandwidthOptimizer.getCurrentCondition(),
            NetworkCondition.good);
      });

      test('Detect network conditions', () {
        expect(
          bandwidthOptimizer.detectNetworkCondition(
            bandwidth: 15.0,
            latency: 30.0,
            packetLoss: 0.1,
          ),
          NetworkCondition.excellent,
        );

        expect(
          bandwidthOptimizer.detectNetworkCondition(
            bandwidth: 0.5,
            latency: 200.0,
            packetLoss: 10.0,
          ),
          NetworkCondition.poor,
        );
      });

      test('Generate optimization recommendations', () {
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'poor_network',
            condition: NetworkCondition.poor,
            bandwidth: 0.5,
            latency: 500.0,
            packetLoss: 5.0,
          ),
        );

        final recommendations =
            bandwidthOptimizer.generateRecommendations();

        expect(recommendations.isNotEmpty, true);
        expect(
          recommendations.any((r) => r.id.contains('quality')),
          true,
        );
      });

      test('Apply optimization', () {
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'fair_network',
            condition: NetworkCondition.fair,
            bandwidth: 3.0,
            latency: 100.0,
            packetLoss: 2.0,
          ),
        );

        final recommendations =
            bandwidthOptimizer.generateRecommendations();
        if (recommendations.isNotEmpty) {
          bandwidthOptimizer.applyOptimization(recommendations[0].id);

          final state = bandwidthOptimizer.getOptimizationState();
          expect(state.isNotEmpty, true);
        }
      });

      test('Get network statistics', () {
        for (int i = 0; i < 5; i++) {
          bandwidthOptimizer.recordNetworkProfile(
            NetworkProfile(
              id: 'profile_$i',
              condition: NetworkCondition.good,
              bandwidth: 7.0 + i,
              latency: 50.0 + i * 10,
              packetLoss: 0.5 + i * 0.1,
            ),
          );
        }

        final stats = bandwidthOptimizer.getNetworkStatistics();
        expect(stats['profileCount'], 5);
        expect(stats.containsKey('averageBandwidth'), true);
      });

      test('Estimate sync time', () {
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'good_network',
            condition: NetworkCondition.good,
            bandwidth: 5.0,
            latency: 75.0,
            packetLoss: 0.5,
          ),
        );

        final estimatedMs = bandwidthOptimizer.estimateSyncTime(1024 * 1024);
        expect(estimatedMs, greaterThan(0));
      });

      test('Should defer sync', () {
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'offline',
            condition: NetworkCondition.offline,
            bandwidth: 0.0,
            latency: 0.0,
            packetLoss: 100.0,
          ),
        );

        expect(bandwidthOptimizer.shouldDeferSync(), true);
      });

      test('Get network trend', () {
        for (int i = 0; i < 10; i++) {
          bandwidthOptimizer.recordNetworkProfile(
            NetworkProfile(
              id: 'trend_$i',
              condition: NetworkCondition.good,
              bandwidth: 5.0 + (i * 0.5),
              latency: 50.0,
              packetLoss: 0.5,
            ),
          );
        }

        final trend = bandwidthOptimizer.getNetworkTrend();
        expect(
          ['improving', 'degrading', 'stable'],
          contains(trend),
        );
      });

      test('Export optimizer data as JSON', () {
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'export_test',
            condition: NetworkCondition.good,
            bandwidth: 7.5,
            latency: 60.0,
            packetLoss: 0.5,
          ),
        );

        final json = bandwidthOptimizer.exportOptimizerDataAsJson();
        expect(json.contains('timestamp'), true);
        expect(json.contains('statistics'), true);
      });
    });

    group('Integration Tests', () {
      test('Complete incremental sync workflow', () {
        // Record deltas
        for (int i = 0; i < 5; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'update',
              fieldPath: 'status',
              newValue: 'synced',
              timestamp: DateTime.now(),
              estimatedSize: 100,
            ),
          );
        }

        expect(incrementalSync.getPendingDeltasCount(), 5);

        // Create checkpoint
        final checkpoint = incrementalSync.createCheckpoint(
          'device_1',
          ['delta_0', 'delta_1'],
          5,
          2,
          3,
        );

        expect(checkpoint.successRate, lessThan(100));

        // Mark as synced
        incrementalSync.markDeltasAsSynced(['delta_0', 'delta_1']);
        expect(incrementalSync.getPendingDeltasCount(), 3);
      });

      test('Compression with bandwidth optimization', () {
        // Simulate poor network
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'poor',
            condition: NetworkCondition.poor,
            bandwidth: 0.5,
            latency: 500.0,
            packetLoss: 10.0,
          ),
        );

        final recommendations =
            bandwidthOptimizer.generateRecommendations();

        // Compress data with recommended level
        final testData = 'Important data' * 100;
        final result = compression.compress(
          'integrated_test',
          testData,
          algorithm: CompressionAlgorithm.deflate,
          level: CompressionLevel.maximum,
        );

        expect(result.wasWorthwhile, true);
      });

      test('End-to-end incremental sync and compression', () {
        // Record changes
        for (int i = 0; i < 10; i++) {
          incrementalSync.recordDelta(
            DataDelta(
              id: 'delta_$i',
              dataType: 'challenge',
              operation: 'update',
              newValue: {'status': 'changed_$i'},
              timestamp: DateTime.now(),
              estimatedSize: 500,
            ),
          );
        }

        // Monitor network
        bandwidthOptimizer.recordNetworkProfile(
          NetworkProfile(
            id: 'monitoring',
            condition: NetworkCondition.fair,
            bandwidth: 2.5,
            latency: 150.0,
            packetLoss: 3.0,
          ),
        );

        // Get optimization recommendations
        final recommendations =
            bandwidthOptimizer.generateRecommendations();

        // Compress the sync payload
        final syncSize = incrementalSync.calculateEstimatedSyncSize();
        final syncSavings = incrementalSync.estimateBandwidthSavings();

        expect(syncSize, greaterThan(0));
        expect(syncSavings, greaterThan(0));
        expect(recommendations.isNotEmpty, true);
      });
    });

    tearDown(() {
      incrementalSync.clearAllDeltas();
      compression.clearHistory();
      bandwidthOptimizer.clearData();
    });
  });
}
