// ──────────────────────────────────────────────────────────
// notes_screen.dart — Study Notes Browser
// ──────────────────────────────────────────────────────────
// Features: Premium Grid Layout, Category Filtering, PDF Actions
// ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/note_service.dart';
import '../core/app_theme.dart';
import '../widgets/global_app_bar.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NoteService _noteService = NoteService();
  String _searchQuery = "";
  String _selectedCategory = "All";
  late Stream<List<Note>> _notesStream;

  @override
  void initState() {
    super.initState();
    _notesStream = _noteService.getNotesStream();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: const GlobalAppBar(title: "Study Notes", transparent: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search notes...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ─── Content ───
              Expanded(
                child: StreamBuilder<List<Note>>(
                  stream: _notesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allNotes = snapshot.data ?? [];
                    if (allNotes.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    // Filter
                    final filteredNotes = allNotes.where((note) {
                      final matchesSearch =
                          note.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          note.content.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          );
                      final matchesCategory =
                          _selectedCategory == "All" ||
                          note.category == _selectedCategory;
                      return matchesSearch && matchesCategory;
                    }).toList();

                    // Extract Categories
                    final categories = [
                      "All",
                      ...allNotes.map((n) => n.category).toSet().toList()
                        ..sort(),
                    ];

                    return Column(
                      children: [
                        // Category Chips
                        if (categories.length > 1)
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final isSelected = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    onSelected: (v) =>
                                        setState(() => _selectedCategory = cat),
                                    selectedColor: theme.primaryColor
                                        .withValues(alpha: 0.2),
                                    checkmarkColor: theme.primaryColor,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.black87),
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white10
                                        : Colors.grey[200],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    side: BorderSide.none,
                                  ),
                                );
                              },
                            ),
                          ),

                        // Grid
                        Expanded(
                          child: filteredNotes.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No notes found matching your criteria.",
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        mainAxisExtent:
                                            220, // Fixed height cards
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: filteredNotes.length,
                                  itemBuilder: (context, index) {
                                    return _buildNoteCard(
                                      filteredNotes[index],
                                      theme,
                                      isDark,
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No notes available yet.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note.category.isEmpty ? "General" : note.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              Text(
                DateFormat.MMMd().format(note.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (note.pdfUrl != null && note.pdfUrl!.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(note.pdfUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text("View"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      minimumSize: const Size(0, 36),
                      side: BorderSide(
                        color: theme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _downloadFile(
                      context,
                      note.pdfUrl!,
                      note.fileName ?? "note.pdf",
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$fileName";
      final dio = Dio();
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await dio.download(url, savePath);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloaded to $savePath"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Close",
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
