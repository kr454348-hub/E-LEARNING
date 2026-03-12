import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/course.dart';
import 'admin_add_course_screen.dart';
import 'admin_notes_screen.dart';
import 'admin_chapters_screen.dart';
import 'admin_layout.dart';
import '../../widgets/global_app_bar.dart';

class AdminManageContentScreen extends StatefulWidget {
  const AdminManageContentScreen({super.key});

  @override
  State<AdminManageContentScreen> createState() =>
      _AdminManageContentScreenState();
}

class _AdminManageContentScreenState extends State<AdminManageContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    final isAdmin = user?.role == 'admin';
    final isTeacher = user?.role == 'teacher';
    final canManage = isAdmin || isTeacher;

    if (!canManage) {
      return const Scaffold(
        // Fallback if regular user somehow gets here
        appBar: GlobalAppBar(title: "Access Denied"),
        body: Center(
          child: Text("Only Teachers and Admins can manage content."),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AdminLayout(
      title: "Content Management",
      activeRoute: 'content',
      body: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.primaryColor,
              tabs: const [
                Tab(text: "Courses", icon: Icon(Icons.video_library)),
                Tab(text: "Notes", icon: Icon(Icons.note)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AdminManageCoursesList(),
                AdminNotesScreen(), // Assuming this is compatible or needs wrapper?
                // AdminNotesScreen likely has its own Scaffold. Ideally we should strip it.
                // But for now let's hope it behaves or we refactor it next.
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            if (_tabController.index == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAddCourseScreen()),
              );
            } else {
              showAddEditNoteDialog(context);
            }
          },
          tooltip: "Add New",
        ),
      ],
    );
  }
}

class AdminManageCoursesList extends StatelessWidget {
  const AdminManageCoursesList({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final user = Provider.of<AuthService>(context).userModel;
    final isTeacher = user?.role == 'teacher';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: isTeacher
          ? db.streamCollection(
              'courses',
              where: 'authorId = ?',
              whereArgs: [user!.uid],
            )
          : db.streamCollection('courses'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text("No courses available to manage."));
        }

        // Group courses by category
        final Map<String, List<Map<String, dynamic>>> groupedCourses = {};
        for (var item in data) {
          final category = item['category'] ?? 'Uncategorized';
          if (!groupedCourses.containsKey(category)) {
            groupedCourses[category] = [];
          }
          groupedCourses[category]!.add(item);
        }

        final sortedCategories = groupedCourses.keys.toList()..sort();

        return ListView.builder(
          itemCount: sortedCategories.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final category = sortedCategories[index];
            final categoryCourses = groupedCourses[category]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  _buildCourseGrid(context, categoryCourses, isDesktop),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCourseGrid(
    BuildContext context,
    List<Map<String, dynamic>> coursesData,
    bool isDesktop,
  ) {
    final crossAxisCount = isDesktop
        ? 4
        : (MediaQuery.of(context).size.width > 600 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop
            ? 0.9
            : 3.0, // Desktop cards vertical, Mobile horizontal-ish? Or just use same?
        // Let's stick to standard card ratio for desktop, and maybe 3.0 for mobile list tile look
        // Actually, let's make mobile look like cards too if >1 col, but 1 col mobile can be ListTile-like list
      ),
      itemCount: coursesData.length,
      itemBuilder: (context, index) {
        final course = Course.fromMap(
          coursesData[index],
          coursesData[index]['id'],
        );
        if (!isDesktop && crossAxisCount == 1) {
          return _buildMobileCourseCard(context, course);
        }
        return _buildDesktopCourseCard(context, course);
      },
    );
  }

  Widget _buildMobileCourseCard(BuildContext context, Course course) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: course.thumbnail.isNotEmpty
              ? Image.network(
                  course.thumbnail,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.school),
                ),
        ),
        title: Text(
          course.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${course.lessons.length} Lessons • ${course.category}",
          maxLines: 1,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminAddCourseScreen(course: course),
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminChaptersScreen(
              courseId: course.id,
              courseTitle: course.title,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCourseCard(BuildContext context, Course course) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminChaptersScreen(
              courseId: course.id,
              courseTitle: course.title,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: course.thumbnail.isNotEmpty
                  ? Image.network(
                      course.thumbnail,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.school, size: 40, color: Colors.grey),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${course.lessons.length} Lessons",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            color: Theme.of(context).primaryColor,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AdminAddCourseScreen(course: course),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.menu_book,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
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
}
