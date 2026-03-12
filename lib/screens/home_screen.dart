// ──────────────────────────────────────────────────────────
// home_screen.dart — Student Dashboard (Main Screen)
// ──────────────────────────────────────────────────────────
// Shows: Courses, categories, learning paths, recommendations
// Bottom nav: Home, Courses, Notes, Progress, Profile
// ──────────────────────────────────────────────────────────

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/progress_service.dart';
import '../core/app_constants.dart';
import 'courses_screen.dart';
import 'category_courses_screen.dart';
import 'course_detail_screen.dart';
import 'profile_screen.dart';
import 'notes_screen.dart';

import '../widgets/app_drawer.dart';
import 'admin/admin_manage_content_screen.dart';
import 'search/global_search_delegate.dart';
import 'chat/chat_list_screen.dart';
import 'live_classes_screen.dart';
import '../core/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Container(
        decoration: AppTheme.premiumBackground(isDark),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardTab(
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigate: (index) => setState(() => _currentIndex = index),
            ),
            const CoursesScreen(),
            const ChatListScreen(), // 1:1 messaging with teachers
            const NotesScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: "Courses",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: "Chat",
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: "Notes",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final Function(int)? onNavigate;

  const DashboardTab({super.key, this.onMenuTap, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressService = ProgressService();

    // Responsive Breakpoints
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 1. Header Section ───
              _buildHeader(context, user, theme, isDark),

              // ─── 2. Categories ───
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    _buildSectionHeader(
                      context,
                      "Categories",
                      onSeeAll: () {
                        if (onNavigate != null) {
                          onNavigate!(1); // Go to Courses tab
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: AppCategories.mainCategories.take(6).map((
                          cat,
                        ) {
                          return _buildCategoryItem(
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

              // ─── 3. Resume Learning ───
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, "Continue Learning"),
                      const SizedBox(height: 16),
                      _buildContinueLearningList(
                        context,
                        user.uid,
                        progressService,
                        isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ─── 4. Featured Courses ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, "Featured Courses"),
                    const SizedBox(height: 16),
                    _buildFeaturedCoursesList(context, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─── 5. Quick Actions ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildActivityCards(context, user, isDesktop),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic user,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        // Subtle Gradient Overlay
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Menu + Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: onMenuTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              GestureDetector(
                onTap: () {
                  if (onNavigate != null) onNavigate!(4); // Go to Profile
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: user?.photoUrl.isNotEmpty == true
                        ? (user!.photoUrl.startsWith('http')
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : (kIsWeb
                                ? NetworkImage(user.photoUrl)
                                : FileImage(File(user.photoUrl)) as ImageProvider))
                        : null,
                    backgroundColor: Colors.white24,
                    child: user?.photoUrl.isEmpty ?? true
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Row 2: Greeting
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${user?.name.isNotEmpty == true ? user!.name.split(' ').first : 'Student'}! 👋",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "What would you like\nto learn today?",
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Row 3: Search Bar
          GestureDetector(
            onTap: () =>
                showSearch(context: context, delegate: GlobalSearchDelegate()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: theme.primaryColor,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    "Search for courses, mentors...",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text("See All")),
      ],
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryCoursesScreen(categoryName: title),
                      ),
                    );
                  }
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Center(child: Icon(icon, color: color, size: 32)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearningList(
    BuildContext context,
    String uid,
    ProgressService service,
    bool isDark,
  ) {
    final db = DatabaseService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.streamCollection('courses'),
      builder: (context, coursesSnapshot) {
        if (!coursesSnapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allCourses = coursesSnapshot.data!;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: service.getAllProgressStream(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              // Empty State
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start your journey!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Enroll in a course to track progress.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final progressList = snapshot.data!;
            final List<Widget> items = [];

            for (var progress in progressList) {
              final courseId = progress['course_id'];
              final courseData = allCourses.firstWhere(
                (c) => c['id'] == courseId,
                orElse: () => {},
              );

              if (courseData.isEmpty) continue;

              final course = Course.fromMap(courseData, courseId);
              final percent =
                  (progress['percent_complete'] ??
                          progress['percentComplete'] as num?)
                      ?.toDouble() ??
                  0.0;

              items.add(
                Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildCourseProgressCard(
                    context,
                    course,
                    percent,
                    isDark,
                  ),
                ),
              );
            }

            return SizedBox(
              height: 200, // Increased height for better card layout
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: items,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCourseProgressCard(
    BuildContext context,
    Course course,
    double percent,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
            );
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: course.thumbnail,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 110,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 110,
                      color: Colors.grey,
                      child: const Icon(Icons.error),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[200],
                      color: Theme.of(context).primaryColor,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(percent * 100).toInt()}% Complete",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCoursesList(BuildContext context, bool isDark) {
    final db = DatabaseService();
    return StreamBuilder<List<Course>>(
      stream: db.streamCollection('courses', limit: 10).map((list) {
        return list.map((data) => Course.fromMap(data, data['id'])).toList();
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 50,
            child: Center(child: Text("No courses available at the moment.")),
          );
        }

        final courses = snapshot.data!;
        return SizedBox(
          height: 260, // Increased height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildFeaturedCourseCard(context, course, isDark),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFeaturedCourseCard(
    BuildContext context,
    Course course,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
      ),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Hero(
              tag: 'course_img_${course.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: CachedNetworkImage(
                  imageUrl: course.thumbnail,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 130,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 130,
                    color: Colors.grey,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${course.lessons.length} Lessons",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCards(
    BuildContext context,
    dynamic user,
    bool isDesktop,
  ) {
    // Actions List
    final actions = [
      _ActionItem(
        title: "Live Classes",
        subtitle: "Join sessions",
        icon: Icons.video_camera_front_rounded,
        gradient: [Colors.redAccent, Colors.pinkAccent],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LiveClassesScreen()),
        ),
      ),
      _ActionItem(
        title: "My Notes",
        subtitle: "Review key points",
        icon: Icons.edit_note_rounded,
        gradient: [const Color(0xFFFF512F), const Color(0xFFDD2476)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesScreen()),
        ),
      ),
      if (user?.role == 'admin')
        _ActionItem(
          title: "Admin Panel",
          subtitle: "Manage App",
          icon: Icons.admin_panel_settings_rounded,
          gradient: [Colors.orange.shade800, Colors.orange.shade400],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminManageContentScreen()),
          ),
        ),
    ];

    if (isDesktop) {
      // Grid for desktop
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: actions
            .map(
              (a) => SizedBox(width: 200, child: _buildActionCard(context, a)),
            )
            .toList(),
      );
    }

    // List/Row for mobile
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionCard(context, actions[0])),
            if (actions.length > 1) ...[
              const SizedBox(width: 16),
              Expanded(child: _buildActionCard(context, actions[1])),
            ],
          ],
        ),
        if (actions.length > 2) ...[
          const SizedBox(height: 16),
          _buildActionCard(context, actions[2], fullWidth: true),
        ],
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    _ActionItem item, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: item.gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}
