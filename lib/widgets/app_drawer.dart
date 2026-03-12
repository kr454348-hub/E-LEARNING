import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/admin/admin_manage_content_screen.dart';
import '../screens/admin/admin_users_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          // Custom Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor,
                  const Color(0xFF8E2DE2), // Purple accent
                  const Color(0xFF4A00E0), // Deep blue accent
                ],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: user?.photoUrl.isNotEmpty == true
                  ? NetworkImage(user!.photoUrl)
                  : null,
              child: user?.photoUrl.isEmpty ?? true
                  ? Icon(Icons.person, size: 40, color: theme.primaryColor)
                  : null,
            ),
            accountName: Text(
              user?.name.isNotEmpty == true ? user!.name : "Student",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(user?.email ?? "email@example.com"),
          ),

          // Drawer Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  Icons.person_outline,
                  "Edit Profile",
                  () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      }
                    });
                  },
                ),
                _buildDrawerItem(context, Icons.bar_chart, "My Progress", () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.smart_toy, color: Colors.blue),
                  title: const Text('AI Tutor'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/ai_tutor');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt, color: Colors.amber),
                  title: const Text('Study Notes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotesScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.explore, color: Colors.green),
                  title: const Text('All Courses'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CoursesScreen()),
                    );
                  },
                ),
                if (user?.role == 'admin' || user?.role == 'teacher')
                  ListTile(
                    leading: const Icon(
                      Icons.library_books,
                      color: Colors.orange,
                    ),
                    title: const Text('Manage Content'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminManageContentScreen(),
                        ),
                      );
                    },
                  ),
                if (user?.role == 'admin')
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.blue),
                    title: const Text('Manage Users'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersScreen(),
                        ),
                      );
                    },
                  ),
                _buildDrawerItem(
                  context,
                  Icons.settings_outlined,
                  "Settings",
                  () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) Navigator.pop(context);
                    });
                  },
                ),
                if (user?.role == 'admin')
                  _buildDrawerItem(
                    context,
                    Icons.admin_panel_settings,
                    "Admin Dashboard",
                    () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        '/main',
                      ); // AuthWrapper will pick admin dashboard
                    },
                  ),
                if (user?.role == 'teacher')
                  _buildDrawerItem(
                    context,
                    Icons.dashboard_customize_outlined,
                    "Teacher Dashboard",
                    () {
                      Navigator.pop(context);
                      // Already on dashboard if they are a teacher, but this helps if they navigated away
                      Navigator.pushReplacementNamed(
                        context,
                        '/teacher-dashboard',
                      );
                    },
                  ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  Icons.help_outline,
                  "Help & Support",
                  () {
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(context, Icons.info_outline, "About App", () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: "E-Learning App",
                    applicationVersion: "1.0.0",
                  );
                }),
              ],
            ),
          ),

          // Bottom Logout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<AuthService>(context, listen: false).signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.grey[700]),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
