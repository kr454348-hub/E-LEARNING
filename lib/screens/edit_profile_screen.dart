import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _photoUrlController = TextEditingController();

  XFile? _pickedFile;
  bool _isLoading = false;

  final List<String> _avatarPresets = AuthService.defaultAvatars;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).userModel;
    if (user != null) {
      _nameController.text = user.name;
      _photoUrlController.text = user.photoUrl;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _pickedFile = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_pickedFile == null) return null;
    try {
      final storage = StorageService();
      final String fileName =
          'profile_$userId${p.extension(_pickedFile!.path)}';

      if (kIsWeb) {
        final bytes = await _pickedFile!.readAsBytes();
        return await storage.uploadData(
          path: 'users',
          fileName: fileName,
          data: bytes,
          contentType:
              'image/${p.extension(_pickedFile!.path).replaceFirst('.', '')}',
        );
      } else {
        return await storage.uploadFile(
          path: 'users',
          fileName: fileName,
          file: File(_pickedFile!.path),
        );
      }
    } catch (e) {
      throw Exception("Cloud upload failed: $e");
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userModel;

    try {
      String finalPhotoUrl = _photoUrlController.text.trim();

      if (_pickedFile != null && user != null) {
        final uploadedUrl = await _uploadImage(user.uid);
        if (uploadedUrl != null) {
          finalPhotoUrl = uploadedUrl;
        }
      }

      await authService.updateProfile(
        name: _nameController.text.trim(),
        photoUrl: finalPhotoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ImageProvider? backgroundImage;

    if (_pickedFile != null) {
      if (kIsWeb) {
        backgroundImage = NetworkImage(_pickedFile!.path);
      } else {
        backgroundImage = FileImage(File(_pickedFile!.path));
      }
    } else if (_photoUrlController.text.isNotEmpty) {
      if (_photoUrlController.text.startsWith('http') || kIsWeb) {
        backgroundImage = NetworkImage(_photoUrlController.text);
      } else {
        backgroundImage = FileImage(File(_photoUrlController.text));
      }
    }

    final isDark = theme.brightness == Brightness.dark;

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: const GlobalAppBar(title: "Edit Profile", transparent: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primaryColor, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      backgroundImage: backgroundImage,
                      child: backgroundImage == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Pick from Gallery"),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Or Choose an Avatar",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarPresets.length,
                separatorBuilder: (ctx, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final url = _avatarPresets[index];
                  final isSelected =
                      _pickedFile == null && _photoUrlController.text == url;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _photoUrlController.text = url;
                        _pickedFile = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(35),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: NetworkImage(url),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                  shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
