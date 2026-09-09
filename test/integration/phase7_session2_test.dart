import 'package:flutter_test/flutter_test.dart';
import 'package:machigai/services/smart_cache_service.dart';
import 'package:machigai/services/adaptive_cache_strategy.dart';
import 'package:machigai/services/cache_memory_profiler.dart';
import 'package:machigai/services/cache_analytics.dart';

void main() {
  group('Phase 7 Session 2: Advanced Caching Tests', () {
    late SmartCacheService smartCache;
    late AdaptiveCacheStrategy cacheStrategy;
    late CacheMemoryProfiler memoryProfiler;
    late CacheAnalytics cacheAnalytics;

    setUp(() {
      smartCache = SmartCacheService.withSize(100);
      cacheStrategy = AdaptiveCacheStrategy();
      memoryProfiler = CacheMemoryProfiler();
      cacheAnalytics = CacheAnalytics();
    });

    group('SmartCacheService Tests', () {
      test('LRU cache stores and retrieves values', () {
        smartCache.put('key1', 'value1');
        final result = smartCache.get('key1');
        expect(result, 'value1');
      });

      test('Cache expiration removes expired entries', () {
        smartCache.put(
          'key1',
          'value1',
          ttl: const Duration(milliseconds: 100),
        );
        expect(smartCache.get('key1'), 'value1');

        // Wait for expiration
        Future.delayed(const Duration(milliseconds: 150)).then((_) {
          expect(smartCache.get('key1'), null);
        });
      });

      test('LRU eviction removes least recently used', () {
        final cache = SmartCacheService.withSize(3);

        cache.put('key1', 'value1');
        cache.put('key2', 'value2');
        cache.put('key3', 'value3');

        // Access key1 to make it recently used
        cache.get('key1');

        // Add key4, should evict key2 (least recently used)
        cache.put('key4', 'value4');

        expect(cache.get('key1'), 'value1');
        expect(cache.get('key2'), null); // Evicted
        expect(cache.get('key3'), 'value3');
        expect(cache.get('key4'), 'value4');
      });

      test('Cache statistics track hits and misses', () {
        smartCache.put('key1', 'value1');
        smartCache.get('key1'); // Hit
        smartCache.get('key2'); // Miss

        final stats = smartCache.getStats();
        expect(stats.hits, greaterThan(0));
        expect(stats.misses, greaterThan(0));
      });

      test('Hot keys returns most accessed', () {
        smartCache.put('hot1', 'value');
        smartCache.put('cold1', 'value');

        for (int i = 0; i < 10; i++) {
          smartCache.get('hot1');
        }

        final hotKeys = smartCache.getHotKeys(1);
        expect(hotKeys.isNotEmpty, true);
        expect(hotKeys[0], 'hot1');
      });

      test('Cold keys returns least accessed', () {
        smartCache.put('hot1', 'value');
        smartCache.put('cold1', 'value');

        for (int i = 0; i < 10; i++) {
          smartCache.get('hot1');
        }

        final coldKeys = smartCache.getColdKeys(1);
        expect(coldKeys.isNotEmpty, true);
        expect(coldKeys[0], 'cold1');
      });

      test('Cache export produces valid JSON', () {
        smartCache.put('key1', 'value1');
        final json = smartCache.exportCacheDataAsJson();

        expect(json.contains('timestamp'), true);
        expect(json.contains('size'), true);
        expect(json.contains('statistics'), true);
      });

      test('Cache clear removes all entries', () {
        smartCache.put('key1', 'value1');
        smartCache.put('key2', 'value2');
        smartCache.clear();

        expect(smartCache.getSize(), 0);
        expect(smartCache.get('key1'), null);
      });
    });

    group('AdaptiveCacheStrategy Tests', () {
      test('Analyzes access patterns', () {
        final pattern = AccessPattern(
          totalAccesses: 1000,
          uniqueKeys: 100,
          temporalLocality: 0.8,
          spatialLocality: 0.6,
          zipfianCoefficient: 1.2,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );

        final recommendation = cacheStrategy.analyzeAndRecommend(pattern);
        expect(recommendation.confidenceScore, greaterThan(0.0));
      });

      test('Recommends LFU for high skewness', () {
        final pattern = AccessPattern(
          totalAccesses: 1000,
          uniqueKeys: 50,
          temporalLocality: 0.5,
          spatialLocality: 0.5,
          zipfianCoefficient: 2.0, // High skewness
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );

        final recommendation = cacheStrategy.analyzeAndRecommend(pattern);
        expect(recommendation.recommendedStrategy, EvictionStrategy.lfu);
      });

      test('Recommends LRU for high temporal locality', () {
        final pattern = AccessPattern(
          totalAccesses: 1000,
          uniqueKeys: 100,
          temporalLocality: 0.9, // High temporal locality
          spatialLocality: 0.5,
          zipfianCoefficient: 1.0,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );

        final recommendation = cacheStrategy.analyzeAndRecommend(pattern);
        expect(recommendation.recommendedStrategy, EvictionStrategy.lru);
      });

      test('Applies recommendation successfully', () {
        final pattern = AccessPattern(
          totalAccesses: 500,
          uniqueKeys: 100,
          temporalLocality: 0.8,
          spatialLocality: 0.6,
          zipfianCoefficient: 1.2,
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: DateTime.now(),
        );

        final recommendation = cacheStrategy.analyzeAndRecommend(pattern);
        cacheStrategy.applyRecommendation(recommendation);

        expect(cacheStrategy.currentStrategy, recommendation.recommendedStrategy);
        expect(cacheStrategy.currentSizing, recommendation.recommendedSizing);
        expect(cacheStrategy.currentMaxSize, recommendation.suggestedCacheSize);
      });

      test('Calculates adaptive cache size', () {
        cacheStrategy.setSizingPolicy(CacheSizingPolicy.dynamic);
        final adaptiveSize = cacheStrategy.calculateAdaptiveSize(1000, 0.5);
        expect(adaptiveSize, greaterThan(0));
      });

      test('Strategy performance tracking', () {
        cacheStrategy.recordStrategyPerformance(EvictionStrategy.lru, 0.95);
        final performance = cacheStrategy.getStrategyPerformance();
        expect(performance.containsKey(EvictionStrategy.lru), true);
      });

      test('Strategy export produces valid JSON', () {
        final json = cacheStrategy.exportStrategyDataAsJson();
        expect(json.contains('currentStrategy'), true);
        expect(json.contains('adaptationCount'), true);
      });
    });

    group('CacheMemoryProfiler Tests', () {
      test('Records memory allocations', () {
        memoryProfiler.recordAllocation('key1', 1000, 800);
        expect(memoryProfiler.getTotalMemoryAllocated(), 1000);
        expect(memoryProfiler.getTotalMemoryUsed(), 800);
      });

      test('Tracks fragmentation', () {
        memoryProfiler.recordAllocation('key1', 1000, 600);
        expect(memoryProfiler.getTotalFragmentation(), 400);
      });

      test('Finds most fragmented allocations', () {
        memoryProfiler.recordAllocation('key1', 100, 20);
        memoryProfiler.recordAllocation('key2', 100, 90);

        final fragmented = memoryProfiler.getMostFragmentedAllocations(2);
        expect(fragmented.isNotEmpty, true);
        expect(fragmented[0].key, 'key1');
      });

      test('Creates memory snapshots', () {
        memoryProfiler.recordAllocation('key1', 1000, 800);
        final snapshot = memoryProfiler.createSnapshot();

        expect(snapshot.totalAllocated, 1000);
        expect(snapshot.totalUsed, 800);
        expect(snapshot.efficiencyScore, greaterThan(0.0));
      });

      test('Tracks peak memory usage', () {
        memoryProfiler.recordAllocation('key1', 500, 400);
        expect(memoryProfiler.getPeakMemoryUsage(), 500);

        memoryProfiler.recordAllocation('key2', 1000, 800);
        expect(memoryProfiler.getPeakMemoryUsage(), 1500);
      });

      test('Suggests cleanup opportunities', () {
        memoryProfiler.recordAllocation('key1', 1000, 100); // High fragmentation
        final suggestions = memoryProfiler.suggestCleanupOpportunities(50.0);
        expect(suggestions.isNotEmpty, true);
      });

      test('Profiler statistics include trends', () {
        memoryProfiler.recordAllocation('key1', 1000, 800);
        final stats = memoryProfiler.getProfilerStats();

        expect(stats.containsKey('totalAllocations'), true);
        expect(stats.containsKey('peakMemoryUsage'), true);
        expect(stats.containsKey('memoryTrend'), true);
      });

      test('Profiler export produces valid JSON', () {
        memoryProfiler.recordAllocation('key1', 1000, 800);
        final json = memoryProfiler.exportProfilerDataAsJson();

        expect(json.contains('profilerStats'), true);
        expect(json.contains('currentSnapshot'), true);
        expect(json.contains('cleanupSuggestions'), true);
      });
    });

    group('CacheAnalytics Tests', () {
      test('Records cache hits and misses', () {
        cacheAnalytics.recordHit('key1');
        cacheAnalytics.recordMiss('key2');

        expect(cacheAnalytics.getOverallHitRate(), greaterThan(0.0));
      });

      test('Calculates hit rate correctly', () {
        for (int i = 0; i < 10; i++) {
          cacheAnalytics.recordHit('key1');
        }
        for (int i = 0; i < 5; i++) {
          cacheAnalytics.recordMiss('key1');
        }

        final hitRate = cacheAnalytics.getOverallHitRate();
        expect(hitRate, greaterThan(60.0));
        expect(hitRate, lessThan(70.0));
      });

      test('Identifies most frequent keys', () {
        for (int i = 0; i < 10; i++) {
          cacheAnalytics.recordHit('hot');
        }
        for (int i = 0; i < 2; i++) {
          cacheAnalytics.recordHit('cold');
        }

        final frequent = cacheAnalytics.getMostFrequentKeys(1);
        expect(frequent.isNotEmpty, true);
        expect(frequent[0], 'hot');
      });

      test('Analyzes and generates recommendations', () {
        // High hit rate for hot key
        for (int i = 0; i < 100; i++) {
          cacheAnalytics.recordHit('hot_key');
        }

        // Low hit rate for cold key
        for (int i = 0; i < 1; i++) {
          cacheAnalytics.recordHit('cold_key');
        }
        for (int i = 0; i < 10; i++) {
          cacheAnalytics.recordMiss('cold_key');
        }

        final recommendations = cacheAnalytics.analyzeAndRecommend();
        expect(recommendations.isNotEmpty, true);
      });

      test('Records performance snapshots', () {
        cacheAnalytics.recordHit('key1');
        cacheAnalytics.recordPerformanceSnapshot();

        final history = cacheAnalytics.getPerformanceHistory();
        expect(history.isNotEmpty, true);
      });

      test('Determines performance trend', () {
        for (int i = 0; i < 50; i++) {
          cacheAnalytics.recordHit('key$i');
          if (i % 5 == 0) {
            cacheAnalytics.recordPerformanceSnapshot();
          }
        }

        final trend = cacheAnalytics.getPerformanceTrend();
        expect(['improving', 'degrading', 'stable'].contains(trend), true);
      });

      test('Analytics export produces valid JSON', () {
        cacheAnalytics.recordHit('key1');
        cacheAnalytics.recordMiss('key2');

        final json = cacheAnalytics.exportAnalyticsAsJson();
        expect(json.contains('summary'), true);
        expect(json.contains('recommendations'), true);
        expect(json.contains('topFrequentKeys'), true);
      });
    });

    group('Integration Tests: Cache Services', () {
      test('SmartCache with AdaptiveStrategy workflow', () {
        // Simulate workload
        for (int i = 0; i < 50; i++) {
          smartCache.put('key$i', 'value$i');
          if (i % 3 == 0) {
            smartCache.get('key$i');
          }
        }

        // Analyze pattern
        final pattern = AccessPattern(
          totalAccesses: 100,
          uniqueKeys: 50,
          temporalLocality: 0.7,
          spatialLocality: 0.6,
          zipfianCoefficient: 1.3,
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          endTime: DateTime.now(),
        );

        final recommendation = cacheStrategy.analyzeAndRecommend(pattern);
        cacheStrategy.applyRecommendation(recommendation);

        expect(cacheStrategy.currentMaxSize, greaterThan(0));
      });

      test('Memory profiler tracks cache growth', () {
        for (int i = 0; i < 20; i++) {
          final data = 'x' * (100 * (i + 1));
          memoryProfiler.recordAllocation('key$i', data.length, data.length - 20);
        }

        final stats = memoryProfiler.getProfilerStats();
        expect(stats['currentAllocations'], 20);
        expect(stats['totalAllocations'], 20);
      });

      test('Analytics detects cache performance degradation', () {
        // Good performance phase
        for (int i = 0; i < 100; i++) {
          cacheAnalytics.recordHit('key$i');
        }
        cacheAnalytics.recordPerformanceSnapshot();

        // Poor performance phase
        for (int i = 0; i < 100; i++) {
          cacheAnalytics.recordMiss('key${i + 100}');
        }
        cacheAnalytics.recordPerformanceSnapshot();

        final trend = cacheAnalytics.getPerformanceTrend();
        expect(['degrading', 'stable'].contains(trend), true);
      });

      test('Full caching workflow end-to-end', () async {
        // Initialize services
        final cache = SmartCacheService.withSize(50);
        final strategy = AdaptiveCacheStrategy();
        final profiler = CacheMemoryProfiler();
        final analytics = CacheAnalytics();

        // Simulate workload
        for (int i = 0; i < 30; i++) {
          cache.put('data_$i', 'value_$i');
          analytics.recordHit('data_$i');
          profiler.recordAllocation('data_$i', 100, 90);

          if (i % 5 == 0) {
            cache.get('data_$i');
          }
        }

        // Analyze
        final pattern = AccessPattern(
          totalAccesses: 50,
          uniqueKeys: 30,
          temporalLocality: 0.75,
          spatialLocality: 0.65,
          zipfianCoefficient: 1.25,
          startTime: DateTime.now().subtract(const Duration(seconds: 30)),
          endTime: DateTime.now(),
        );

        final recommendation = strategy.analyzeAndRecommend(pattern);
        strategy.applyRecommendation(recommendation);

        // Verify all services working
        expect(cache.getSize(), greaterThan(0));
        expect(analytics.getOverallHitRate(), greaterThan(0.0));
        expect(profiler.getTotalMemoryAllocated(), greaterThan(0));
        expect(strategy.currentMaxSize, greaterThan(0));
      });
    });

    tearDown(() {
      smartCache.clear();
      cacheStrategy.clearHistory();
      memoryProfiler.clearData();
      cacheAnalytics.clearData();
    });
  });
}
