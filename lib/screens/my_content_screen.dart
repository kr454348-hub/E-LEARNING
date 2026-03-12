import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import 'dart:io';
import '../services/database_service.dart';
import 'admin/admin_add_course_screen.dart';
import '../widgets/global_app_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MyContentScreen extends StatefulWidget {
  const MyContentScreen({super.key});

  @override
  State<MyContentScreen> createState() => _MyContentScreenState();
}

class _MyContentScreenState extends State<MyContentScreen>
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
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: GlobalAppBar(
        title: "My Contributions",
        leading: Navigator.canPop(context)
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
              ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "My Courses", icon: Icon(Icons.video_library)),
            Tab(text: "My Notes", icon: Icon(Icons.note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _buildMyCoursesList(user.uid),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _buildMyNotesList(user.uid),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminAddCourseScreen()),
            );
          } else {
            _showAddNoteDialog(context, user.uid, user.name);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMyCoursesList(String userId) {
    final db = DatabaseService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.periodic(const Duration(seconds: 2)).asyncMap(
        (_) => db.query('courses', where: 'authorId = ?', whereArgs: [userId]),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            "No courses created yet.",
            Icons.video_library_outlined,
          );
        }

        final courses = snapshot.data!
            .map((data) => Course.fromMap(data, data['id']))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminAddCourseScreen(course: course),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: course.thumbnail.isNotEmpty
                            ? Image.network(
                                course.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.school,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  course.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  course.category,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
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
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminAddCourseScreen(course: course),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text("Edit"),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(60, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
          },
        );
      },
    );
  }

  Widget _buildMyNotesList(String userId) {
    final db = DatabaseService();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.periodic(const Duration(seconds: 2)).asyncMap(
        (_) => db.query(
          'notes',
          where: 'author_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No notes created yet.", Icons.note_outlined);
        }

        final notes = snapshot.data!
            .map((data) => Note.fromMap(data, data['id']))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(note.category),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat.yMMMd().format(note.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                note.category,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (note.pdfUrl != null && note.pdfUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: () async {
                                    final String pdfPath = note.pdfUrl!;
                                    if (pdfPath.startsWith('http')) {
                                      final uri = Uri.parse(pdfPath);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    } else if (!kIsWeb) {
                                      // Local file
                                      final file = File(pdfPath);
                                      if (await file.exists()) {
                                        // Use url_launcher to open local file if possible,
                                        // or simple success msg for now as placeholder
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Opening local file: ${note.fileName}",
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 200,
                                        ),
                                        child: Text(
                                          note.fileName ?? "View PDF",
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showAddNoteDialog(
                                    context,
                                    userId,
                                    note.authorName,
                                    note: note,
                                  ),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Delete Note?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text(
                                              "Delete",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await db.delete(
                                        'notes',
                                        where: 'id = ?',
                                        whereArgs: [note.id],
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Note deleted locally",
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
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
            );
          },
        );
      },
    );
  }

  void _showAddNoteDialog(
    BuildContext context,
    String userId,
    String userName, {
    Note? note,
  }) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final categoryController = TextEditingController(
      text: note?.category ?? '',
    );
    String? selectedFileName = note?.fileName;
    String? selectedPdfPath = note?.pdfUrl;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(note == null ? 'Add Note' : 'Edit Note'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Attachment (PDF)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (selectedFileName != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            selectedFileName = null;
                            selectedPdfPath = null;
                          }),
                        ),
                      ],
                    ),
                  if (selectedFileName == null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                        );
                        if (result != null &&
                            result.files.single.path != null) {
                          setState(() {
                            selectedPdfPath = result.files.single.path;
                            selectedFileName = result.files.single.name;
                          });
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text("Select PDF File"),
                    ),
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (titleController.text.isNotEmpty &&
                            contentController.text.isNotEmpty) {
                          setState(() => isProcessing = true);

                          String? finalPdfPath = selectedPdfPath;

                          // If it's a new file (not starting with app docs dir), copy it
                          if (!kIsWeb &&
                              selectedPdfPath != null &&
                              !selectedPdfPath!.contains('app_flutter')) {
                            try {
                              final directory =
                                  await getApplicationDocumentsDirectory();
                              final String newPath = p.join(
                                directory.path,
                                selectedFileName!,
                              );
                              await File(selectedPdfPath!).copy(newPath);
                              finalPdfPath = newPath;
                            } catch (e) {
                              debugPrint("Error copying file: $e");
                            }
                          }

                          final noteData = {
                            'title': titleController.text,
                            'content': contentController.text,
                            'category': categoryController.text.isEmpty
                                ? 'General'
                                : categoryController.text,
                            'author_id': userId,
                            'author_name': userName,
                            'pdf_url': finalPdfPath,
                            'file_name': selectedFileName,
                          };

                          try {
                            final db = DatabaseService();
                            if (note == null) {
                              noteData['id'] = DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();
                              await db.insert('notes', noteData);
                            } else {
                              await db.update(
                                'notes',
                                noteData,
                                where: 'id = ?',
                                whereArgs: [note.id],
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            debugPrint("Error saving note: $e");
                            setState(() => isProcessing = false);
                          }
                        }
                      },
                child: Text(note == null ? 'Add' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'python':
        return const Color(0xFFFFD43B);
      case 'java':
        return const Color(0xFF007396);
      case 'dart':
        return const Color(0xFF0175C2);
      case 'c':
        return const Color(0xFF555555);
      case 'ai & ml':
        return const Color(0xFF673AB7);
      case 'data science':
        return const Color(0xFF3F51B5);
      default:
        return Colors.blueGrey;
    }
  }
}
