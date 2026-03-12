// ──────────────────────────────────────────────────────────
// admin_dashboard_screen.dart — Admin Panel Main Screen
// ──────────────────────────────────────────────────────────
// Shows: User management, content management, analytics,
//        course browsing, notes, search, and cache controls
// Access: Admin role only (enforced by AuthWrapper)
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import 'admin_users_screen.dart';
import 'admin_add_course_screen.dart';
import 'admin_manage_content_screen.dart';
import 'admin_layout.dart';

import '../../services/seed_courses.dart';
import '../../services/database_service.dart';
import '../chat/chat_list_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isDark = theme.brightness == Brightness.dark;

    return AdminLayout(
      title: "Admin Dashboard",
      activeRoute: 'dashboard',
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              _buildDesktopHeader(user, theme, isDark),
              const SizedBox(height: 32),
            ],

            // Stats / Welcome Section
            _buildWelcomeStats(context, user, theme, isDark, isDesktop),
            const SizedBox(height: 32),

            // Admin Actions Grid
            Text(
              "Quick Actions",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionGrid(context, isDesktop),
          ],
        ),
      ),
    );
  }

  // Methods moved to AdminLayout or refactored

  Widget _buildDesktopHeader(UserModel? user, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overview",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Welcome back, ${user?.name ?? 'Admin'}. Here's what's happening.",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        // Search Bar (Visual Only for now)
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey[400], size: 20),
              const SizedBox(width: 12),
              Text("Search...", style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeStats(
    BuildContext context,
    UserModel? user,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    final db = DatabaseService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.streamCollection(
        'users',
        where: 'role == ?',
        whereArgs: ['student'],
      ),
      builder: (context, studentSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.streamCollection(
            'users',
            where: 'role == ?',
            whereArgs: ['teacher'],
          ),
          builder: (context, teacherSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: db.streamCollection('courses'),
              builder: (context, courseSnapshot) {
                final studentCount = studentSnapshot.data?.length ?? 0;
                final teacherCount = teacherSnapshot.data?.length ?? 0;
                final courseCount = courseSnapshot.data?.length ?? 0;

                int totalViews = 0;
                if (courseSnapshot.hasData) {
                  for (var course in courseSnapshot.data!) {
                    totalViews += (course['views'] as num?)?.toInt() ?? 0;
                  }
                }

                if (isDesktop) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Total Students",
                          studentCount.toString(),
                          Icons.people_alt,
                          const Color(0xFF4F46E5),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Active Courses",
                          courseCount.toString(),
                          Icons.school,
                          const Color(0xFF10B981),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Total Teachers",
                          teacherCount.toString(),
                          Icons.person_search_rounded,
                          const Color(0xFFF59E0B),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          "Total Views",
                          totalViews.toString(),
                          Icons.visibility_rounded,
                          const Color(0xFFEC4899),
                          isDark,
                        ),
                      ),
                    ],
                  );
                }

                // Mobile Header
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.4),
                        offset: const Offset(0, 10),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: (user?.photoUrl.isNotEmpty == true)
                                ? NetworkImage(user!.photoUrl)
                                : null,
                            child: (user?.photoUrl.isEmpty ?? true)
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Welcome Back,",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                user?.name ?? "Admin",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMobileStatItem(
                            "Students",
                            studentCount.toString(),
                          ),
                          _buildMobileStatItem(
                            "Courses",
                            courseCount.toString(),
                          ),
                          _buildMobileStatItem(
                            "Teachers",
                            teacherCount.toString(),
                          ),
                          _buildMobileStatItem("Views", totalViews.toString()),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, bool isDesktop) {
    // Defines actions
    final actions = [
      _ActionItem(
        title: "Manage Users",
        subtitle: "Ban/Unban accounts",
        icon: Icons.people_alt_rounded,
        colors: [const Color(0xFF4F46E5), const Color(0xFF818CF8)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        ),
      ),
      _ActionItem(
        title: "Add Course",
        subtitle: "Create new content",
        icon: Icons.add_box_rounded,
        colors: [const Color(0xFF059669), const Color(0xFF34D399)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAddCourseScreen()),
        ),
      ),
      _ActionItem(
        title: "Manage Content",
        subtitle: "Edit courses & videos",
        icon: Icons.library_books_rounded,
        colors: [const Color(0xFFDB2777), const Color(0xFFF472B6)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminManageContentScreen()),
        ),
      ),
      _ActionItem(
        title: "Refresh Cache",
        subtitle: "Sync with Firebase",
        icon: Icons.refresh_rounded,
        colors: [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
        onTap: () async {
          // ... Cache clearing logic ...
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
          await CacheService().clearAllCaches();
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Cache cleared!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
      _ActionItem(
        title: "Student Chats",
        subtitle: "View messages",
        icon: Icons.chat_bubble_rounded,
        colors: [const Color(0xFFEA580C), const Color(0xFFFB923C)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        ),
      ),
      _ActionItem(
        title: "Seed Data",
        subtitle: "Populate db",
        icon: Icons.auto_awesome_rounded,
        colors: [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
        onTap: () async {
          // ... Seed data logic ...
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
          try {
            await SeedCourses.seedAll();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Seeded!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) Navigator.pop(context);
          }
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive column count
        int crossAxisCount = isDesktop
            ? 4
            : (constraints.maxWidth > 600 ? 3 : 2);
        // On very small mobile, maybe 1 column? No, 2 is usually fine for icons.
        double childAspectRatio = isDesktop ? 1.2 : 1.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            return _buildNewActionCard(context, actions[index], isDesktop);
          },
        );
      },
    );
  }

  Widget _buildNewActionCard(
    BuildContext context,
    _ActionItem item,
    bool isDesktop,
  ) {
    // isDark not used here, colors are fixed
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: item.colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.colors.last.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative Circle
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 10 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 16 : 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: isDesktop ? 12 : 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  // Drawer removed as it's now handled by AdminLayout
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
}
