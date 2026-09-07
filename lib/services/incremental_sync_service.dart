import 'dart:convert';

/// Represents a delta/change between two versions
class DataDelta {
  final String id;
  final String dataType;
  final String operation; // 'create', 'update', 'delete'
  final String? fieldPath; // For partial updates
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  final int estimatedSize; // Bytes

  DataDelta({
    required this.id,
    required this.dataType,
    required this.operation,
    this.fieldPath,
    this.oldValue,
    this.newValue,
    required this.timestamp,
    required this.estimatedSize,
  });

  /// Check if this is a field-level change
  bool get isFieldChange => fieldPath != null;

  /// Check if this delta is significant (worth syncing)
  bool get isSignificant =>
      estimatedSize > 0 ||
      operation == 'delete' ||
      (oldValue != newValue);

  Map<String, dynamic> toMap() => {
    'id': id,
    'dataType': dataType,
    'operation': operation,
    'fieldPath': fieldPath,
    'oldValue': oldValue,
    'newValue': newValue,
    'timestamp': timestamp.toIso8601String(),
    'estimatedSize': estimatedSize,
  };
}

/// Sync checkpoint for incremental synchronization
class SyncCheckpoint {
  final String deviceId;
  final DateTime timestamp;
  final String checkpointHash;
  final List<String> syncedIds;
  final int totalChanges;
  final int successCount;
  final int failureCount;

  SyncCheckpoint({
    required this.deviceId,
    required this.timestamp,
    required this.checkpointHash,
    required this.syncedIds,
    required this.totalChanges,
    required this.successCount,
    required this.failureCount,
  });

  /// Calculate sync success rate
  double get successRate =>
      totalChanges > 0 ? (successCount / totalChanges) * 100 : 0;

  /// Check if checkpoint is recent (within last hour)
  bool get isRecent =>
      DateTime.now().difference(timestamp).inHours < 1;

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'checkpointHash': checkpointHash,
    'syncedIds': syncedIds,
    'totalChanges': totalChanges,
    'successCount': successCount,
    'failureCount': failureCount,
    'successRate': successRate,
  };
}

/// Service for incremental synchronization
class IncrementalSyncService {
  static final IncrementalSyncService _instance =
      IncrementalSyncService._internal();

  factory IncrementalSyncService() {
    return _instance;
  }

  IncrementalSyncService._internal();

  // Delta tracking
  final List<DataDelta> _allDeltas = [];
  final Map<String, List<DataDelta>> _deltasByType = {};
  final Map<String, List<DataDelta>> _pendingDeltas = {};

  // Checkpoint management
  final Map<String, SyncCheckpoint> _checkpoints = {};
  final List<SyncCheckpoint> _checkpointHistory = [];

  // Sync state
  DateTime? _lastFullSync;
  DateTime? _lastIncrementalSync;
  int _totalBandwidthSaved = 0;

  /// Record a data change/delta
  void recordDelta(DataDelta delta) {
    if (delta.isSignificant) {
      _allDeltas.add(delta);

      // Keep only last 10,000 deltas for memory efficiency
      if (_allDeltas.length > 10000) {
        _allDeltas.removeAt(0);
      }

      // Track by type
      _deltasByType.putIfAbsent(delta.dataType, () => []).add(delta);

      // Track as pending
      _pendingDeltas.putIfAbsent(delta.dataType, () => []).add(delta);

      _lastIncrementalSync = DateTime.now();
    }
  }

  /// Get deltas since last sync
  List<DataDelta> getDeltasSinceLastSync() {
    if (_lastIncrementalSync == null) {
      return _allDeltas;
    }

    return _allDeltas
        .where((d) => d.timestamp.isAfter(_lastIncrementalSync!))
        .toList();
  }

  /// Get deltas for specific type
  List<DataDelta> getDeltasByType(String dataType) {
    return _deltasByType[dataType] ?? [];
  }

  /// Get pending deltas (not yet synced)
  List<DataDelta> getPendingDeltas() {
    final pending = <DataDelta>[];
    for (final deltaList in _pendingDeltas.values) {
      pending.addAll(deltaList);
    }
    return pending;
  }

  /// Get pending deltas count
  int getPendingDeltasCount() {
    var count = 0;
    for (final deltaList in _pendingDeltas.values) {
      count += deltaList.length;
    }
    return count;
  }

  /// Mark deltas as synced
  void markDeltasAsSynced(List<String> syncedDeltaIds) {
    for (final id in syncedDeltaIds) {
      // Remove from pending
      for (final entry in _pendingDeltas.entries) {
        entry.value.removeWhere((d) => d.id == id);
      }
    }
  }

  /// Create sync checkpoint
  SyncCheckpoint createCheckpoint(
    String deviceId,
    List<String> syncedIds,
    int totalChanges,
    int successCount,
    int failureCount,
  ) {
    final checkpoint = SyncCheckpoint(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      checkpointHash: _generateCheckpointHash(),
      syncedIds: syncedIds,
      totalChanges: totalChanges,
      successCount: successCount,
      failureCount: failureCount,
    );

    _checkpoints[deviceId] = checkpoint;
    _checkpointHistory.add(checkpoint);

    // Keep last 100 checkpoints
    if (_checkpointHistory.length > 100) {
      _checkpointHistory.removeAt(0);
    }

    _lastIncrementalSync = DateTime.now();

    return checkpoint;
  }

  /// Get checkpoint for device
  SyncCheckpoint? getCheckpoint(String deviceId) {
    return _checkpoints[deviceId];
  }

  /// Get recent checkpoints
  List<SyncCheckpoint> getRecentCheckpoints() {
    return _checkpointHistory
        .where((c) => c.isRecent)
        .toList();
  }

  /// Calculate estimated data size to sync
  int calculateEstimatedSyncSize() {
    var total = 0;
    for (final delta in getPendingDeltas()) {
      total += delta.estimatedSize;
    }
    return total;
  }

  /// Estimate bandwidth savings from incremental sync
  int estimateBandwidthSavings() {
    // Full sync would be 10x the delta size
    final deltaSize = calculateEstimatedSyncSize();
    return deltaSize * 9; // 90% savings estimate
  }

  /// Get incremental sync stats
  Map<String, dynamic> getIncrementalSyncStats() {
    return {
      'totalDeltas': _allDeltas.length,
      'pendingDeltas': getPendingDeltasCount(),
      'deltasByType': _getDeltasCountByType(),
      'estimatedSyncSize': calculateEstimatedSyncSize(),
      'estimatedBandwidthSavings': estimateBandwidthSavings(),
      'totalBandwidthSaved': _totalBandwidthSaved,
      'lastFullSync': _lastFullSync?.toIso8601String(),
      'lastIncrementalSync': _lastIncrementalSync?.toIso8601String(),
      'checkpointCount': _checkpoints.length,
    };
  }

  Map<String, int> _getDeltasCountByType() {
    final counts = <String, int>{};
    for (final entry in _deltasByType.entries) {
      counts[entry.key] = entry.value.length;
    }
    return counts;
  }

  /// Generate checkpoint hash
  String _generateCheckpointHash() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return timestamp.hashCode.toString();
  }

  /// Reset incremental sync (full sync occurred)
  void resetIncrementalSync(String deviceId) {
    _lastFullSync = DateTime.now();
    _pendingDeltas.clear();
    _allDeltas.clear();
    _deltasByType.clear();

    final checkpoint = _checkpoints[deviceId];
    if (checkpoint != null) {
      _totalBandwidthSaved += estimateBandwidthSavings();
    }
  }

  /// Get sync efficiency metrics
  Map<String, dynamic> getSyncEfficiencyMetrics() {
    final totalDeltas = _allDeltas.length;
    final syncedCount = (totalDeltas - getPendingDeltasCount());

    return {
      'totalDeltasProcessed': totalDeltas,
      'syncedDeltas': syncedCount,
      'pendingDeltas': getPendingDeltasCount(),
      'syncEfficiency': totalDeltas > 0
          ? (syncedCount / totalDeltas) * 100
          : 0,
      'averageDeltaSize': totalDeltas > 0
          ? _allDeltas
                  .fold(0, (sum, d) => sum + d.estimatedSize) ~/
              totalDeltas
          : 0,
      'totalBandwidthSaved': _totalBandwidthSaved,
    };
  }

  /// Export deltas as JSON
  String exportDeltasAsJson() {
    return '''
{
  "timestamp": "${DateTime.now().toIso8601String()}",
  "totalDeltas": ${_allDeltas.length},
  "pendingDeltas": ${getPendingDeltasCount()},
  "deltas": [
    ${_allDeltas.take(100).map((d) => _deltaToJson(d)).join(',\n    ')}
  ],
  "statistics": ${_mapToJson(getIncrementalSyncStats())}
}
''';
  }

  String _deltaToJson(DataDelta delta) {
    return '''
{
      "id": "${delta.id}",
      "dataType": "${delta.dataType}",
      "operation": "${delta.operation}",
      "fieldPath": "${delta.fieldPath ?? 'full'}",
      "timestamp": "${delta.timestamp.toIso8601String()}",
      "estimatedSize": ${delta.estimatedSize}
    }''';
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
      } else if (entry.value is Map) {
        buffer.write(_mapToJson(entry.value as Map<String, dynamic>));
      } else {
        buffer.write('${entry.value}');
      }

      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Clear all deltas
  void clearAllDeltas() {
    _allDeltas.clear();
    _deltasByType.clear();
    _pendingDeltas.clear();
  }
}
