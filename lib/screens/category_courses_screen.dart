import 'package:flutter/material.dart';
import 'package:elearning_app/models/course.dart';
import 'package:elearning_app/screens/course_detail_screen.dart';
import 'package:elearning_app/services/database_service.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';

class CategoryCoursesScreen extends StatelessWidget {
  final String categoryName;

  const CategoryCoursesScreen({super.key, required this.categoryName});

  final List<Map<String, dynamic>> _codingLanguages = const [
    {"name": "C", "color": Color(0xFF555555), "icon": Icons.code},
    {
      "name": "C++",
      "color": Color(0xFF00599C),
      "icon": Icons.integration_instructions,
    },
    {"name": "Java", "color": Color(0xFF007396), "icon": Icons.coffee},
    {"name": "Python", "color": Color(0xFFFFD43B), "icon": Icons.pest_control},
    {
      "name": "JavaScript",
      "color": Color(0xFFF7DF1E),
      "icon": Icons.javascript,
    },
    {"name": "Kotlin", "color": Color(0xFF7F52FF), "icon": Icons.android},
    {"name": "Dart", "color": Color(0xFF0175C2), "icon": Icons.flutter_dash},
    {"name": "PHP", "color": Color(0xFF777BB4), "icon": Icons.php},
    {"name": "SQL", "color": Color(0xFF4479A1), "icon": Icons.table_chart},
    {"name": "Swift", "color": Color(0xFFFA7343), "icon": Icons.bolt},
  ];

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final List<String> codingLangs = _codingLanguages
        .map((l) => l['name'] as String)
        .toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: GlobalAppBar(title: "$categoryName Courses", transparent: true),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (categoryName == "Coding")
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Language",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _codingLanguages.length,
                      itemBuilder: (context, index) =>
                          _buildLanguageCard(context, _codingLanguages[index]),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "All Coding Courses",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Stream.periodic(
              const Duration(seconds: 5),
            ).asyncMap((_) => db.query('courses', orderBy: 'title ASC')),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(child: Text("Error: ${snapshot.error}")),
                );
              }
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              List<Map<String, dynamic>> rawData = snapshot.data!;
              List<Course> courses = rawData
                  .map((data) => Course.fromMap(data, data['id']))
                  .toList();

              if (categoryName == "Coding") {
                courses = courses
                    .where((c) => codingLangs.contains(c.category))
                    .toList();
              } else {
                courses = courses
                    .where((c) => c.category == categoryName)
                    .toList();
              }

              if (courses.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No courses found in $categoryName",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final course = courses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: course.thumbnail.isNotEmpty
                              ? Image.network(
                                  course.thumbnail,
                                  width: 80,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 60,
                                  color: Colors.grey[100],
                                  child: const Icon(
                                    Icons.school,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        title: Text(
                          course.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                course.rating > 0
                                    ? "${course.rating.toStringAsFixed(1)} (${course.ratingCount})"
                                    : "New",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "${course.lessons.length} Lessons",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(course: course),
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: courses.length),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, Map<String, dynamic> lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryCoursesScreen(categoryName: lang['name']),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (lang['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(lang['icon'], color: lang['color'], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
