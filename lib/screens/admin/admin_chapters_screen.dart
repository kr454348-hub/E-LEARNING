// ──────────────────────────────────────────────────────────
// AdminChaptersScreen — Manage chapters within a course
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../widgets/global_app_bar.dart';
import '../../models/course.dart';
import '../../services/course_content_service.dart';
import 'admin_lectures_screen.dart';

class AdminChaptersScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  const AdminChaptersScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<AdminChaptersScreen> createState() => _AdminChaptersScreenState();
}

class _AdminChaptersScreenState extends State<AdminChaptersScreen> {
  final CourseContentService _service = CourseContentService();
  bool _isLoading = true;
  Course? _course;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    final course = await _service.getCourse(widget.courseId);
    if (mounted) {
      setState(() {
        _course = course;
        _isLoading = false;
      });
    }
  }

  void _showAddChapterDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Chapter'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Chapter Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await _service.addChapter(
                widget.courseId,
                Chapter(title: titleController.text.trim()),
              );
              _loadCourse();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditChapterDialog(Chapter chapter) {
    final titleController = TextEditingController(text: chapter.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chapter'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Chapter Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await _service.updateChapter(widget.courseId, chapter.id, {
                'title': titleController.text.trim(),
              });
              _loadCourse();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Delete "${chapter.title}" and all its lectures?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteChapter(widget.courseId, chapter.id);
      _loadCourse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: GlobalAppBar(title: widget.courseTitle, centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showAddChapterDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Chapter'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _course == null
          ? const Center(child: Text('Course not found'))
          : _course!.chapters.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chapters yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap + to add the first chapter'),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _course!.chapters.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final chapter = _course!.chapters.removeAt(oldIndex);
                  _course!.chapters.insert(newIndex, chapter);
                });
                await _service.reorderChapters(
                  widget.courseId,
                  oldIndex,
                  newIndex + (oldIndex < newIndex ? 0 : 0), // Adjust if needed
                );
                _loadCourse();
              },
              itemBuilder: (context, index) {
                final chapter = _course!.chapters[index];
                return Card(
                  key: ValueKey(chapter.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      chapter.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${chapter.lectures.length} lecture(s)',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditChapterDialog(chapter),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteChapter(chapter),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminLecturesScreen(
                            courseId: widget.courseId,
                            chapterId: chapter.id,
                            chapterTitle: chapter.title,
                          ),
                        ),
                      ).then((_) => _loadCourse());
                    },
                  ),
                );
              },
            ),
    );
  }
}
