import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import '../courses_screen.dart';
import 'admin_manage_content_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../core/app_theme.dart';

class AdminLayout extends StatelessWidget {
  final Widget body;
  final String title;
  final String
  activeRoute; // 'dashboard', 'users', 'courses', 'content', 'messages'
  final List<Widget>? actions;

  const AdminLayout({
    super.key,
    required this.body,
    required this.title,
    required this.activeRoute,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).userModel;
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: actions,
            ),
      drawer: isDesktop
          ? null
          : _AdminDrawer(user: user, activeRoute: activeRoute),
      body: Row(
        children: [
          if (isDesktop)
            _AdminSidebar(user: user, activeRoute: activeRoute, isDark: isDark),
          Expanded(
            child: Container(
              decoration: AppTheme.premiumBackground(isDark),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final UserModel? user;
  final String activeRoute;
  final bool isDark;

  const _AdminSidebar({
    required this.user,
    required this.activeRoute,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "AdminPanel",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  title: "Dashboard",
                  icon: Icons.dashboard,
                  isActive: activeRoute == 'dashboard',
                  onTap: () => _navigate(context, 'dashboard'),
                  isDark: isDark,
                ),
                _SidebarItem(
                  title: "Users",
                  icon: Icons.people,
                  isActive: activeRoute == 'users',
                  onTap: () => _navigate(context, 'users'),
                  isDark: isDark,
                ),
                _SidebarItem(
                  title: "Courses",
                  icon: Icons.school,
                  isActive: activeRoute == 'courses',
                  onTap: () => _navigate(context, 'courses'),
                  isDark: isDark,
                ),
                _SidebarItem(
                  title: "Content",
                  icon: Icons.library_books,
                  isActive: activeRoute == 'content',
                  onTap: () => _navigate(context, 'content'),
                  isDark: isDark,
                ),
                _SidebarItem(
                  title: "Messages",
                  icon: Icons.chat_bubble,
                  isActive: activeRoute == 'messages',
                  onTap: () => _navigate(context, 'messages'),
                  isDark: isDark,
                ),
                const Divider(height: 32),
                _SidebarItem(
                  title: "Logout",
                  icon: Icons.logout,
                  isActive: false,
                  isLogout: true,
                  onTap: () => _handleLogout(context),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          // User Profile Snippet
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: (user?.photoUrl.isNotEmpty == true)
                      ? NetworkImage(user!.photoUrl)
                      : null,
                  child: (user?.photoUrl.isEmpty ?? true)
                      ? Text(
                          user?.name.isNotEmpty == true ? user!.name[0] : "A",
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? "Admin",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? "",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (route == activeRoute) return;

    // Simple navigation replacement for now.
    // Ideally use GoRouter for better shell feel, but this works.
    Widget page;
    switch (route) {
      case 'dashboard':
        page = const AdminDashboardScreen();
        break;
      case 'users':
        page = const AdminUsersScreen();
        break;
      case 'courses':
        page = const CoursesScreen(); // Reuse existing
        break;
      case 'content':
        page = const AdminManageContentScreen();
        break;
      case 'messages':
        page = const ChatListScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero, // Instant switch for shell feel
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
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
}

class _SidebarItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final bool isLogout;

  const _SidebarItem({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;
    final inactiveColor = isDark ? Colors.grey[400] : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? activeColor.withValues(alpha: 0.1)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isLogout
              ? Colors.red
              : (isActive ? activeColor : inactiveColor),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout
                ? Colors.red
                : (isActive ? activeColor : inactiveColor),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final UserModel? user;
  final String activeRoute;

  const _AdminDrawer({required this.user, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.primaryColor),
            accountName: Text(user?.name ?? "Admin"),
            accountEmail: Text(user?.email ?? ""),
            currentAccountPicture: CircleAvatar(
              child: Text(user?.name.isNotEmpty == true ? user!.name[0] : "A"),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            selected: activeRoute == 'dashboard',
            onTap: () => _navigate(context, 'dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Manage Users"),
            selected: activeRoute == 'users',
            onTap: () => _navigate(context, 'users'),
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text("Courses"),
            selected: activeRoute == 'courses',
            onTap: () => _navigate(context, 'courses'),
          ),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text("Content"),
            selected: activeRoute == 'content',
            onTap: () => _navigate(context, 'content'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble),
            title: const Text("Messages"),
            selected: activeRoute == 'messages',
            onTap: () => _navigate(context, 'messages'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              // ... Logout logic duplicated due to StatelessWidget context constraints ...
              // ideally handle via provider/service call
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (route == activeRoute) {
      Navigator.pop(context); // just close drawer
      return;
    }

    Navigator.pop(context); // close drawer first

    Widget page;
    switch (route) {
      case 'dashboard':
        page = const AdminDashboardScreen();
        break;
      case 'users':
        page = const AdminUsersScreen();
        break;
      case 'courses':
        page = const CoursesScreen();
        break;
      case 'content':
        page = const AdminManageContentScreen();
        break;
      case 'messages':
        page = const ChatListScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }
}
