// ──────────────────────────────────────────────────────────
// course_detail_screen.dart — Individual Course View
// ──────────────────────────────────────────────────────────
// Shows: Course info, lessons list, video playback, quiz
// Data: Firestore (lessons, questions) + CacheService
// Supports: YouTube, direct URLs, and embedded video
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/video_player_widget.dart';
import 'chat/chat_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final int initialLessonIndex;

  const CourseDetailScreen({
    super.key,
    required this.course,
    this.initialLessonIndex = -1,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int _currentLessonIndex = -1;
  final ProgressService _progressService = ProgressService();
  String? _userId;
  final GlobalKey<VideoPlayerWidgetState> _videoKey = GlobalKey<VideoPlayerWidgetState>();

  // Removed redundant state variables that are now derived in build()
  bool _isLoadingContent = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Get current user ID
    final authService = Provider.of<AuthService>(context, listen: false);
    _userId = authService.currentUser?.uid;

    if (_userId != null) {
      _restoreProgress();
    } else {
      _initializePlayer(widget.initialLessonIndex);
      setState(() => _isLoadingContent = false);
    }
  }

  Future<void> _restoreProgress() async {
    setState(() => _isLoadingContent = true);
    // 1. Check if we were passed an initial index (e.g. from Home Screen "Continue")
    if (widget.initialLessonIndex != -1) {
      _initializePlayer(widget.initialLessonIndex);
      return;
    }

    // 2. Otherwise, fetch from Firestore
    try {
      final db = DatabaseService();
      // Query by user_id only to avoid composite index with course_id
      final response = await db.query(
        'user_progress',
        where: 'user_id = ?',
        whereArgs: [_userId!],
      );

      // Client-side filtering for course_id
      final courseProgress = response.where((item) => item['course_id'] == widget.course.id);

      if (courseProgress.isNotEmpty) {
        final lastIndex =
            int.tryParse(courseProgress.first['last_lesson_id'] ?? '-1') ?? -1;
        if (lastIndex != -1 && lastIndex < widget.course.lessons.length) {
          if (mounted) {
            _initializePlayer(lastIndex);
            setState(() => _isLoadingContent = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Resuming from lesson ${lastIndex + 1}")),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("Error restoring progress: $e");
    }

    // 3. Fallback to start
    if (mounted) {
      _initializePlayer(widget.initialLessonIndex == -1 ? -1 : widget.initialLessonIndex);
      setState(() => _isLoadingContent = false);
    }
  }

  void _initializePlayer(int index) {
    if (!mounted) return;
    setState(() {
      _currentLessonIndex = index;
      String currentUrl = index == -1
          ? widget.course.videoUrl
          : (index < widget.course.lessons.length
              ? widget.course.lessons[index].videoUrl
              : "");

      _errorMessage = currentUrl.isEmpty ? "No video URL provided" : null;
    });
  }

  void _playLesson(int index, List<Lesson> lessons) {
    String url = index >= 0 && index < lessons.length
        ? lessons[index].videoUrl
        : widget.course.videoUrl;

    setState(() {
      _currentLessonIndex = index;
      _errorMessage = url.isEmpty ? "No video URL provided" : null;
    });

    if (_userId != null && index >= 0 && lessons.isNotEmpty) {
      _progressService.saveProgress(
        userId: _userId!,
        courseId: widget.course.id,
        lastLessonId: index.toString(),
        percentComplete: (index + 1) / lessons.length,
      );
    }
  }

  void _playNext(List<Lesson> lessons) {
    if (_currentLessonIndex < lessons.length - 1) {
      _playLesson(_currentLessonIndex + 1, lessons);
    }
  }

  void _playPrevious(List<Lesson> lessons) {
    if (_currentLessonIndex > -1) {
      _playLesson(_currentLessonIndex - 1, lessons);
    }
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  void _showReviewDialog(BuildContext context, String courseId) {
    final TextEditingController commentController = TextEditingController();
    double rating = 5.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Write a Review"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Rate this course:"),
                  Slider(
                    value: rating,
                    min: 1.0,
                    max: 5.0,
                    divisions: 4,
                    label: rating.toString(),
                    onChanged: (val) => setState(() => rating = val),
                  ),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: "Your Review",
                      hintText: "What did you like?",
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please login to review")),
                      );
                      return;
                    }
                    Navigator.pop(context);

                    final user = Provider.of<AuthService>(
                      context,
                      listen: false,
                    ).userModel;
                    try {
                      final db = DatabaseService();
                      await db.insert('course_reviews', {
                        'course_id': courseId,
                        'user_id': _userId,
                        'user_name': user?.name ?? "Student",
                        'rating': rating,
                        'comment': commentController.text.trim(),
                      });

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Review submitted locally!"),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String courseId = widget.course.id;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: DatabaseService().streamDocument('courses', courseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error loading course: ${snapshot.error}")),
          );
        }
        Course displayCourse = widget.course;
        List<Lesson> currentLessons = widget.course.lessons;
        List<Question> currentQuestions = widget.course.questions.whereType<Question>().toList();

        if (snapshot.hasData && snapshot.data != null) {
          displayCourse = Course.fromMap(
            snapshot.data!,
            snapshot.data!['id'] ?? courseId,
          );
          currentLessons = displayCourse.lessons;
          currentQuestions = displayCourse.questions.whereType<Question>().toList();
        }

        String currentVideoUrl = displayCourse.videoUrl;
        if (_currentLessonIndex >= 0 && _currentLessonIndex < currentLessons.length) {
          currentVideoUrl = currentLessons[_currentLessonIndex].videoUrl;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(displayCourse.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.forum),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        roomId: courseId,
                        otherUserName: displayCourse.title,
                        otherUserRole: 'course',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentVideoUrl.isNotEmpty)
                  _buildVideoPlayer(currentVideoUrl, currentLessons),
                if (_isLoadingContent)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCourseInfo(displayCourse, currentLessons),
                  ),
                  if (currentQuestions.isNotEmpty) _buildQuizButton(displayCourse, currentQuestions),
                  _buildNotesSection(displayCourse.category),
                  const Divider(),
                  _buildReviewsSection(courseId),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesSection(String category) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Study Materials",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService().streamCollection(
              'notes',
              where: 'category = ?',
              whereArgs: [category],
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text("Error: ${snapshot.error}");
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final notes = snapshot.data ?? [];
              if (notes.isEmpty) {
                return const Text(
                  "No supplementary notes available for this category.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }
              return Column(
                children: notes.map((data) {
                  final title = data['title'] ?? 'Untitled Note';
                  final pdfUrl = data['pdf_url'] ?? data['pdfUrl'];
                  final fileName =
                      data['file_name'] ?? data['fileName'] ?? "Download PDF";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.description,
                        color: Colors.blue,
                      ),
                      title: Text(title),
                      subtitle: Text(fileName),
                      trailing: pdfUrl != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.green,
                              ),
                              onPressed: () => launchUrl(
                                Uri.parse(pdfUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(String currentVideoUrl, List<Lesson> currentLessons) {
    if (_errorMessage != null) {
      return Container(
        height: 250,
        width: double.infinity,
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _initializePlayer(_currentLessonIndex),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        VideoPlayerWidget(
          key: ValueKey(currentVideoUrl), // Use ValueKey to force rebuild on URL change
          videoUrl: currentVideoUrl,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentLessonIndex > -1 ? () => _playPrevious(currentLessons) : null,
                icon: const Icon(Icons.skip_previous, size: 32),
                tooltip: "Previous Lesson",
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  onPressed: () => _videoKey.currentState?.togglePlay(),
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  tooltip: "Play/Pause",
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _videoKey.currentState?.pause(),
                icon: const Icon(Icons.stop, size: 32),
                tooltip: "Stop Video",
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _currentLessonIndex < currentLessons.length - 1
                    ? () => _playNext(currentLessons)
                    : null,
                icon: const Icon(Icons.skip_next, size: 32),
                tooltip: "Next Lesson",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseInfo(Course displayCourse, List<Lesson> lessons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayCourse.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(displayCourse.description, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        const Text(
          "Lessons",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (lessons.isEmpty)
          const Text("No lessons yet.")
        else
          ...lessons.asMap().entries.map((entry) {
            int idx = entry.key;
            var lesson = entry.value;
            bool isPlaying = _currentLessonIndex == idx;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isPlaying
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(
                  isPlaying
                      ? Icons.play_circle_filled
                      : Icons.play_circle_outline,
                  color: isPlaying
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                title: Text(
                  lesson.title,
                  style: TextStyle(
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    color: isPlaying ? Theme.of(context).primaryColor : null,
                  ),
                ),
                subtitle: Text(lesson.duration),
                onTap: () => _playLesson(idx, lessons),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildQuizButton(Course displayCourse, List<Question> questions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.quiz),
          label: Text(
            "Start Coding Knowledge Check (${questions.length} Questions)",
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseQuizScreen(course: displayCourse),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(String courseId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Reviews",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _showReviewDialog(context, courseId),
                icon: const Icon(Icons.rate_review),
                label: const Text("Write a Review"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseService().query(
              'course_reviews',
              where: 'course_id = ?',
              whereArgs: [courseId],
              // Removed orderBy to avoid missing composite index error
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text("Error: ${snapshot.error}");
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final reviews = snapshot.data!;
              if (reviews.isEmpty) {
                return const Center(
                  child: Text(
                    "No reviews yet. Be the first to review!",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: reviews.map((data) {
                  final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
                  final comment = data['comment'] as String? ?? "";
                  final userName = data['user_name'] as String? ?? "Anonymous";
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(userName[0].toUpperCase()),
                      ),
                      title: Row(
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(" $rating"),
                        ],
                      ),
                      subtitle: Text(comment),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Reconstructed CourseQuizScreen
class CourseQuizScreen extends StatefulWidget {
  final Course course;
  const CourseQuizScreen({super.key, required this.course});

  @override
  State<CourseQuizScreen> createState() => _CourseQuizScreenState();
}

class _CourseQuizScreenState extends State<CourseQuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _showResult = false;

  void _answerQuestion(int selectedIndex) {
    if (selectedIndex ==
        widget.course.questions[_currentQuestionIndex].correctIndex) {
      _score++;
    }

    setState(() {
      if (_currentQuestionIndex < widget.course.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _showResult = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return Scaffold(
        appBar: AppBar(title: const Text("Quiz Result")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Your Score: $_score / ${widget.course.questions.length}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back to Course"),
              ),
            ],
          ),
        ),
      );
    }

    final question = widget.course.questions[_currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(title: Text("Quiz: ${widget.course.title}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Question ${_currentQuestionIndex + 1} of ${widget.course.questions.length}",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              question.text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...List.generate(question.options.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => _answerQuestion(index),
                  child: Text(
                    question.options[index],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
