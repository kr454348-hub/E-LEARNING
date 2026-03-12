import 'package:cloud_firestore/cloud_firestore.dart';

class LiveClass {
  final String id;
  final String title;
  final String description; // e.g., "Join via Zoom" or "Code review session"
  final String meetingUrl;
  final DateTime scheduledAt;
  final String instructorName;
  final String courseId; // Optional: Link to a specific course

  LiveClass({
    required this.id,
    required this.title,
    required this.description,
    required this.meetingUrl,
    required this.scheduledAt,
    required this.instructorName,
    this.courseId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'meetingUrl': meetingUrl,
      'scheduled_at': scheduledAt.toIso8601String(),
      'instructor_name': instructorName,
      'course_id': courseId,
    };
  }

  factory LiveClass.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

    return LiveClass(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      meetingUrl: map['meetingUrl'] ?? '',
      scheduledAt: parseDate(map['scheduled_at']),
      instructorName: map['instructor_name'] ?? 'Instructor',
      courseId: map['course_id'] ?? '',
    );
  }
}
