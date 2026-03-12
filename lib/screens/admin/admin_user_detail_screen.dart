import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:provider/provider.dart';
import '../chat/chat_screen.dart';
import '../progress_screen.dart';
import '../../widgets/global_app_bar.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final UserModel user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late TextEditingController _nameController;
  late String _selectedRole;
  bool _isLoading = false;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    final roleLower = widget.user.role.toLowerCase();
    _selectedRole = ['student', 'admin', 'teacher'].contains(roleLower)
        ? roleLower
        : 'student';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    setState(() => _isLoading = true);
    try {
      await _db.update('users', {
        'name': _nameController.text.trim(),
        'role': _selectedRole,
      }, docId: widget.user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User Profile Updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update Failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
          'This will delete all course progress for this user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteWhere('user_progress', 'user_id', widget.user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User Progress Reset Successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Reset Failed: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _messageUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.userModel;
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final chatService = ChatService();
      final roomId = await chatService.createPrivateChat(
        userId: currentUser.uid,
        userName: currentUser.name,
        userRole: currentUser.role,
        otherUserId: widget.user.uid,
        otherUserName: widget.user.name,
        otherUserRole: widget.user.role,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: roomId,
              otherUserName: widget.user.name,
              otherUserRole: widget.user.role,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(title: 'Edit: ${widget.user.name}'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: widget.user.photoUrl.isNotEmpty
                          ? NetworkImage(widget.user.photoUrl)
                          : null,
                      child: widget.user.photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "User Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _messageUser,
                    icon: const Icon(Icons.message),
                    label: const Text("Message User"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    items: ['student', 'admin', 'teacher']
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                    decoration: const InputDecoration(
                      labelText: 'System Role',
                      prefixIcon: Icon(Icons.security),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _updateUser,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Save Changes"),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProgressScreen(userId: widget.user.uid),
                      ),
                    ),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text("View Detailed User Progress"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    "Danger Zone",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const Divider(color: Colors.red),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _resetProgress,
                    icon: const Icon(Icons.history),
                    label: const Text("Reset All Course Progress"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Warning: Resetting progress cannot be undone. The user will have to start all courses from the beginning.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
