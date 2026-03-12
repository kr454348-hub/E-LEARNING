import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/course.dart';
import 'course_detail_screen.dart';
import '../core/app_theme.dart';
import '../widgets/global_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userId = auth.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId == null) return const Center(child: Text("Please login"));

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: const GlobalAppBar(title: "My Favorites", transparent: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().streamSubCollection(
          'users',
          userId,
          'favorites',
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final favoriteIds = snapshot.data!
              .map((e) => e['id'] as String)
              .toList();

          if (favoriteIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No favorites yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService().streamCollection('courses'),
            builder: (context, courseSnapshot) {
              if (!courseSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final courses = courseSnapshot.data!
                  .map((e) => Course.fromMap(e, e['id']))
                  .where((c) => favoriteIds.contains(c.id))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: course.thumbnail,
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        course.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(course.category),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(course: course),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
