import 'package:flutter/material.dart';

class AppCategories {
  static const List<Map<String, dynamic>> mainCategories = [
    {"name": "Coding", "icon": Icons.code, "color": Colors.blue},
    {"name": "Medical", "icon": Icons.medical_services, "color": Colors.red},
    {"name": "Engineering", "icon": Icons.engineering, "color": Colors.blueGrey},
    {"name": "Competitive Exams", "icon": Icons.assignment, "color": Colors.deepOrange},
    {"name": "Applied Sciences", "icon": Icons.science, "color": Colors.cyan},
    {"name": "Data Science", "icon": Icons.analytics, "color": Colors.indigo},
    {"name": "Cloud Computing", "icon": Icons.cloud, "color": Colors.lightBlue},
    {"name": "Cyber Security", "icon": Icons.security, "color": Colors.red},
    {"name": "AI & ML", "icon": Icons.smart_toy, "color": Colors.deepPurple},
    {
      "name": "Blockchain",
      "icon": Icons.currency_bitcoin,
      "color": Colors.orange,
    },
    {"name": "DevOps", "icon": Icons.adb, "color": Colors.green},
    {"name": "Design", "icon": Icons.brush, "color": Colors.pink},
    {"name": "Business", "icon": Icons.work, "color": Colors.teal},
    {"name": "Marketing", "icon": Icons.trending_up, "color": Colors.purple},
  ];

  static const List<Map<String, dynamic>> codingLanguages = [
    {"name": "Dart", "icon": Icons.flutter_dash, "color": Color(0xFF0175C2)},
    {"name": "Python", "icon": Icons.pest_control, "color": Color(0xFFFFD43B)},
    {
      "name": "JavaScript",
      "icon": Icons.javascript,
      "color": Color(0xFFF7DF1E),
    },
    {"name": "Java", "icon": Icons.coffee, "color": Color(0xFF007396)},
    {"name": "Kotlin", "icon": Icons.android, "color": Color(0xFF7F52FF)},
    {"name": "Swift", "icon": Icons.bolt, "color": Color(0xFFFA7343)},
    {
      "name": "C++",
      "icon": Icons.integration_instructions,
      "color": Color(0xFF00599C),
    },
    {"name": "C", "icon": Icons.code, "color": Color(0xFF555555)},
    {"name": "PHP", "icon": Icons.php, "color": Color(0xFF777BB4)},
    {"name": "SQL", "icon": Icons.table_chart, "color": Color(0xFF4479A1)},
  ];
}
