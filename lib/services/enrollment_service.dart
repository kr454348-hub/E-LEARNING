import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EnrollmentService {
  static final EnrollmentService _instance = EnrollmentService._internal();
  factory EnrollmentService() => _instance;
  EnrollmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> enrollUser({
    required String userId,
    required String courseId,
  }) async {
    try {
      final enrollmentId = "${userId}_$courseId";
      await _firestore.collection('enrollments').doc(enrollmentId).set({
        'user_id': userId,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      debugPrint("✅ [Enrollment] User $userId enrolled in $courseId");
    } catch (e) {
      debugPrint("🔴 [Enrollment] Error enrolling user: $e");
      rethrow;
    }
  }

  Future<bool> isEnrolled({
    required String userId,
    required String courseId,
  }) async {
    try {
      final enrollmentId = "${userId}_$courseId";
      final doc = await _firestore
          .collection('enrollments')
          .doc(enrollmentId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint("🔴 [Enrollment] Error checking status: $e");
      return false;
    }
  }

  Stream<bool> streamEnrollmentStatus({
    required String userId,
    required String courseId,
  }) {
    final enrollmentId = "${userId}_$courseId";
    return _firestore
        .collection('enrollments')
        .doc(enrollmentId)
        .snapshots()
        .map((doc) => doc.exists);
  }
}
