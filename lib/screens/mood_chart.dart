import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MoodChartScreen extends StatefulWidget {
  const MoodChartScreen({super.key});

  @override
  State<MoodChartScreen> createState() => _MoodChartScreenState();
}

class _MoodChartScreenState extends State<MoodChartScreen> {
  late Future<List<_MoodCount>> _moodCountsFuture;
  String _username = "Friend";

  final Map<String, IconData> moodIcons = {
    "Sad": Icons.sentiment_dissatisfied,
    "Neutral": Icons.sentiment_neutral,
    "Happy": Icons.sentiment_satisfied,
    "Very Happy": Icons.sentiment_very_satisfied,
    "Energetic": Icons.flash_on,
    "Calm": Icons.self_improvement,
    "Depressed": Icons.mood_bad,
    "Apathetic": Icons.remove_circle_outline,
    "Confused": Icons.help_outline,
    "Low Energy": Icons.battery_alert,
    "Frisky": Icons.wb_sunny,
    "Irritated": Icons.warning,
    "Anxious": Icons.warning_amber,
    "Mood Swings": Icons.autorenew,
    "Feeling Guilty": Icons.sentiment_very_dissatisfied,
    "Very Self-Critical": Icons.report_problem,
  };

  @override
  void initState() {
    super.initState();
    _moodCountsFuture = fetchAllMoodCounts();
  }

  Future<List<_MoodCount>> fetchAllMoodCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    _username = user.displayName ?? user.email?.split('@').first ?? "Friend";

    final snapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Entries')
        .orderBy('CreatedAt', descending: false) // fetch all
        .get();

    if (snapshot.docs.isEmpty) return [];

    final Map<String, int> counts = {};

    for (final doc in snapshot.docs) {
      final entryMoods = List<String>.from(doc['Moods'] ?? []);
      for (final mood in entryMoods) {
        counts[mood] = (counts[mood] ?? 0) + 1;
      }
    }

    // Convert to list for chart
    final moodList = counts.entries
        .map((e) => _MoodCount(mood: e.key, count: e.value))
        .toList();

    // Sort alphabetically or leave unsorted
    moodList.sort((a, b) => a.mood.compareTo(b.mood));

    return moodList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mood Chart"),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<_MoodCount>>(
        future: _moodCountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final moods = snapshot.data ?? [];

          if (moods.isEmpty) {
            return _buildEmptyState();
          }

          final maxCount =
          moods.map((e) => e.count).reduce((a, b) => a > b ? a : b);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  "Your Mood Variations",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),

                // Mood Line Chart
                SizedBox(
                  height: 320,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelRotation: 45,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    primaryYAxis: NumericAxis(
                      minimum: 0,
                      maximum: maxCount.toDouble() + 1,
                      interval: 1,
                      labelStyle: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                      majorGridLines:
                      const MajorGridLines(width: 0.3, color: Colors.teal),
                    ),
                    series: <SplineSeries<_MoodCount, String>>[
                      SplineSeries<_MoodCount, String>(
                        dataSource: moods,
                        xValueMapper: (data, _) => data.mood,
                        yValueMapper: (data, _) => data.count.toDouble(),
                        color: Colors.teal,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: false),
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          builder: (data, point, series, pointIndex, seriesIndex) {
                            return Icon(
                              moodIcons[data.mood] ?? Icons.circle,
                              color: Colors.teal,
                              size: 24,
                            );
                          },
                        ),
                      ),
                    ],
                    plotAreaBorderWidth: 0,
                  ),
                ),

                const SizedBox(height: 20),

                // Legend
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 12,
                    children: moods.map((data) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            moodIcons[data.mood] ?? Icons.circle,
                            color: Colors.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            data.mood,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      "🌟 Keep recording your moods! This is your progress. 🎉",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hey $_username! You don’t have any entries yet.",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Logging your moods helps you track your emotional wellbeing over time. Start recording today!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/dashboard'),
              child: const Text("Add Entry"),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodCount {
  final String mood;
  final int count;
  _MoodCount({required this.mood, required this.count});
}
