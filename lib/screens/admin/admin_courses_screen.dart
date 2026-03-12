import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/global_app_bar.dart';
import '../../models/course.dart';
import '../course_detail_screen.dart';
import 'admin_add_course_screen.dart';

class AdminCoursesScreen extends StatelessWidget {
  const AdminCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: const GlobalAppBar(title: 'Manage Courses'),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAddCourseScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.streamCollection('courses'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          debugPrint(
            "🔍 [AdminCoursesScreen] snapshot.hasData=${snapshot.hasData}, length=${snapshot.data?.length ?? 0}",
          );

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final raw = snapshot.data ?? [];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No courses found.'),
                    const SizedBox(height: 8),
                    Text('Debug: ${jsonEncode(raw)}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final coursesData = snapshot.data!;
          final courses = coursesData
              .map((data) => Course.fromMap(data, data['id']))
              .toList();

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              return ListTile(
                leading: course.thumbnail.isNotEmpty
                    ? Image.network(
                        course.thumbnail,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.book),
                      )
                    : const Icon(Icons.book),
                title: Text(course.title),
                subtitle: Text(course.category),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(course: course),
                        ),
                      ),
                      tooltip: 'View Course',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminAddCourseScreen(course: course),
                        ),
                      ),
                      tooltip: 'Edit Course',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCourse(context, db, course.id),
                      tooltip: 'Delete Course',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _deleteCourse(
    BuildContext context,
    DatabaseService db,
    String courseId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure? This is permanent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await db.delete('courses', docId: courseId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Course deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
