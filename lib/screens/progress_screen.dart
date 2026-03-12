import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/global_app_bar.dart';
import '../core/app_theme.dart';

class ProgressScreen extends StatelessWidget {
  final String?
  userId; // Optional: If provided, viewing another user's progress (Admin mode)

  const ProgressScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).userModel;
    final targetUid = userId ?? currentUser?.uid;
    final db = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (targetUid == null) {
      return const SizedBox.shrink();
    }

    return AppTheme.backgroundScaffold(
      isDark: isDark,
      appBar: GlobalAppBar(
        title: userId != null ? "User Progress" : "My Progress",
        transparent: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 5)).asyncMap(
          (_) => db.query(
            'user_progress',
            where: 'user_id = ?',
            whereArgs: [targetUid],
          ),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dataList = snapshot.data ?? [];

          // Calculate Overall Progress
          double totalProgressSum = 0.0;
          int startedCoursesCount = 0;

          for (var data in dataList) {
            final lastIndex =
                (data['last_lesson_index'] ?? data['lastLessonIndex'] as num?)
                    ?.toInt() ??
                -1;
            final total =
                (data['total_lessons'] ?? data['totalLessons'] as num?)
                    ?.toInt() ??
                1;

            if (total > 0 && lastIndex > -1) {
              double p = (lastIndex + 1) / total;
              totalProgressSum += p.clamp(0.0, 1.0);
              startedCoursesCount++;
            }
          }

          double overallProgress = startedCoursesCount > 0
              ? (totalProgressSum / startedCoursesCount)
              : 0.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade700,
                            Colors.purple.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircularProgressIndicator(
                            value: overallProgress,
                            strokeWidth: 8,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Overall Progress",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${(overallProgress * 100).toInt()}%",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                startedCoursesCount > 0
                                    ? "Across $startedCoursesCount courses"
                                    : "Start a course!",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "Weekly Activity",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Weekly Activity Chart
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Stream.periodic(const Duration(seconds: 10))
                          .asyncMap(
                            (_) => db.query(
                              'activity_log',
                              where: 'user_id = ?',
                              whereArgs: [targetUid],
                            ),
                          ),
                      builder: (context, activitySnapshot) {
                        if (activitySnapshot.hasError) {
                          return Text(
                            "Error loading chart: ${activitySnapshot.error}",
                          );
                        }

                        final rawLogs = activitySnapshot.data ?? [];
                        final sevenDaysAgo = DateTime.now().subtract(
                          const Duration(days: 7),
                        );

                        final activityLogs = rawLogs.where((log) {
                          final ts = DateTime.parse(
                            log['timestamp'] ?? log['created_at'],
                          );
                          return ts.isAfter(sevenDaysAgo);
                        }).toList();

                        Map<int, double> weeklyUsage = {
                          0: 0,
                          1: 0,
                          2: 0,
                          3: 0,
                          4: 0,
                          5: 0,
                          6: 0,
                        };

                        for (var log in activityLogs) {
                          final ts = DateTime.parse(
                            log['timestamp'] ?? log['created_at'],
                          );
                          int dayIndex = ts.weekday - 1;
                          if (dayIndex >= 0 && dayIndex <= 6) {
                            weeklyUsage[dayIndex] =
                                (weeklyUsage[dayIndex] ?? 0) + 1;
                          }
                        }

                        double maxY = 5;
                        for (var v in weeklyUsage.values) {
                          if (v > maxY) maxY = v;
                        }

                        return SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxY * 1.2,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget:
                                        (double value, TitleMeta meta) {
                                          const style = TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          );
                                          String text = [
                                            'M',
                                            'T',
                                            'W',
                                            'T',
                                            'F',
                                            'S',
                                            'S',
                                          ][value.toInt() % 7];
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(text, style: style),
                                          );
                                        },
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(
                                7,
                                (i) => _makeBarGroup(
                                  i,
                                  weeklyUsage[i]!,
                                  i >= 3 ? Colors.purpleAccent : Colors.purple,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "Ongoing Courses",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (dataList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            "No courses started yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: dataList.map((data) {
                          final title =
                              data['course_title'] ??
                              data['courseTitle'] ??
                              'Unknown Course';
                          final lastIndex =
                              (data['last_lesson_index'] ??
                                      data['lastLessonIndex'] as num?)
                                  ?.toInt() ??
                              -1;
                          final total =
                              (data['total_lessons'] ??
                                      data['totalLessons'] as num?)
                                  ?.toInt() ??
                              1;
                          double progress = total > 0
                              ? (lastIndex + 1) / total
                              : 0.0;
                          return _buildCourseProgressItem(
                            title,
                            progress.clamp(0.0, 1.0),
                            Colors.blueAccent,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildCourseProgressItem(String title, double progress, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
