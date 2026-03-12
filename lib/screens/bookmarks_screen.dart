import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../core/app_theme.dart';
import '../widgets/global_app_bar.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userId = auth.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId == null) return const Center(child: Text("Please login"));

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: const GlobalAppBar(title: "My Bookmarks", transparent: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().streamSubCollection(
          'users',
          userId,
          'bookmarks',
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookmarkIds = snapshot.data!
              .map((e) => e['id'] as String)
              .toList();

          if (bookmarkIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No bookmarks yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // This is a bit complex as bookmarks are lessons within courses.
          // For now, let's just show the IDs or implement a search.
          // In a real app, we'd store courseId + lessonId in the bookmark doc.
          return const Center(
            child: Text("Bookmarks recorded. Integration pending."),
          );
        },
      ),
    );
  }
}
