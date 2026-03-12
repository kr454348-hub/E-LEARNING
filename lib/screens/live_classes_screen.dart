 // ──────────────────────────────────────────────────────────
// live_classes_screen.dart — Live Classes Management
// ──────────────────────────────────────────────────────────
// Shows upcoming live classes for students and teachers.
// Features:
// - Real-time updates via Firestore stream
// - Local caching for offline/instant load
// - Teachers/Admins can schedule and delete classes
// - Students can join via meeting URL
// ──────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/global_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/live_class.dart';
import '../services/live_class_service.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'admin/schedule_class_screen.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  final LiveClassService _liveClassService = LiveClassService();
  final CacheService _cacheService = CacheService();

  List<LiveClass>? _liveClasses;
  List<LiveClass>? _cachedClasses;
  StreamSubscription? _classSubscription;

  bool _isLoading = true;
  bool _showTimeoutError = false;
  String? _errorMessage;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadCache();
    _initStream();
    _liveClassService.cleanupPastClasses(); // Kick off background cleanup
  }

  void _initStream() {
    setState(() {
      _isLoading = _cachedClasses == null;
      _errorMessage = null;
      _showTimeoutError = false;
    });

    _classSubscription?.cancel();
    _startTimeoutTimer();

    _classSubscription = _liveClassService.getUpcomingClasses().listen(
      (data) {
        if (!mounted) return;

        // Manual In-Memory Sorting by schedule date
        data.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        setState(() {
          _liveClasses = data;
          _isLoading = false;
          _showTimeoutError = false;
          _timeoutTimer?.cancel();
        });

        // Safe Side-Effect: update cache
        _cacheService.cacheLiveClasses(data.map((c) => c.toMap()).toList());
      },
      onError: (err) {
        debugPrint("🔴 [LiveClasses] Stream Error: $err");
        if (!mounted) return;
        setState(() {
          _errorMessage = err.toString();
          _isLoading = false;
        });
      },
    );
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _liveClasses == null && _cachedClasses == null) {
        setState(() => _showTimeoutError = true);
      }
    });
  }

  @override
  void dispose() {
    _classSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    _initStream();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _loadCache() async {
    try {
      final cachedData = await _cacheService.getCachedLiveClasses();
      if (cachedData != null && mounted) {
        final List<LiveClass> decoded = cachedData
            .map((d) => LiveClass.fromMap(d, d['id']))
            .toList();

        // Sort cached data too
        decoded.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        setState(() {
          _cachedClasses = decoded;
          // If we have cache, we stop the immediate loading spinner
          if (_liveClasses == null) _isLoading = false;
          _timeoutTimer?.cancel();
        });
      }
    } catch (e) {
      debugPrint("⚠️ [LiveClasses] cache load error: $e");
    }
  }

  Future<void> _joinClass(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which list to display (live data preferred over cache)
    final displayList = _liveClasses ?? _cachedClasses;

    final authService = Provider.of<AuthService>(context);
    final userModel = authService.userModel;
    final isTeacherOrAdmin =
        userModel != null &&
        (userModel.role == 'admin' || userModel.role == 'teacher');

    return Scaffold(
      appBar: const GlobalAppBar(title: "Live Classes"),
      floatingActionButton: isTeacherOrAdmin
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleClassScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(displayList, isTeacherOrAdmin),
      ),
    );
  }

  Widget _buildBody(List<LiveClass>? classes, bool isTeacherOrAdmin) {
    // 1. Error state
    if (_errorMessage != null && classes == null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Error: $_errorMessage",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          Center(
            child: ElevatedButton(
              onPressed: _refresh,
              child: const Text("Retry"),
            ),
          ),
        ],
      );
    }

    // 2. Loading state (no data and no error yet)
    if (_isLoading && classes == null) {
      if (_showTimeoutError) {
        return _buildTimeoutView();
      }
      return const Center(child: CircularProgressIndicator());
    }

    // 3. Empty state
    if (classes == null || classes.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  "No upcoming live classes.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextButton(onPressed: _refresh, child: const Text("Refresh")),
              ],
            ),
          ),
        ],
      );
    }

    // 4. Data List
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final liveClass = classes[index];
        return _buildClassCard(liveClass, isTeacherOrAdmin);
      },
    );
  }

  Widget _buildTimeoutView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          "Connection is slower than usual.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry Connection"),
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(LiveClass liveClass, bool isAdmin) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    liveClass.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(liveClass),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  liveClass.instructorName,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(liveClass.description),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Scheduled For:",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(liveClass.scheduledAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _joinClass(context, liveClass.meetingUrl),
                  icon: const Icon(Icons.video_call),
                  label: const Text("Join Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(LiveClass liveClass) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Class?"),
        content: const Text("Are you sure you want to cancel this class?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Cancel Class",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _liveClassService.deleteClass(liveClass.id);
    }
  }
}
