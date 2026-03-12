// ──────────────────────────────────────────────────────────
// ChatRoom Model — Direct messaging rooms
// Supports role-based visibility:
//   Students see only their own chats
//   Teachers/Admins see all chats
// ──────────────────────────────────────────────────────────

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames; // uid → display name
  final Map<String, String>
  participantRoles; // uid → role (student/teacher/admin)
  final String lastMessage;
  final DateTime lastTimestamp;
  final String type; // 'direct'
  final String? courseId; // Optional: link chat to a course

  ChatRoom({
    required this.id,
    required this.participants,
    this.participantNames = const {},
    this.participantRoles = const {},
    required this.lastMessage,
    required this.lastTimestamp,
    required this.type,
    this.courseId,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      participantNames: Map<String, String>.from(
        map['participant_names'] ?? map['participantNames'] ?? {},
      ),
      participantRoles: Map<String, String>.from(
        map['participant_roles'] ?? map['participantRoles'] ?? {},
      ),
      lastMessage: map['last_message'] ?? map['lastMessage'] ?? '',
      lastTimestamp: _parseDateTime(
        map['last_timestamp'] ?? map['lastTimestamp'],
      ),
      type: map['type'] ?? 'direct',
      courseId: map['course_id'] ?? map['courseId'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    // Check for Firestore Timestamp
    if (value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participant_names': participantNames,
      'participant_roles': participantRoles,
      'last_message': lastMessage,
      'last_timestamp': lastTimestamp.toIso8601String(),
      'type': type,
      'course_id': courseId,
    };
  }

  /// Get the display name of the other participant (for 1-to-1 chats)
  String getOtherParticipantName(String currentUserId) {
    for (final entry in participantNames.entries) {
      if (entry.key != currentUserId) return entry.value;
    }
    return 'Unknown';
  }

  /// Get the role of the other participant
  String getOtherParticipantRole(String currentUserId) {
    for (final entry in participantRoles.entries) {
      if (entry.key != currentUserId) return entry.value;
    }
    return 'student';
  }
}
