import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

// Helper function to show the Add/Edit Dialog
Future<void> showAddEditNoteDialog(BuildContext context, {Note? note}) async {
  final db = DatabaseService();
  final storage = StorageService();

  final outerNavigator = Navigator.of(context);
  final outerMessenger = ScaffoldMessenger.of(context);
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.userModel;

  final titleController = TextEditingController(text: note?.title ?? '');
  final contentController = TextEditingController(text: note?.content ?? '');
  final categoryController = TextEditingController(
    text: note?.category ?? 'General',
  );
  String? selectedFileName = note?.fileName;
  String? pdfUrl = note?.pdfUrl;
  bool isUploading = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (sbContext, setState) {
        return AlertDialog(
          title: Text(note == null ? 'Add Note' : 'Edit Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g. Python, Updates)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Attachment (Optional PDF)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(
                    selectedFileName ?? "No file attached",
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedFileName == null ? Colors.grey : null,
                    ),
                  ),
                  trailing: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(
                            selectedFileName == null
                                ? Icons.upload_file
                                : Icons.close,
                          ),
                          onPressed: () async {
                            if (selectedFileName != null) {
                              setState(() {
                                selectedFileName = null;
                                pdfUrl = null;
                              });
                              return;
                            }

                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                              withData: true,
                            );

                            if (result != null) {
                              setState(() => isUploading = true);
                              try {
                                final file = result.files.first;
                                final url = await storage.uploadData(
                                  path: 'notes',
                                  fileName:
                                      'note_${DateTime.now().millisecondsSinceEpoch}.pdf',
                                  data: file.bytes!,
                                  contentType: 'application/pdf',
                                );
                                setState(() {
                                  pdfUrl = url;
                                  selectedFileName = file.name;
                                });
                              } catch (e) {
                                // ignore: use_build_context_synchronously
                                if (sbContext.mounted) {
                                  ScaffoldMessenger.of(sbContext).showSnackBar(
                                    SnackBar(
                                      content: Text("Upload failed: $e"),
                                    ),
                                  );
                                }
                              } finally {
                                setState(() => isUploading = false);
                              }
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.isNotEmpty &&
                          contentController.text.isNotEmpty) {
                        final noteData = {
                          'title': titleController.text,
                          'content': contentController.text,
                          'category': categoryController.text.isEmpty
                              ? 'General'
                              : categoryController.text,
                          'author_id': note != null && note.authorId.isNotEmpty
                              ? note.authorId
                              : (user?.uid ?? ''),
                          'author_name':
                              note != null && note.authorName.isNotEmpty
                              ? note.authorName
                              : (user?.name ?? 'Admin'),
                          'pdf_url': pdfUrl,
                          'file_name': selectedFileName,
                        };

                        try {
                          if (note == null) {
                            noteData['created_at'] = DateTime.now()
                                .toIso8601String();
                            await db.insert('notes', noteData);
                          } else {
                            await db.update('notes', noteData, docId: note.id);
                          }
                          outerNavigator.pop();
                        } catch (e) {
                          outerMessenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
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

class AdminNotesScreen extends StatelessWidget {
  const AdminNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.userModel;
    final currentUserId = currentUser?.uid;
    final isAdmin = currentUser?.role == 'admin';

    // Desktop check for adaptive layout if needed, though ListView is usually fine for notes.
    // For now, allow simple list.

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.streamCollection('notes'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text('No notes available.'));
        }

        // Group notes by category
        final Map<String, List<Map<String, dynamic>>> groupedNotes = {};
        for (var item in data) {
          final category = item['category'] ?? 'General';
          if (!groupedNotes.containsKey(category)) {
            groupedNotes[category] = [];
          }
          groupedNotes[category]!.add(item);
        }

        final sortedCategories = groupedNotes.keys.toList()..sort();

        return ListView.builder(
          itemCount: sortedCategories.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final category = sortedCategories[index];
            final categoryNotes = groupedNotes[category]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              color: Colors.transparent,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  ...categoryNotes.map((item) {
                    final note = Note.fromMap(item, item['id']);
                    final canEdit = isAdmin || note.authorId == currentUserId;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          note.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${DateFormat.yMMMd().format(note.createdAt)}\n${note.content}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: canEdit
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () => showAddEditNoteDialog(
                                      context,
                                      note: note,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _deleteNote(context, db, note.id),
                                  ),
                                ],
                              )
                            : null,
                        onTap: canEdit
                            ? () => showAddEditNoteDialog(context, note: note)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteNote(BuildContext context, DatabaseService db, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Note"),
        content: const Text("Are you sure you want to delete this note?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await db.delete('notes', docId: id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Note deleted.")),
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
