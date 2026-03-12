import '../models/live_class.dart';
import 'database_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class LiveClassService {
  final DatabaseService _db = DatabaseService();

  // Stream of upcoming classes, ordered by date
  Stream<List<LiveClass>> getUpcomingClasses() {
    return _db.streamCollection('live_classes').map((list) {
      return list.map((map) => LiveClass.fromMap(map, map['id'])).toList();
    });
  }

  // Add a new class
  Future<void> scheduleClass(LiveClass liveClass) async {
    await _db.insert('live_classes', liveClass.toMap());
  }

  // Delete a class
  Future<void> deleteClass(String id) async {
    await _db.delete('live_classes', docId: id);
  }

  // Cleanup classes that ended > 1 hour ago
  Future<void> cleanupPastClasses() async {
    try {
      final now = DateTime.now();
      final threshold = now.subtract(const Duration(hours: 1));

      // Fetch classes where scheduledAt is before the threshold
      // NOTE: We fetch all and filter because DatabaseService.query only supports equality for now.
      // This is still better than decoding all objects first.
      final classes = await _db.query('live_classes');
      
      int count = 0;
      for (var map in classes) {
        final scheduledAtStr = map['scheduledAt'] as String?;
        if (scheduledAtStr != null) {
          final scheduledAt = DateTime.parse(scheduledAtStr);
          if (scheduledAt.isBefore(threshold)) {
            await deleteClass(map['id'] ?? '');
            count++;
          }
        }
      }
      if (count > 0) {
        debugPrint("🧹 [LiveClassService] Cleaned up $count past classes.");
      }
    } catch (e) {
      debugPrint("🔴 [LiveClassService] Error cleaning up past classes: $e");
    }
  }
}
