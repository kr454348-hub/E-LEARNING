// ──────────────────────────────────────────────────────────
// ChatService — 1-to-1 Messaging (replaces AI Tutor)
// Role-based visibility:
//   Students: see only their own chats
//   Teachers/Admins: see all chats
// ──────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/chat_room.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Send Message ───
  Future<void> sendMessage(String roomId, Message message) async {
    try {
      final messageMap = message.toMap();
      messageMap['room_id'] = roomId;

      await _firestore.collection('chat_messages').add(messageMap);

      final roomRef = _firestore.collection('chat_rooms').doc(roomId);
      await roomRef.set({
        'last_message': message.type == 'image' ? '[Image]' : message.text,
        'last_timestamp': message.timestamp.toIso8601String(),
        'participants': FieldValue.arrayUnion([message.senderId]),
        'type': roomId.contains('_') ? 'direct' : 'course',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // ─── Get Messages Stream ───
  Stream<List<Message>> getMessages(String roomId) {
    return _firestore
        .collection('chat_messages')
        .where('room_id', isEqualTo: roomId)
        .snapshots()
        .map((snap) {
          final messages = snap.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList();
          // Sort in-memory to avoid Firestore Composite Index requirement
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        })
        .handleError((error) {
          debugPrint('🔴 [ChatService] getMessages error: $error');
        });
  }

  // ─── Create or Get Private Chat Room ───
  Future<String> createPrivateChat({
    required String userId,
    required String userName,
    required String userRole,
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
  }) async {
    try {
      // Check if chat already exists
      final snapshot = await _firestore
          .collection('chat_rooms')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: userId)
          .get();

      for (var doc in snapshot.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      // Create new chat room
      final roomId = '${userId}_$otherUserId';
      await _firestore.collection('chat_rooms').doc(roomId).set({
        'participants': [userId, otherUserId],
        'participant_names': {userId: userName, otherUserId: otherUserName},
        'participant_roles': {userId: userRole, otherUserId: otherUserRole},
        'last_message': '',
        'last_timestamp': DateTime.now().toIso8601String(),
        'type': 'direct',
      });

      return roomId;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  // ─── Get Student's Own Chats ───
  Stream<List<ChatRoom>> getStudentChats(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final rooms = snap.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .toList();
          // Sort in-memory to avoid Firestore Composite Index requirement
          rooms.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
          return rooms;
        })
        .handleError((error) {
          debugPrint('🔴 [ChatService] getStudentChats error: $error');
        });
  }

  // ─── Get All Chats (for Teacher/Admin) ───
  Stream<List<ChatRoom>> getAllChats() {
    return _firestore.collection('chat_rooms').snapshots().map((snap) {
      final rooms = snap.docs
          .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
          .toList();
      // Sort in-memory
      rooms.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
      return rooms;
    });
  }

  // ─── Get Available Users to Chat With ───
  Future<List<Map<String, dynamic>>> getAvailableUsers({
    required String currentUserId,
    required String currentUserRole,
  }) async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final users = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;
        final data = doc.data();
        final role = data['role'] ?? 'student';

        // Students can chat with teachers and admins
        // Teachers can chat with students and admins
        // Admins can chat with everyone
        if (currentUserRole == 'student' &&
            (role == 'teacher' || role == 'admin')) {
          users.add({'uid': doc.id, ...data});
        } else if (currentUserRole == 'teacher' &&
            (role == 'student' || role == 'admin')) {
          users.add({'uid': doc.id, ...data});
        } else if (currentUserRole == 'admin') {
          users.add({'uid': doc.id, ...data});
        }
      }

      return users;
    } catch (e) {
      debugPrint('Error getting users: $e');
      return [];
    }
  }

  // ─── Mark Messages as Read ───
  Future<void> markAsRead(String roomId, String userId) async {
    try {
      final unread = await _firestore
          .collection('chat_messages')
          .where('room_id', isEqualTo: roomId)
          .get();

      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        final readBy = List<String>.from(doc.data()['read_by'] ?? []);
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          batch.update(doc.reference, {'read_by': readBy});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }
}
