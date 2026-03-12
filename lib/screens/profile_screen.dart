// ──────────────────────────────────────────────────────────
// profile_screen.dart — Premium User Profile & Settings
// ──────────────────────────────────────────────────────────

import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/course_content_service.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingStats = true;
  String _stat1Label = "Courses";
  String _stat1Value = "0";
  String _stat2Label = "Success";
  String _stat2Value = "0%";
  String _stat3Label = "Points";
  String _stat3Value = "0";

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    try {
      final db = DatabaseService();

      if (user.role == 'admin') {
        final stats = await CourseContentService().getContentStats();
        _stat1Label = "Users";
        _stat1Value = (stats['users'] ?? 0).toString();
        _stat2Label = "Courses";
        _stat2Value = (stats['courses'] ?? 0).toString();
        _stat3Label = "Platform";
        _stat3Value = "Active";
      } else if (user.role == 'teacher') {
        final courses = await db.query(
          'courses',
          where: 'author_id = ?',
          whereArgs: [user.uid],
        );
        _stat1Label = "My Courses";
        _stat1Value = courses.length.toString();

        // Count enrollments across their courses
        int totalStudents = 0;
        for (var c in courses) {
           final enrolls = await db.query('enrollments', where: 'course_id = ?', whereArgs: [c['id']]);
           totalStudents += enrolls.length;
        }

        _stat2Label = "Students";
        _stat2Value = totalStudents.toString();
        _stat3Label = "Avg Rating";
        _stat3Value = "N/A"; // Placeholder or calculate if needed
      } else {
        // Student
        final enrolls = await db.query(
          'enrollments',
          where: 'user_id = ?',
          whereArgs: [user.uid],
        );
        _stat1Label = "Enrolled";
        _stat1Value = enrolls.length.toString();

        final favs = await db.query(
          'users/${user.uid}/favorites',
        );
        _stat2Label = "Favorites";
        _stat2Value = favs.length.toString();

        final books = await db.query(
          'users/${user.uid}/bookmarks',
        );
        _stat3Label = "Bookmarks";
        _stat3Value = books.length.toString();
      }
    } catch (e) {
      debugPrint("Error loading profile stats: $e");
    }

    if (mounted) {
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Loading State
    if (auth.isLoading && user == null) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.premiumBackground(isDark),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 2. Error/Missing Profile State
    if (user == null) {
      return AppTheme.backgroundScaffold(
        isDark: isDark,
        appBar: const GlobalAppBar(title: "My Profile"),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text(
                "Profile not found",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "We couldn't load your profile information.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out & Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: AppTheme.premiumBackground(isDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // --- Profile Avatar ---
                Center(
                  child: Builder(
                    builder: (context) {
                      ImageProvider? provider;
                      if (user.photoUrl.isNotEmpty) {
                        if (user.photoUrl.startsWith('http')) {
                          provider = NetworkImage(user.photoUrl);
                        } else if (!kIsWeb) {
                          provider = FileImage(File(user.photoUrl));
                        }
                      }
                      return CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: provider,
                        child: provider == null
                            ? Icon(Icons.person, size: 60, color: theme.primaryColor)
                            : null,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // --- User Name & Email ---
                Text(
                  user.name.isNotEmpty ? user.name : "User",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email.isNotEmpty ? user.email : "user@example.com",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),

                // Role badge
                if (user.role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // --- Edit Profile Button ---
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit Profile"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(200, 44),
                  ),
                ),

                const SizedBox(height: 10),

                // --- Change Password Button ---
                OutlinedButton.icon(
                  onPressed: () => _showChangePasswordDialog(context),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text("Change Password"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(200, 44),
                  ),
                ),

                const SizedBox(height: 30),

                // --- Dynamic Stats Layer (Retained) ---
                _buildStatsRow(context, isDark),
                
                const SizedBox(height: 30),

                // --- Profile Menu Items ---
                if (user.role != 'student') // Hide contributions from students
                  _buildProfileItem(
                    context,
                    Icons.upload_file,
                    "My Contributions",
                    () {
                      // Navigate to contents/contributions
                    },
                    isDark: isDark,
                    theme: theme,
                  ),
                  
                _buildProfileItem(
                  context,
                  Icons.history,
                  "History & Progress",
                  () {
                    // Navigate to progress
                  },
                  isDark: isDark,
                  theme: theme,
                ),
                _buildProfileItem(
                  context,
                  Icons.notifications_outlined,
                  "Notifications",
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("No new notifications"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: isDark ? const Color(0xFF252540) : null,
                      ),
                    );
                  },
                  isDark: isDark,
                  theme: theme,
                ),

                // Delete Account
                if (user.email != 'admin@admin.com')
                  _buildProfileItem(
                    context,
                    Icons.delete_forever,
                    "Delete Account",
                    () => _showDeleteAccountDialog(context),
                    isDark: isDark,
                    theme: theme,
                    isDestructive: true,
                  ),

                _buildProfileItem(
                  context,
                  Icons.settings_outlined,
                  "Settings",
                  () {
                    // Navigate to settings
                  },
                  isDark: isDark,
                  theme: theme,
                ),
                
                _buildProfileItem(
                  context,
                  Icons.help_outline,
                  "Help & Support",
                  () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Contact: support@sketchlearn.com"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: isDark ? const Color(0xFF252540) : null,
                      ),
                    );
                  },
                  isDark: isDark,
                  theme: theme,
                ),

                // --- Admin Section (only for admin role) ---
                if (user.role == 'admin') ...[
                  const Divider(height: 40),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Administrative",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileItem(
                    context,
                    Icons.admin_panel_settings,
                    "Admin Dashboard",
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                    isDark: isDark,
                    theme: theme,
                  ),
                ],

                const Divider(height: 40),

                // --- Logout Button ---
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single profile menu item card
  Widget _buildProfileItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    required bool isDark,
    required ThemeData theme,
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isDark ? const Color(0xFF252540) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : theme.primaryColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[500],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, bool isDark) {
    if (_isLoadingStats) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(_stat1Label, _stat1Value, Icons.menu_book_rounded, isDark),
        _buildStatDivider(isDark),
        _buildStatItem(_stat2Label, _stat2Value, Icons.insights_rounded, isDark),
        _buildStatDivider(isDark),
        _buildStatItem(_stat3Label, _stat3Value, Icons.workspace_premium_rounded, isDark),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: isDark ? Colors.indigoAccent : Colors.indigo,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.white10 : Colors.grey[300],
    );
  }


  // ──────────────────────────────────────────────────────────
  // DIALOGS & HELPERS (Logic preserved)
  // ──────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) async {
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
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
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

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent and cannot be undone.\n"
          "All your progress will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              try {
                await authService.deleteAccount();
                navigator.pushNamedAndRemoveUntil('/', (route) => false);
              } catch (e) {
                String msg = "Error deleting account: $e";
                if (e.toString().contains('requires-recent-login') ||
                    e.toString().contains('sensitive')) {
                  msg = "Please log in again to confirm deletion. Logging out...";
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                  await Future.delayed(const Duration(seconds: 2));
                  await authService.signOut();
                  navigator.pushNamedAndRemoveUntil('/', (route) => false);
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Current Password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm New Password",
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final current = currentPasswordController.text.trim();
                          final newPass = newPasswordController.text.trim();
                          final confirm = confirmPasswordController.text.trim();
                          if (current.isEmpty || newPass.isEmpty) return;
                          if (newPass != confirm) return;

                          setState(() => isLoading = true);
                          try {
                            final auth =
                                Provider.of<AuthService>(context, listen: false);
                            await auth.changePassword(newPass);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

