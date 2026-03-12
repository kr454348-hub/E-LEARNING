import 'dart:convert';

// ──────────────────────────────────────────────────────────
// Course Model — Top-level course container
// Structure: Course → Chapter → Lecture (each with video/quiz/notes)
// ──────────────────────────────────────────────────────────

class Course {
  final String id;
  final String title;
  final String description;
  final String thumbnail;
  final String category;
  final String videoUrl; // Intro/preview video
  final List<Chapter> chapters;
  final List<dynamic> questions; // Legacy: course-level quiz
  final String authorId;
  final String authorName;
  final String level;
  final DateTime? createdAt;
  final double price;
  final double rating;
  final int ratingCount;

  Course({
    this.id = '',
    this.title = '',
    this.description = '',
    this.thumbnail = '',
    this.videoUrl = '',
    this.category = 'General',
    this.chapters = const [],
    this.questions = const [],
    this.authorId = '',
    this.authorName = '',
    this.level = 'Beginner',
    this.price = 0.0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.createdAt,
  });

  factory Course.fromMap(Map<String, dynamic> data, String documentId) {
    // Parse legacy lessons into chapters if needed
    dynamic lessonsData = data['lessons'];
    if (lessonsData is String && lessonsData.isNotEmpty) {
      try {
        lessonsData = jsonDecode(lessonsData);
      } catch (e) {
        lessonsData = [];
      }
    }

    dynamic questionsData = data['questions'];
    if (questionsData is String && questionsData.isNotEmpty) {
      try {
        questionsData = jsonDecode(questionsData);
      } catch (e) {
        questionsData = [];
      }
    }

    // Parse chapters (new structure)
    dynamic chaptersData = data['chapters'];
    List<Chapter> chapters = [];
    if (chaptersData is List) {
      chapters = chaptersData
          .whereType<Map<String, dynamic>>()
          .map((e) => Chapter.fromMap(e))
          .toList();
    } else if (lessonsData is List && (lessonsData).isNotEmpty) {
      // Legacy: convert flat lessons to a single chapter
      final legacyLectures = (lessonsData)
          .asMap()
          .entries
          .map(
            (entry) => Lecture(
              id: 'legacy_${entry.key}',
              title:
                  (entry.value as Map<String, dynamic>)['title'] ??
                  'Lesson ${entry.key + 1}',
              videoUrl:
                  (entry.value as Map<String, dynamic>)['video_url'] ??
                  (entry.value as Map<String, dynamic>)['videoUrl'] ??
                  '',
              duration: (entry.value as Map<String, dynamic>)['duration'] ?? '',
              order: entry.key,
            ),
          )
          .toList();
      if (legacyLectures.isNotEmpty) {
        chapters = [
          Chapter(
            id: 'legacy_chapter_0',
            title: 'Course Content',
            order: 0,
            lectures: legacyLectures,
          ),
        ];
      }
    }

    return Course(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      thumbnail: data['thumbnail'] ?? '',
      videoUrl: data['video_url'] ?? data['videoUrl'] ?? '',
      category: data['category'] ?? 'General',
      chapters: chapters,
      questions:
          (questionsData as List<dynamic>?)
              ?.map((e) => Question.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      authorId: (data['author_id'] ?? data['authorId'] ?? '').toString(),
      authorName: (data['author_name'] ?? data['authorName'] ?? '').toString(),
      level: data['level'] ?? 'Beginner',
      price: double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0,
      rating: double.tryParse(data['rating']?.toString() ?? '0.0') ?? 0.0,
      ratingCount: int.tryParse(data['ratingCount']?.toString() ?? '0') ?? 0,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
    );
  }

  /// Backward-compatible getter: flattens all chapters' lectures into legacy Lesson objects.
  /// Use this only in screens that haven't been migrated to the chapter/lecture model yet.
  List<Lesson> get lessons {
    final result = <Lesson>[];
    for (final chapter in chapters) {
      for (final lecture in chapter.lectures) {
        result.add(
          Lesson(
            title: lecture.title,
            videoUrl: lecture.videoUrl,
            duration: lecture.duration,
            content: lecture.content,
          ),
        );
      }
    }
    return result;
  }

  /// Total lecture count across all chapters
  int get totalLectures {
    int count = 0;
    for (final ch in chapters) {
      count += ch.lectures.length;
    }
    return count;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'video_url': videoUrl,
      'category': category,
      'chapters': chapters.map((e) => e.toMap()).toList(),
      'questions': questions.map((e) => e.toMap()).toList(),
      'has_questions': questions.isNotEmpty, // Automatically derive
      'author_id': authorId,
      'author_name': authorName,
      'level': level,
      'price': price,
      'rating': rating,
      'ratingCount': ratingCount,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnail,
    String? videoUrl,
    String? category,
    List<Chapter>? chapters,
    List<dynamic>? questions,
    String? authorId,
    String? authorName,
    String? level,
    double? price,
    double? rating,
    int? ratingCount,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnail: thumbnail ?? this.thumbnail,
      videoUrl: videoUrl ?? this.videoUrl,
      category: category ?? this.category,
      chapters: chapters ?? this.chapters,
      questions: questions ?? this.questions,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      level: level ?? this.level,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Chapter — Groups lectures within a course
// ──────────────────────────────────────────────────────────

class Chapter {
  final String id;
  final String title;
  final int order;
  final List<Lecture> lectures;

  Chapter({
    this.id = '',
    this.title = '',
    this.order = 0,
    this.lectures = const [],
  });

  factory Chapter.fromMap(Map<String, dynamic> data) {
    return Chapter(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      order: int.tryParse(data['order']?.toString() ?? '0') ?? 0,
      lectures:
          (data['lectures'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => Lecture.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'order': order,
      'lectures': lectures.map((e) => e.toMap()).toList(),
    };
  }

  Chapter copyWith({
    String? id,
    String? title,
    int? order,
    List<Lecture>? lectures,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      order: order ?? this.order,
      lectures: lectures ?? this.lectures,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Lecture — Individual lesson with video, notes, quiz
// ──────────────────────────────────────────────────────────

class Lecture {
  final String id;
  final String title;
  final String videoUrl;
  final String duration;
  final String content; // Notes/text content
  final List<Question> questions; // Quiz for this lecture
  final int order;

  Lecture({
    this.id = '',
    this.title = '',
    this.videoUrl = '',
    this.duration = '',
    this.content = '',
    this.questions = const [],
    this.order = 0,
  });

  factory Lecture.fromMap(Map<String, dynamic> data) {
    return Lecture(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      videoUrl: data['video_url'] ?? data['videoUrl'] ?? '',
      duration: data['duration'] ?? '',
      content: data['content'] ?? '',
      questions:
          (data['questions'] as List<dynamic>?)
              ?.map((e) => Question.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'video_url': videoUrl,
      'duration': duration,
      'content': content,
      'questions': questions.map((e) => e.toMap()).toList(),
      'order': order,
    };
  }

  Lecture copyWith({
    String? id,
    String? title,
    String? videoUrl,
    String? duration,
    String? content,
    List<Question>? questions,
    int? order,
  }) {
    return Lecture(
      id: id ?? this.id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      content: content ?? this.content,
      questions: questions ?? this.questions,
      order: order ?? this.order,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Question — Quiz question with multiple choice options
// ──────────────────────────────────────────────────────────

class Question {
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['text'] ?? '',
      options: (map['options'] as List<dynamic>?)?.cast<String>() ?? [],
      correctIndex: map['correct_index'] ?? map['correctIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'text': text, 'options': options, 'correct_index': correctIndex};
  }
}

// Legacy Lesson class — kept for backward compatibility
class Lesson {
  final String title;
  final String videoUrl;
  final String duration;
  final String content;

  Lesson({
    this.title = '',
    this.videoUrl = '',
    this.duration = '',
    this.content = '',
  });

  factory Lesson.fromMap(Map<String, dynamic> data) {
    return Lesson(
      title: data['title'] ?? '',
      videoUrl: data['video_url'] ?? data['videoUrl'] ?? '',
      duration: data['duration'] ?? '',
      content: data['content'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'video_url': videoUrl,
      'duration': duration,
      'content': content,
    };
  }
}
