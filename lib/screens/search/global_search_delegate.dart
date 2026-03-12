import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../models/note.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../course_detail_screen.dart';
import '../../core/app_theme.dart';

class GlobalSearchDelegate extends SearchDelegate {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      const SizedBox(width: 8),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchContent(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchContent(context);
  }

  Widget _buildSearchContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = DatabaseService();
    final user = Provider.of<AuthService>(context, listen: false).userModel;

    return Container(
      decoration: AppTheme.premiumBackground(isDark),
      child: Column(
        children: [
          // ─── Filter Chips ───
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _selectedFilter = filter;
                        showSuggestions(context);
                      }
                    },
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    selectedColor: theme.primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : (isDark ? Colors.white70 : Colors.black54),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? theme.primaryColor : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Results ───
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                db.query('courses'),
                if (user != null)
                  db.query('notes', where: 'author_id = ?', whereArgs: [user.uid])
                else
                  Future.value([]),
              ]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final results = _processSnapshots(snapshot.data);
                final courses = results['courses'] as List<Course>;
                final lessons = results['lessons'] as List<Map<String, dynamic>>;
                final notes = results['notes'] as List<Note>;

                final filteredCourses = _filterList(courses, query, (c) => c.title, (c) => c.category, (c) => c.level);
                final filteredLessons = lessons.where((item) {
                  final lesson = item['lesson'];
                  final course = item['course'] as Course;
                  final matchesQuery = lesson.title.toLowerCase().contains(query.toLowerCase());
                  final matchesFilter = _selectedFilter == 'All' || course.level == _selectedFilter;
                  return matchesQuery && matchesFilter;
                }).toList();
                final filteredNotes = _selectedFilter == 'All' 
                    ? _filterList(notes, query, (n) => n.title, (n) => n.content, (n) => "All") 
                    : <Note>[];

                if (filteredCourses.isEmpty && filteredLessons.isEmpty && filteredNotes.isEmpty) {
                  return _buildEmptyState(query);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (filteredCourses.isNotEmpty) ...[
                      _buildSectionHeader("Courses", Icons.school_rounded, Colors.blue),
                      ...filteredCourses.map((c) => _buildCourseCard(context, c, isDark)),
                      const SizedBox(height: 16),
                    ],
                    if (filteredLessons.isNotEmpty) ...[
                      _buildSectionHeader("Lessons", Icons.play_circle_fill_rounded, Colors.purple),
                      ...filteredLessons.map((l) => _buildLessonCard(context, l, isDark)),
                      const SizedBox(height: 16),
                    ],
                    if (filteredNotes.isNotEmpty) ...[
                      _buildSectionHeader("Notes", Icons.note_alt_rounded, Colors.orange),
                      ...filteredNotes.map((n) => _buildNoteCard(context, n, isDark)),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _processSnapshots(List<dynamic>? data) {
    final rawCourses = data?[0];
    final List<Map<String, dynamic>> coursesList = (rawCourses is List) ? List<Map<String, dynamic>>.from(rawCourses) : [];
    final rawNotes = data?[1];
    final List<Map<String, dynamic>> notesList = (rawNotes is List) ? List<Map<String, dynamic>>.from(rawNotes) : [];

    final courses = coursesList.map((d) => Course.fromMap(d, d['id'])).toList();
    final notes = notesList.map((d) => Note.fromMap(d, d['id'])).toList();

    final List<Map<String, dynamic>> lessons = [];
    for (var c in courses) {
      for (int i = 0; i < c.lessons.length; i++) {
        lessons.add({'course': c, 'lessonIndex': i, 'lesson': c.lessons[i]});
      }
    }

    return {'courses': courses, 'lessons': lessons, 'notes': notes};
  }

  List<T> _filterList<T>(
    List<T> list,
    String query,
    String Function(T) titleGetter,
    String Function(T) categoryGetter,
    String Function(T) levelGetter,
  ) {
    final q = query.toLowerCase();
    return list.where((item) {
      final matchesQuery = titleGetter(item).toLowerCase().contains(q) || categoryGetter(item).toLowerCase().contains(q);
      final matchesFilter = _selectedFilter == 'All' || levelGetter(item) == _selectedFilter;
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, Course course, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 60,
            height: 60,
            child: course.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: course.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                    errorWidget: (_, __, ___) => const Icon(Icons.school),
                  )
                : const Icon(Icons.school, size: 30),
          ),
        ),
        title: Text(
          course.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.category_rounded, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(course.category, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.level,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.primaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          close(context, null);
          Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
        },
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final Course course = item['course'];
    final lesson = item['lesson'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.purple),
        ),
        title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text("In: ${course.title}", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: () {
          close(context, null);
          Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)));
        },
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.note_alt_rounded, color: Colors.orange, size: 20),
        ),
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        onTap: () {
          close(context, null);
          _showNoteDialog(context, note);
        },
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            query.isEmpty ? "Start typing to search" : "No results for \"$query\"",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text("Try a different keyword or filter", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text("Oops! Something went wrong", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(note.content, style: const TextStyle(height: 1.5))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
