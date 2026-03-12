import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:provider/provider.dart';
import 'admin_edit_quiz_screen.dart';
import '../../widgets/global_app_bar.dart';
import '../../core/app_constants.dart';

class AdminAddCourseScreen extends StatefulWidget {
  final Course? course; // If null, adding new.
  const AdminAddCourseScreen({super.key, this.course});

  @override
  State<AdminAddCourseScreen> createState() => _AdminAddCourseScreenState();
}

class _AdminAddCourseScreenState extends State<AdminAddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;
  String? _selectedCategory;
  late TextEditingController _thumbnailController;
  late TextEditingController _videoUrlController;
  bool _isLoading = false;

  List<Lesson> _lessons = [];
  List<Question> _questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course?.title ?? '');
    _descController = TextEditingController(
      text: widget.course?.description ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.course?.category ?? '',
    );
    _selectedCategory = widget.course?.category;
    _thumbnailController = TextEditingController(
      text: widget.course?.thumbnail ?? '',
    );
    _videoUrlController = TextEditingController(
      text: widget.course?.videoUrl ?? '',
    );
    if (widget.course != null) {
      _loadSubCollections();
    }
  }

  Future<void> _loadSubCollections() async {
    final db = DatabaseService();
    try {
      final lessonsData = await db.query(
        'courses/${widget.course!.id}/lessons',
      );
      final questionsData = await db.query(
        'courses/${widget.course!.id}/questions',
      );

      if (mounted) {
        setState(() {
          _lessons = lessonsData.map((e) => Lesson.fromMap(e)).toList();
          _questions = questionsData.map((e) => Question.fromMap(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading sub-collections for admin: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _thumbnailController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  void _saveCourse() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final db = DatabaseService();
      final user = authService.userModel;

      final courseId =
          widget.course?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final courseData = {
        'title': _titleController.text,
        'description': _descController.text,
        'category': _categoryController.text,
        'thumbnail': _thumbnailController.text,
        'video_url': _videoUrlController.text, // Fix field name to match model
        'chapters': _lessons.isEmpty
            ? (widget.course?.chapters.map((e) => e.toMap()).toList() ?? [])
            : [
                Chapter(
                  id: 'chapter_0',
                  title: 'Course Content',
                  order: 0,
                  lectures: _lessons
                      .asMap()
                      .entries
                      .map(
                        (e) => Lecture(
                          id: 'lec_${e.key}',
                          title: e.value.title,
                          videoUrl: e.value.videoUrl,
                          duration: e.value.duration,
                          order: e.key,
                        ),
                      )
                      .toList(),
                ).toMap(),
              ],
        'questions': _questions.map((e) => e.toMap()).toList(),
        'has_questions': _questions.isNotEmpty,
        'author_id': widget.course?.authorId.isNotEmpty == true
            ? widget.course!.authorId
            : (user?.uid ?? ''),
        'author_name': widget.course?.authorName.isNotEmpty == true
            ? widget.course!.authorName
            : (user?.name ?? 'Admin'),
        'level': widget.course?.level ?? 'Beginner',
      };

      setState(() => _isLoading = true);
      try {
        if (widget.course == null) {
          await db.insert('courses', courseData, docId: courseId);
        } else {
          await db.update('courses', courseData, docId: courseId);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Course Saved!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Operation Failed: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _deleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.course != null) {
      final db = DatabaseService();
      setState(() => _isLoading = true);
      try {
        await db.delete('courses', docId: widget.course!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted Successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete Failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _editLesson(int index) {
    final lesson = _lessons[index];
    final titleController = TextEditingController(text: lesson.title);
    final urlController = TextEditingController(text: lesson.videoUrl);
    final durationController = TextEditingController(text: lesson.duration);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Lesson'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Video URL'),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _lessons[index] = Lesson(
                      title: titleController.text,
                      videoUrl: urlController.text,
                      duration: durationController.text,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _addLesson() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final durationController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Lesson'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Video URL'),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _lessons.add(
                      Lesson(
                        title: titleController.text,
                        videoUrl: urlController.text,
                        duration: durationController.text,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: widget.course == null ? 'Add Course' : 'Edit Course',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                initialValue: AppCategories.mainCategories
                        .any((c) => c['name'] == _selectedCategory)
                    ? _selectedCategory
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppCategories.mainCategories
                    .map((c) => DropdownMenuItem<String>(
                          value: c['name'] as String,
                          child: Text(c['name'] as String),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                    _categoryController.text = val ?? '';
                  });
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Please select a category' : null,
              ),
              TextFormField(
                controller: _thumbnailController,
                decoration: const InputDecoration(labelText: 'Thumbnail URL'),
              ),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(labelText: 'Intro Video URL'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lessons',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addLesson,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final item = _lessons.removeAt(oldIndex);
                    _lessons.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < _lessons.length; i++)
                    Card(
                      key: ValueKey(_lessons[i]),
                      child: ListTile(
                        leading: const Icon(Icons.play_arrow),
                        title: Text(_lessons[i].title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _lessons.removeAt(i)),
                        ),
                        onTap: () => _editLesson(i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.quiz),
                label: const Text("Manage Quiz Questions"),
                onPressed: () async {
                  final result = await Navigator.push<List<Question>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminEditQuizScreen(initialQuestions: _questions),
                    ),
                  );
                  if (result != null) {
                    setState(() => _questions = result);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCourse,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.course == null
                            ? 'Create Course'
                            : 'Update Course',
                      ),
              ),
              if (widget.course != null) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _isLoading ? null : _deleteCourse,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Delete Course Permanently'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
