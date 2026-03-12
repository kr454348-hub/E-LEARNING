// ──────────────────────────────────────────────────────────
// CourseContentService — CRUD for Chapters, Lectures, Quizzes, Notes
// Firebase structure: courses/{courseId} with chapters as embedded array
// ──────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/note.dart';

class CourseContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Course CRUD ───

  Future<String> addCourse(Course course) async {
    try {
      final doc = await _firestore.collection('courses').add(course.toMap());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding course: $e');
      rethrow;
    }
  }

  Future<void> updateCourse(String courseId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('courses').doc(courseId).update(data);
    } catch (e) {
      debugPrint('Error updating course: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      // Delete all notes linked to this course
      final notesSnap = await _firestore
          .collection('notes')
          .where('course_id', isEqualTo: courseId)
          .get();
      for (final doc in notesSnap.docs) {
        await doc.reference.delete();
      }
      await _firestore.collection('courses').doc(courseId).delete();
    } catch (e) {
      debugPrint('Error deleting course: $e');
      rethrow;
    }
  }

  Stream<List<Course>> streamCourses({String? category}) {
    Query<Map<String, dynamic>> query = _firestore.collection('courses');
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map(
      (snap) =>
          snap.docs.map((doc) => Course.fromMap(doc.data(), doc.id)).toList(),
    );
  }

  Future<Course?> getCourse(String courseId) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseId).get();
      if (doc.exists && doc.data() != null) {
        return Course.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting course: $e');
      return null;
    }
  }

  // ─── Chapter CRUD (embedded in Course document) ───

  Future<void> addChapter(String courseId, Chapter chapter) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = List<Chapter>.from(course.chapters);
      final newChapter = chapter.copyWith(
        id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
        order: chapters.length,
      );
      chapters.add(newChapter);
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error adding chapter: $e');
      rethrow;
    }
  }

  Future<void> updateChapter(
    String courseId,
    String chapterId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters.map((ch) {
        if (ch.id == chapterId) {
          return Chapter(
            id: ch.id,
            title: updates['title'] ?? ch.title,
            order: updates['order'] ?? ch.order,
            lectures: ch.lectures,
          );
        }
        return ch;
      }).toList();
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error updating chapter: $e');
      rethrow;
    }
  }

  Future<void> deleteChapter(String courseId, String chapterId) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters
          .where((ch) => ch.id != chapterId)
          .toList();
      // Re-order remaining chapters
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = chapters[i].copyWith(order: i);
      }
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error deleting chapter: $e');
      rethrow;
    }
  }

  Future<void> reorderChapters(
    String courseId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = List<Chapter>.from(course.chapters);

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final Chapter item = chapters.removeAt(oldIndex);
      chapters.insert(newIndex, item);

      // Update orders
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = chapters[i].copyWith(order: i);
      }

      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error reordering chapters: $e');
      rethrow;
    }
  }

  // ─── Lecture CRUD (embedded in Chapter) ───

  Future<void> addLecture(
    String courseId,
    String chapterId,
    Lecture lecture,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters.map((ch) {
        if (ch.id == chapterId) {
          final lectures = List<Lecture>.from(ch.lectures);
          final newLecture = lecture.copyWith(
            id: 'lec_${DateTime.now().millisecondsSinceEpoch}',
            order: lectures.length,
          );
          lectures.add(newLecture);
          return ch.copyWith(lectures: lectures);
        }
        return ch;
      }).toList();
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error adding lecture: $e');
      rethrow;
    }
  }

  Future<void> updateLecture(
    String courseId,
    String chapterId,
    String lectureId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters.map((ch) {
        if (ch.id == chapterId) {
          final lectures = ch.lectures.map((lec) {
            if (lec.id == lectureId) {
              return Lecture(
                id: lec.id,
                title: updates['title'] ?? lec.title,
                videoUrl: updates['video_url'] ?? lec.videoUrl,
                duration: updates['duration'] ?? lec.duration,
                content: updates['content'] ?? lec.content,
                questions: updates['questions'] != null
                    ? (updates['questions'] as List)
                          .map(
                            (q) => Question.fromMap(q as Map<String, dynamic>),
                          )
                          .toList()
                    : lec.questions,
                order: updates['order'] ?? lec.order,
              );
            }
            return lec;
          }).toList();
          return ch.copyWith(lectures: lectures);
        }
        return ch;
      }).toList();
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error updating lecture: $e');
      rethrow;
    }
  }

  Future<void> deleteLecture(
    String courseId,
    String chapterId,
    String lectureId,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters.map((ch) {
        if (ch.id == chapterId) {
          final lectures = ch.lectures.where((l) => l.id != lectureId).toList();
          for (int i = 0; i < lectures.length; i++) {
            lectures[i] = lectures[i].copyWith(order: i);
          }
          return ch.copyWith(lectures: lectures);
        }
        return ch;
      }).toList();
      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error deleting lecture: $e');
      rethrow;
    }
  }

  Future<void> reorderLectures(
    String courseId,
    String chapterId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      final course = await getCourse(courseId);
      if (course == null) return;
      final chapters = course.chapters.map((ch) {
        if (ch.id == chapterId) {
          final lectures = List<Lecture>.from(ch.lectures);
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final Lecture item = lectures.removeAt(oldIndex);
          lectures.insert(newIndex, item);

          // Update orders
          for (int i = 0; i < lectures.length; i++) {
            lectures[i] = lectures[i].copyWith(order: i);
          }
          return ch.copyWith(lectures: lectures);
        }
        return ch;
      }).toList();

      await _firestore.collection('courses').doc(courseId).update({
        'chapters': chapters.map((c) => c.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error reordering lectures: $e');
      rethrow;
    }
  }

  // ─── Notes CRUD (Firestore 'notes' collection) ───

  Future<String> addNote(Note note) async {
    try {
      final doc = await _firestore.collection('notes').add(note.toMap());
      return doc.id;
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(String noteId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('notes').doc(noteId).update(data);
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  Stream<List<Note>> streamNotes({String? courseId, String? category}) {
    Query<Map<String, dynamic>> query = _firestore.collection('notes');
    if (courseId != null && courseId.isNotEmpty) {
      query = query.where('course_id', isEqualTo: courseId);
    }
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Note.fromMap(doc.data(), doc.id)).toList(),
        );
  }

  // ─── Stats for Admin Dashboard ───

  Future<Map<String, int>> getContentStats() async {
    try {
      final coursesSnap = await _firestore.collection('courses').get();
      final notesSnap = await _firestore.collection('notes').get();
      final usersSnap = await _firestore.collection('users').get();
      final chatsSnap = await _firestore.collection('chat_rooms').get();

      int totalChapters = 0;
      int totalLectures = 0;
      for (final doc in coursesSnap.docs) {
        final course = Course.fromMap(doc.data(), doc.id);
        totalChapters += course.chapters.length;
        for (final ch in course.chapters) {
          totalLectures += ch.lectures.length;
        }
      }

      return {
        'courses': coursesSnap.docs.length,
        'chapters': totalChapters,
        'lectures': totalLectures,
        'notes': notesSnap.docs.length,
        'users': usersSnap.docs.length,
        'chats': chatsSnap.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'courses': 0,
        'chapters': 0,
        'lectures': 0,
        'notes': 0,
        'users': 0,
        'chats': 0,
      };
    }
  }
}
