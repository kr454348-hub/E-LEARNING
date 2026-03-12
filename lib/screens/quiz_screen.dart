// ──────────────────────────────────────────────────────────
// quiz_screen.dart — Quiz List & Access
// ──────────────────────────────────────────────────────────
// Lists all available quizzes (courses with questions)
// Features:
// - Real-time updates via Firestore stream (optimized from polling)
// - Admin shortcut to edit quiz
// - Student access to take quiz
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'admin/admin_add_course_screen.dart';
import 'course_detail_screen.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Stream<List<Map<String, dynamic>>> _coursesStream;

  @override
  void initState() {
    super.initState();
    _coursesStream = DatabaseService().streamCollection('courses');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: const GlobalAppBar(
        title: "Quizzes",
        centerTitle: true,
        transparent: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _coursesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Course> quizzes = snapshot.data!
              .map((data) {
                return Course.fromMap(data, data['id']);
              })
              .where((course) {
                // Check if the source data has questions
                final dynamic data = snapshot.data!.firstWhere(
                  (d) => d['id'] == course.id,
                );
                return (data['has_questions'] ?? data['hasQuestions']) == true;
              })
              .toList();
          final courses = quizzes;

          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No quizzes available yet.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildQuizCard(context, course),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, Course course) {
    final isAdmin =
        Provider.of<AuthService>(context, listen: false).userModel?.role ==
        'admin';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (isAdmin) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminAddCourseScreen(course: course),
                ),
              );
            } else {
              // Navigate to course detail which has the quiz button
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(course: course),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9B93FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.category,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${course.questions.length} Questions",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  const Icon(Icons.edit, color: Colors.orange, size: 20)
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: theme.primaryColor,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
