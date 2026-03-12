// ──────────────────────────────────────────────────────────
// courses_screen.dart — Browse All Courses
// ──────────────────────────────────────────────────────────
// Displays: Grid of all courses with search and filtering
// Data source: Firestore via DatabaseService + CacheService
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../core/app_constants.dart';
import 'admin/admin_add_course_screen.dart';
import 'course_detail_screen.dart';
import 'category_courses_screen.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final DatabaseService _db = DatabaseService();
  late Stream<List<Map<String, dynamic>>> _coursesStream;

  @override
  void initState() {
    super.initState();
    _coursesStream = _db.streamCollection('courses');
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<AuthService>(context).userModel;
    final isAdmin = userModel?.role == 'admin';
    final isTeacher = userModel?.role == 'teacher';
    final canManage = isAdmin || isTeacher;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Responsive Calcs
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width > 600) crossAxisCount = 2;
    if (width > 900) crossAxisCount = 3;
    if (width > 1200) crossAxisCount = 4;

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: GlobalAppBar(
        title: "Explore Courses",
        centerTitle: false,
        transparent: true,
        leading: Navigator.canPop(context)
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAddCourseScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text("Add Course"),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Categories Section ───
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                      child: Text(
                        "Browse Categories",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        children: AppCategories.mainCategories.map((cat) {
                          return _buildCategoryChip(
                            context,
                            cat['name'],
                            cat['icon'],
                            cat['color'],
                            isDark,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Languages Grid ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Master a Language",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildLanguageCard(
                      context,
                      AppCategories.codingLanguages[index],
                      isDark,
                    ),
                    childCount: AppCategories.codingLanguages.length,
                  ),
                ),
              ),

              // ─── All Courses Header ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "All Courses",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.filter_list_rounded,
                        color: theme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Courses Grid ───
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _coursesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(child: Text("Error: ${snapshot.error}")),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final courses = snapshot.data!
                      .map((data) => Course.fromMap(data, data['id']))
                      .toList();

                  if (courses.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.library_books_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No courses available yet",
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

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.85, // Adjust for card height
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildCourseCard(
                          context,
                          courses[index],
                          isAdmin,
                          userModel?.uid,
                          isDark,
                        );
                      }, childCount: courses.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    Map<String, dynamic> lang,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
                    color: (lang['color'] as Color).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(lang['icon'], color: lang['color'], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryCoursesScreen(categoryName: title),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    Course course,
    bool isAdmin,
    String? currentUserId,
    bool isDark,
  ) {
    final isAuthor = course.authorId == currentUserId;
    final showManagementItems = isAdmin || (isAuthor);
    final theme = Theme.of(context);

    // Modern "Apple-style" card
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Image Header ───
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: (course.thumbnail.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: course.thumbnail,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Container(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.school,
                                size: 40,
                                color: theme.primaryColor.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // "New" badge or Rating? Adding a rating badge for visual flair
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.rating > 0
                                ? "${course.rating.toStringAsFixed(1)} (${course.ratingCount})"
                                : "New",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showManagementItems)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _buildActionCircle(
                            Icons.edit,
                            Colors.orange,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminAddCourseScreen(course: course),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildActionCircle(
                            Icons.delete_outline,
                            Colors.red,
                            () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete Course?"),
                                  content: const Text("This cannot be undone."),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () async {
                                        await DatabaseService().delete(
                                          'courses',
                                          docId: course.id,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ─── Details ───
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            course.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course.description,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              course.authorName.isNotEmpty
                                  ? course.authorName
                                  : "Instructor",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${course.lessons.length} Lessons",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
        padding: const EdgeInsets.all(6),
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) => onTap());
        },
      ),
    );
  }
}
