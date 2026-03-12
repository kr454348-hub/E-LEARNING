// ──────────────────────────────────────────────────────────
// database_service.dart — Firestore CRUD Abstraction Layer
// ──────────────────────────────────────────────────────────
// Wraps Cloud Firestore operations with error handling,
// timeouts, and real-time streaming support.
// Used by: AuthService, all screens that read/write data
// ──────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Duration _timeout = const Duration(seconds: 20);

  // Generic helpers for Firestore
  Future<void> insert(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    debugPrint(
      "🔍 [DatabaseService] Inserting into $collection (Timeout: ${effectiveTimeout.inSeconds}s)",
    );
    try {
      if (docId != null) {
        await _firestore
            .collection(collection)
            .doc(docId)
            .set(data, SetOptions(merge: true))
            .timeout(
              effectiveTimeout,
              onTimeout: () {
                debugPrint(
                  "🔴 [DatabaseService] INSERT TIMEOUT: $collection/$docId after ${effectiveTimeout.inSeconds}s",
                );
                throw TimeoutException('Insert timed out');
              },
            );
      } else {
        await _firestore
            .collection(collection)
            .add(data)
            .timeout(
              effectiveTimeout,
              onTimeout: () {
                debugPrint(
                  "🔴 [DatabaseService] INSERT TIMEOUT: $collection after ${effectiveTimeout.inSeconds}s",
                );
                throw TimeoutException('Insert timed out');
              },
            );
      }
      debugPrint("✅ [DatabaseService] Insert into $collection complete");
    } catch (e) {
      debugPrint("🔴 [DatabaseService] Insert Error ($collection): $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String collection, {
    String? where,
    List<Object?>? whereArgs,
    int? limit,
    String? orderBy,
    List<String>? columns,
    Duration? timeout,
    int retryCount = 2,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    int attempts = 0;

    while (attempts <= retryCount) {
      attempts++;
      debugPrint(
        "🔍 [DatabaseService] Querying $collection (Attempt $attempts, Timeout: ${effectiveTimeout.inSeconds}s)",
      );

      Query query = _firestore.collection(collection);

      if (orderBy != null) {
        bool descending = orderBy.toLowerCase().contains('desc');
        String field = orderBy.split(' ')[0];
        query = query.orderBy(field, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (where != null && whereArgs != null) {
        final conditions = where.split(
          RegExp(r'\s+AND\s+', caseSensitive: false),
        );
        for (int i = 0; i < conditions.length; i++) {
          final field = conditions[i].split(' ')[0];
          if (i < whereArgs.length) {
            query = query.where(field, isEqualTo: whereArgs[i]);
          }
        }
      }

      try {
        final snapshot = await query.get().timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException('Query timed out');
          },
        );
        debugPrint(
          "✅ [DatabaseService] Query $collection returned ${snapshot.docs.length} docs",
        );
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint(
          "⚠️ [DatabaseService] Query Attempt $attempts Failed ($collection): $e",
        );
        if (attempts > retryCount) {
          debugPrint(
            "🔴 [DatabaseService] Max retries reached for $collection",
          );
          rethrow;
        }
        // Small delay before retry
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    return []; // Should not reach here
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    try {
      debugPrint(
        "🔍 [DatabaseService] Fetching $collection/$docId (Timeout: ${effectiveTimeout.inSeconds}s)",
      );
      final snapshot = await _firestore
          .collection(collection)
          .doc(docId)
          .get()
          .timeout(
            effectiveTimeout,
            onTimeout: () {
              debugPrint(
                "🔴 [DatabaseService] FETCH TIMEOUT: $collection/$docId after ${effectiveTimeout.inSeconds}s",
              );
              throw TimeoutException('Fetch timed out');
            },
          );

      if (!snapshot.exists) {
        debugPrint(
          "🔍 [DatabaseService] Document $collection/$docId does not exist",
        );
        return null;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      data['id'] = snapshot.id;
      return data;
    } catch (e) {
      debugPrint("🔴 [DatabaseService] Error fetching $collection/$docId: $e");
      rethrow;
    }
  }

  Future<void> update(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
    String? where,
    List<Object?>? whereArgs,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    if (docId != null) {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: true))
          .timeout(effectiveTimeout);
      return;
    }

    if (where != null && whereArgs != null && where.contains('?')) {
      // Attempt to parse simple single-field equality like 'field = ?'
      final field = where.split(' ')[0];
      final snapshot = await _firestore
          .collection(collection)
          .where(field, isEqualTo: whereArgs[0])
          .get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, data);
      }
      await batch.commit();
      return;
    }

    throw ArgumentError('Either docId or where/whereArgs must be provided');
  }

  Future<void> delete(
    String collection, {
    String? docId,
    String? where,
    List<Object?>? whereArgs,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    if (docId != null) {
      await _firestore
          .collection(collection)
          .doc(docId)
          .delete()
          .timeout(effectiveTimeout);
      return;
    }

    if (where != null && whereArgs != null && where.contains('?')) {
      final field = where.split(' ')[0];
      final snapshot = await _firestore
          .collection(collection)
          .where(field, isEqualTo: whereArgs[0])
          .get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return;
    }

    throw ArgumentError('Either docId or where/whereArgs must be provided');
  }

  Future<void> deleteWhere(
    String collection,
    String field,
    dynamic value,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Stream access for sub-collections (Tree structure)
  Stream<List<Map<String, dynamic>>> streamSubCollection(
    String parentCollection,
    String parentId,
    String subCollection, {
    String? orderBy,
  }) {
    Query query = _firestore
        .collection(parentCollection)
        .doc(parentId)
        .collection(subCollection);

    if (orderBy != null) {
      String field = orderBy.split(' ')[0];
      bool descending = orderBy.contains('DESC');
      query = query.orderBy(field, descending: descending);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Stream access for real-time updates
  Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    String? orderBy,
    String? where,
    List<dynamic>? whereArgs,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);

    // Simple 'where' parsing for basic equality or array-contains
    if (where != null && whereArgs != null && where.contains('?')) {
      String field = where.split(' ')[0];
      dynamic fieldToQuery = field;
      if (field == 'id') fieldToQuery = FieldPath.documentId;

      if (where.contains('ARRAY-CONTAINS')) {
        query = query.where(fieldToQuery, arrayContains: whereArgs[0]);
      } else {
        query = query.where(fieldToQuery, isEqualTo: whereArgs[0]);
      }
    }

    if (orderBy != null) {
      String field = orderBy.split(' ')[0];
      bool descending = orderBy.contains('DESC');
      query = query.orderBy(field, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<Map<String, dynamic>?> streamDocument(
    String collection,
    String docId,
  ) {
    return _firestore.collection(collection).doc(docId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    });
  }

  // ─── Specialized Activity Methods ───

  Future<void> toggleFavorite(String userId, String courseId) async {
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(courseId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  Stream<bool> isFavorite(String userId, String courseId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(courseId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleBookmark(String userId, String lessonId) async {
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(lessonId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  Stream<bool> isBookmarked(String userId, String lessonId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(lessonId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> submitRating(
    String userId,
    String courseId,
    double rating,
    String comment,
  ) async {
    final batch = _firestore.batch();

    // 1. Add/Update the rating doc
    final ratingRef = _firestore
        .collection('courses')
        .doc(courseId)
        .collection('ratings')
        .doc(userId);
    batch.set(ratingRef, {
      'rating': rating,
      'comment': comment,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update the course summary (optional but better for performance)
    // In a real app, this would be a Cloud Function, but here we can do it client-side for simplicity
    // with a slight risk of race conditions.
    final courseRef = _firestore.collection('courses').doc(courseId);
    batch.update(courseRef, {
      'averageRating': FieldValue.increment(0), // Placeholder for aggregation
      'ratingCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Batch operations for high-speed background seeding
  Future<void> batchInsert(
    String collectionPrefix,
    List<Map<String, dynamic>> items, {
    String Function(int index)? docIdGenerator,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final batch = _firestore.batch();

    for (int i = 0; i < items.length; i++) {
      final data = items[i];
      final docId = docIdGenerator?.call(i);
      final ref = docId != null
          ? _firestore.collection(collectionPrefix).doc(docId)
          : _firestore.collection(collectionPrefix).doc();
      batch.set(ref, data, SetOptions(merge: true));
    }

    try {
      debugPrint(
        "🚀 [DatabaseService] Committing Batch of ${items.length} to $collectionPrefix",
      );
      await batch.commit().timeout(effectiveTimeout);
      debugPrint(
        "✅ [DatabaseService] Batch commit to $collectionPrefix complete",
      );
    } catch (e) {
      debugPrint("🔴 [DatabaseService] Batch commit error: $e");
      rethrow;
    }
  }

  // Legacy for backward compatibility with existing code during migration
  Future<void> init() async {}
}
