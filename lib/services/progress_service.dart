// ──────────────────────────────────────────────────────────
// progress_service.dart — Student Progress Tracking
// ──────────────────────────────────────────────────────────
// Tracks: Completed lessons, quiz scores, course progress
// Data source: Firestore (user_progress collection)
// ──────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'dart:async';
import 'dart:convert';

class ProgressService {
  final DatabaseService _db = DatabaseService();

  // Save progress for a specific course
  Future<void> saveProgress({
    required String userId,
    required String courseId,
    required String lastLessonId,
    List<String>? completedLessonIds,
    double? percentComplete,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'user_id': userId,
        'course_id': courseId,
        'last_lesson_id': lastLessonId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (completedLessonIds != null) {
        data['completed_lessons'] = jsonEncode(completedLessonIds);
      }

      if (percentComplete != null) {
        data['quiz_score'] = percentComplete;
      }

      // Use a unique ID per user course pairing
      final docId = "${userId}_$courseId";
      await _db.insert('user_progress', data, docId: docId);

      debugPrint(
        "Progress saved to Firestore for course $courseId: ID $lastLessonId",
      );
    } catch (e) {
      debugPrint("Error saving Firestore progress: $e");
    }
  }

  // Get progress for a specific course
  Stream<Map<String, dynamic>?> getCourseProgressStream(
    String userId,
    String courseId,
  ) {
    return _db
        .streamCollection(
          'user_progress',
          where: 'user_id = ?',
          whereArgs: [userId],
        )
        .map((list) {
          // Client-side filter for courseId if needed,
          // or we can rely on our refined streamCollection (which only supports one filter atm)
          final matches = list.where((item) => item['course_id'] == courseId);
          if (matches.isEmpty) return null;

          final data = Map<String, dynamic>.from(matches.first);
          if (data['completed_lessons'] != null) {
            data['completed_lesson_ids'] = jsonDecode(
              data['completed_lessons'],
            );
          }
          data['last_lesson_index'] =
              int.tryParse(data['last_lesson_id'] ?? '0') ?? 0;
          data['percent_complete'] = data['quiz_score'];

          return data;
        });
  }

  // Get all progress for the user
  Stream<List<Map<String, dynamic>>> getAllProgressStream(String userId) {
    return _db
        .streamCollection(
          'user_progress',
          where: 'user_id = ?',
          whereArgs: [userId],
        )
        .map((list) {
          return list.map((r) {
            final data = Map<String, dynamic>.from(r);
            if (data['completed_lessons'] != null) {
              data['completed_lesson_ids'] = jsonDecode(
                data['completed_lessons'],
              );
            }
            data['last_lesson_index'] =
                int.tryParse(data['last_lesson_id'] ?? '0') ?? 0;
            data['percent_complete'] = data['quiz_score'];
            return data;
          }).toList();
        });
  }
}
