// ──────────────────────────────────────────────────────────
// SeedCourses — Non-blocking background seeder
// Standardizes courses to 2 chapters, 10 lessons, 5 quizzes.
// ──────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../core/app_constants.dart';

class SeedCourses {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Force run all seeders
  static Future<void> seedAll() async {
    debugPrint('🚀 [Seed] Force seeding all data to meet "2 Chapters, 10 Lessons, 5 Quizzes" rule...');
    await _doSeed(force: true);
    debugPrint('✅ [Seed] Force seed complete.');
  }

  /// Call this from main.dart WITHOUT await — runs in background
  static void seedIfEmpty() {
    _doSeed().catchError((e) {
      debugPrint('⚠️ [Seed] Background seeding skipped or failed: $e');
    });
  }

  static Future<void> _doSeed({bool force = false}) async {
    try {
      // Fetch all existing courses to check structure if not forcing
      final querySnapshot = await _firestore.collection('courses').get();
      
      if (!force && querySnapshot.docs.isNotEmpty) {
        // Simple check: do we have enough courses?
        if (querySnapshot.docs.length >= (AppCategories.mainCategories.length + AppCategories.codingLanguages.length)) {
          debugPrint('ℹ️ [Seed] Courses already exist — skipping background seed.');
          return;
        }
      }

      debugPrint('🎬 [Seed] Seeding standardized courses...');

      final courses = _getSampleCourses();
      
      for (var course in courses) {
        try {
          // Find if course with same title exists
          final existingDoc = querySnapshot.docs.where((doc) => doc.data()['title'] == course.title).firstOrNull;

          if (existingDoc != null && !force) {
            debugPrint('⏭️ [Seed] Skipping existing course: ${course.title}');
            continue;
          }

          final docRef = existingDoc != null 
              ? _firestore.collection('courses').doc(existingDoc.id)
              : _firestore.collection('courses').doc();
          
          course = course.copyWith(id: docRef.id);

          await docRef.set(course.toMap()).timeout(const Duration(seconds: 10));
          debugPrint('✅ [Seed] Standardized course: ${course.title}');
          await _seedNotesForCourse(course);
        } catch (e) {
          debugPrint('🔴 [Seed] FAILED to write course "${course.title}": $e');
        }
      }

      debugPrint('🏁 [Seed] Seeding finished.');
    } catch (e) {
      debugPrint(' global: $e');
      rethrow;
    }
  }

  static Future<void> _seedNotesForCourse(Course course) async {
    try {
      final List<Map<String, String>> notes;
      
      if (course.category == 'Medical') {
        notes = [
          {'title': 'Clinical Anatomy Reference', 'content': 'Comprehensive guide to human anatomical structures for clinical practice.'},
          {'title': 'Pathology Lab Manual', 'content': 'Standard operating procedures for diagnostic pathology and lab analysis.'},
          {'title': 'Pharmacology Cheat Sheet', 'content': 'Quick reference for common drug classifications and dosages.'},
        ];
      } else if (course.category == 'Competitive Exams') {
        notes = [
          {'title': 'JEE Physics Formula Book', 'content': 'Master formulae from Mechanics to Modern Physics for rapid revision.'},
          {'title': 'Inorganic Chemistry Mnemonics', 'content': 'Memorable tricks to master periodic properties and chemical bonding.'},
          {'title': 'Advanced Mathematics Workbook', 'content': 'High-yield problems in Calculus and Algebra.'},
        ];
      } else {
        notes = [
          {'title': '${course.title} - Professional Guide', 'content': 'Industry-standard best practices.'},
          {'title': 'Technical Quick-Ref', 'content': 'Essential syntax and architectural patterns.'},
        ];
      }

      for (var noteData in notes) {
        final noteRef = _firestore.collection('notes').doc();
        await noteRef.set({
          'id': noteRef.id,
          'title': noteData['title'],
          'content': noteData['content'] ?? 'Professional study material.',
          'course_id': course.id,
          'author_name': 'System Expert',
          'author_id': 'system',
          'created_at': DateTime.now().toIso8601String(),
          'category': course.category,
          'file_name': '${noteData['title']!.replaceAll(' ', '_')}.pdf',
          'pdf_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        });
      }
    } catch (e) {
      debugPrint('   ⚠️ [Seed] Failed to add notes for ${course.title}: $e');
    }
  }

  static List<Course> _getSampleCourses() {
    final List<Course> generatedCourses = [];

    // 1. MBBS - Clinical Excellence
    generatedCourses.add(Course(
      title: 'Mastering MBBS - Clinical Excellence',
      description: 'Comprehensive medical education covering Anatomy and Physiology with clinical correlations.',
      category: 'Medical',
      level: 'Professional',
      thumbnail: 'https://images.unsplash.com/photo-1576091160550-217359f4814c?q=80&w=2070&auto=format&fit=crop',
      videoUrl: 'https://www.youtube.com/watch?v=X6E6qI5WbXk',
      authorId: 'system_medical',
      authorName: 'Dr. Jane Smith',
      chapters: [
        Chapter(
          id: 'mbbs_ch_1',
          title: 'Chapter 1: Human Anatomy (Interactive 3D)',
          order: 1,
          lectures: List.generate(5, (i) => Lecture(
                id: 'mbbs_lec_1_$i',
                title: 'Lec ${i + 1}: ${["Skeletal Basics", "Muscular Anatomy", "Cardiovascular System", "Neurological Mapping", "Respiratory Organs"][i]}',
                videoUrl: 'https://www.youtube.com/watch?v=fVUKp18OXuc', // AnatomyZone
                duration: '12:00',
                content: 'Structured study of anatomical structures.',
                order: i + 1,
              )),
        ),
        Chapter(
          id: 'mbbs_ch_2',
          title: 'Chapter 2: Human Physiology (Deep Dive)',
          order: 2,
          lectures: List.generate(5, (i) => Lecture(
                id: 'mbbs_lec_2_$i',
                title: 'Lec ${i + 6}: ${["Cellular Function", "Nerve Signaling", "Cardiac Output", "Renal Filtration", "Endocrine Balance"][i]}',
                videoUrl: 'https://www.youtube.com/watch?v=NinjaNerdPhys', // Ninja Nerd Placeholder
                duration: '15:00',
                content: 'Mechanism of physiological systems.',
                order: i + 1,
              )),
        ),
      ],
      questions: _generateQuestions('MBBS'),
    ));

    // 2. IIT-JEE Ultimate
    generatedCourses.add(Course(
      title: 'IIT-JEE Ultimate Preparation',
      description: 'Master Class for JEE Main & Advanced from top Faculty.',
      category: 'Competitive Exams',
      level: 'Advanced',
      thumbnail: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?q=80&w=2070&auto=format&fit=crop',
      videoUrl: 'https://www.youtube.com/watch?v=60ItHLz5WEA',
      authorId: 'system_iit',
      authorName: 'IIT Alumnus Faculty',
      chapters: [
        Chapter(
          id: 'iit_ch_1',
          title: 'Chapter 1: Advanced Physics (Concept to Core)',
          order: 1,
          lectures: List.generate(5, (i) => Lecture(
                id: 'iit_lec_1_$i',
                title: 'Lesson ${i + 1}: ${["Kinematics", "Laws of Motion", "Work Power Energy", "Rotational Motion", "Gravitation"][i]}',
                videoUrl: 'https://www.youtube.com/watch?v=XU5Wp3S_5M0', // Physics Galaxy
                duration: '20:00',
                content: 'Concept building for JEE.',
                order: i + 1,
              )),
        ),
        Chapter(
          id: 'iit_ch_2',
          title: 'Chapter 2: Master Mathematics (Calculus & Algebra)',
          order: 2,
          lectures: List.generate(5, (i) => Lecture(
                id: 'iit_lec_2_$i',
                title: 'Lesson ${i + 6}: ${["Functions", "Limits", "Derivatives", "Integration", "Probability"][i]}',
                videoUrl: 'https://www.youtube.com/watch?v=60ItHLz5WEA', // Mohit Tyagi
                duration: '25:00',
                content: 'Step-by-step problem solving.',
                order: i + 1,
              )),
        ),
      ],
      questions: _generateQuestions('IIT-JEE'),
    ));

    // 3. Main Categories (Coding, Business, etc)
    for (var cat in AppCategories.mainCategories) {
      if (cat['name'] == 'Medical' || cat['name'] == 'Competitive Exams') continue;
      generatedCourses.add(_createStandardCourse(cat['name']));
    }

    // 4. Coding Languages
    for (var lang in AppCategories.codingLanguages) {
      generatedCourses.add(_createStandardCourse(lang['name']));
    }

    return generatedCourses;
  }

  static Course _createStandardCourse(String categoryName) {
    // Coding specialized videos
    String codingVideo = 'https://www.youtube.com/watch?v=82PXenL4MGg'; // Programming with Mosh
    if (categoryName == 'Python') codingVideo = 'https://www.youtube.com/watch?v=_uQrJ0TkZlc';
    if (categoryName == 'JavaScript') codingVideo = 'https://www.youtube.com/watch?v=PkZNo7MFNFg';
    if (categoryName == 'Java') codingVideo = 'https://www.youtube.com/watch?v=eIrMbAQSU34';

    return Course(
      title: 'Mastering $categoryName',
      description: 'A comprehensive curriculum spanning foundations to advanced implementation in $categoryName.',
      category: categoryName,
      level: 'All Levels',
      thumbnail: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=2070&auto=format&fit=crop',
      videoUrl: codingVideo,
      authorId: 'system',
      authorName: 'System Academy',
      chapters: [
        Chapter(
          id: 'ch_${categoryName.toLowerCase().replaceAll(' ', '_')}_1',
          title: 'Chapter 1: Foundations & Core Concepts',
          order: 1,
          lectures: List.generate(5, (i) => Lecture(
                id: 'lec_${categoryName.toLowerCase().replaceAll(' ', '_')}_1_$i',
                title: 'Lesson ${i + 1}: Introduction to $categoryName Concepts',
                videoUrl: codingVideo,
                duration: '10:00',
                content: 'Basics of $categoryName.',
                order: i + 1,
              )),
        ),
        Chapter(
          id: 'ch_${categoryName.toLowerCase().replaceAll(' ', '_')}_2',
          title: 'Chapter 2: Advanced Projects & Scaling',
          order: 2,
          lectures: List.generate(5, (i) => Lecture(
                id: 'lec_${categoryName.toLowerCase().replaceAll(' ', '_')}_2_$i',
                title: 'Lesson ${i + 6}: Building a Real-World $categoryName Project',
                videoUrl: 'https://www.youtube.com/watch?v=rfscVS0vtbw', // freeCodeCamp
                duration: '45:00',
                content: 'Practical implementation.',
                order: i + 1,
              )),
        ),
      ],
      questions: _generateQuestions(categoryName),
    );
  }

  static List<Question> _generateQuestions(String context) {
    return List.generate(5, (i) => Question(
          text: 'Question ${i + 1}: What is a core principle in $context?',
          options: ['Option 1', 'Option 2', 'Option 3', 'Correct Professional Answer'],
          correctIndex: 3,
        ));
  }
}
