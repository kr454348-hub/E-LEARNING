import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:provider/provider.dart';
import 'admin_layout.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final authService = Provider.of<AuthService>(context, listen: false);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isDark = theme.brightness == Brightness.dark;

    return AdminLayout(
      title: 'Manage Users',
      activeRoute: 'users',
      body: Container(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Text(
                "User Management",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "View and manage all registered users, roles, and statuses.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
            ],

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.streamCollection('users'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No users found."));
                  }

                  final usersData = snapshot.data!;
                  final users = <UserModel>[];
                  for (var data in usersData) {
                    try {
                      users.add(UserModel.fromMap(data, data['id']));
                    } catch (e) {
                      debugPrint("Skipped corrupted user: ${data['id']}");
                    }
                  }

                  if (isDesktop) {
                    return _buildDesktopTable(
                      context,
                      users,
                      authService,
                      theme,
                      isDark,
                    );
                  } else {
                    return _buildMobileList(context, users, authService, theme);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<UserModel> users,
    AuthService authService,
    ThemeData theme,
    bool isDark,
  ) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            horizontalMargin: 0,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: users.map((user) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? Text(user.name.isNotEmpty ? user.name[0] : "?")
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(_buildRoleBadge(user)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user.isBanned
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.isBanned ? 'Banned' : 'Active',
                        style: TextStyle(
                          color: user.isBanned ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.email != 'admin@admin.com') ...[
                          IconButton(
                            icon: Icon(
                              user.isBanned
                                  ? Icons.check_circle_outline
                                  : Icons.block,
                              color: user.isBanned
                                  ? Colors.green
                                  : Colors.orange,
                              size: 20,
                            ),
                            tooltip: user.isBanned ? 'Unban' : 'Ban',
                            onPressed: () =>
                                _toggleBan(context, authService, user),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Change Role',
                            onSelected: (String role) =>
                                _changeRole(context, authService, user, role),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'student',
                                child: Text('Student'),
                              ),
                              const PopupMenuItem(
                                value: 'teacher',
                                child: Text('Teacher'),
                              ),
                              const PopupMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            tooltip: 'Delete',
                            onPressed: () =>
                                _confirmDelete(context, authService, user),
                          ),
                        ] else
                          const Text(
                            "Super Admin",
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<UserModel> users,
    AuthService authService,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundImage: user.photoUrl.isNotEmpty
                  ? NetworkImage(user.photoUrl)
                  : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    )
                  : null,
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildRoleBadge(user),
                    const SizedBox(width: 8),
                    if (user.isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'BANNED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'ban') {
                  _toggleBan(context, authService, user);
                }
                if (value == 'delete') {
                  _confirmDelete(context, authService, user);
                }
                if (['student', 'teacher', 'admin'].contains(value)) {
                  _changeRole(context, authService, user, value);
                }
              },
              itemBuilder: (context) {
                if (user.email == 'admin@admin.com') return [];
                return [
                  PopupMenuItem(
                    value: 'ban',
                    child: Row(
                      children: [
                        Icon(
                          user.isBanned ? Icons.check : Icons.block,
                          size: 18,
                          color: user.isBanned ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(user.isBanned ? 'Unban User' : 'Ban User'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'student',
                    child: Text('Make Student'),
                  ),
                  const PopupMenuItem(
                    value: 'teacher',
                    child: Text('Make Teacher'),
                  ),
                  const PopupMenuItem(
                    value: 'admin',
                    child: Text('Make Admin'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete User',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ];
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(UserModel user) {
    Color color;
    String label;
    switch (user.role) {
      case 'admin':
        color = Colors.red;
        label = 'Admin';
        break;
      case 'teacher':
        color = Colors.orange;
        label = 'Teacher';
        break;
      case 'student':
        color = Colors.blue;
        label = 'Student';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
        if (user.requestedRole != null) {
          label += ' (${user.requestedRole})';
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _toggleBan(
    BuildContext context,
    AuthService authService,
    UserModel user,
  ) async {
    try {
      if (user.isBanned) {
        await authService.unbanUser(user.uid);
      } else {
        await authService.banUser(user.uid);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Action completed.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _changeRole(
    BuildContext context,
    AuthService authService,
    UserModel user,
    String role,
  ) async {
    try {
      if (role == 'admin') {
        await authService.promoteToAdmin(user.uid);
      } else if (role == 'teacher') {
        await authService.promoteToTeacher(user.uid);
      } else {
        await authService.demoteToStudent(user.uid);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Role updated to ${role.toUpperCase()}.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _confirmDelete(
    BuildContext context,
    AuthService authService,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Delete ${user.name}? This is permanent."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await authService.deleteUser(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User deleted.")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
