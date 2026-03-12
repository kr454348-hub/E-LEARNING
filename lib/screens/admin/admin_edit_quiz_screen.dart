import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../widgets/global_app_bar.dart';

class AdminEditQuizScreen extends StatefulWidget {
  final List<Question> initialQuestions;
  const AdminEditQuizScreen({super.key, required this.initialQuestions});

  @override
  State<AdminEditQuizScreen> createState() => _AdminEditQuizScreenState();
}

class _AdminEditQuizScreenState extends State<AdminEditQuizScreen> {
  late List<Question> _questions;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.initialQuestions);
  }

  void _addQuestion() {
    showDialog<Question>(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        final op1Controller = TextEditingController();
        final op2Controller = TextEditingController();
        final op3Controller = TextEditingController();
        final op4Controller = TextEditingController();
        int correctIndex = 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add Question"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: "Question Text",
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Options:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: op1Controller,
                      decoration: const InputDecoration(labelText: "Option 1"),
                    ),
                    TextField(
                      controller: op2Controller,
                      decoration: const InputDecoration(labelText: "Option 2"),
                    ),
                    TextField(
                      controller: op3Controller,
                      decoration: const InputDecoration(labelText: "Option 3"),
                    ),
                    TextField(
                      controller: op4Controller,
                      decoration: const InputDecoration(labelText: "Option 4"),
                    ),
                    const SizedBox(height: 10),
                    const Text("Correct Option (0-3):"),
                    Slider(
                      value: correctIndex.toDouble(),
                      min: 0,
                      max: 3,
                      divisions: 3,
                      label: "Option ${correctIndex + 1}",
                      onChanged: (v) =>
                          setState(() => correctIndex = v.toInt()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    if (textController.text.isNotEmpty &&
                        op1Controller.text.isNotEmpty) {
                      Navigator.pop(
                        context,
                        Question(
                          text: textController.text,
                          options: [
                            op1Controller.text,
                            op2Controller.text,
                            op3Controller.text,
                            op4Controller.text,
                          ],
                          correctIndex: correctIndex,
                        ),
                      );
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null) {
        setState(() {
          _questions.add(result);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: "Manage Quiz",
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _questions),
            tooltip: "Save Quiz",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _addQuestion,
        child: const Icon(Icons.add),
      ),
      body: _questions.isEmpty
          ? const Center(child: Text("No questions. Add one!"))
          : ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _questions.removeAt(oldIndex);
                  _questions.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _questions.length; i++)
                  ListTile(
                    key: ValueKey(_questions[i]),
                    title: Text(_questions[i].text),
                    subtitle: Text(
                      "Answer: Option ${_questions[i].correctIndex + 1}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _questions.removeAt(i);
                        });
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
