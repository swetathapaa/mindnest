import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() => runApp(const MaterialApp(home: MoodGraphScreen()));

class MoodData {
  final String day;
  final int value;
  final String mood;
  const MoodData(this.day, this.value, this.mood);
}

class MoodGraphScreen extends StatefulWidget {
  const MoodGraphScreen({super.key});

  @override
  State<MoodGraphScreen> createState() => _MoodGraphPageState();
}

class _MoodGraphPageState extends State<MoodGraphScreen> {
  static const moodDataList = [
    MoodData("MON", 3, "Calm"),
    MoodData("TUE", 5, "Happy"),
    MoodData("WED", 2, "Sad"),
    MoodData("THU", 4, "Energetic"),
    MoodData("FRI", 1, "Irritated"),
    MoodData("SAT", 3, "Calm"),
    MoodData("SUN", 4, "Happy"),
  ];

  TooltipBehavior tooltipBehavior = TooltipBehavior(enable: true);

  // Fun vector-style icons for moods
  Widget moodIcon(String mood) {
    Color bg;
    IconData icon;

    switch (mood.toLowerCase()) {
      case 'happy':
        bg = Colors.yellow.shade600;
        icon = Icons.sentiment_satisfied_alt;
        break;
      case 'sad':
        bg = Colors.blue.shade400;
        icon = Icons.sentiment_dissatisfied;
        break;
      case 'energetic':
        bg = Colors.orange.shade600;
        icon = Icons.flash_on;
        break;
      case 'calm':
        bg = Colors.teal.shade400;
        icon = Icons.spa;
        break;
      case 'irritated':
        bg = Colors.red.shade400;
        icon = Icons.sentiment_very_dissatisfied;
        break;
      default:
        bg = Colors.grey.shade400;
        icon = Icons.sentiment_neutral;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B9A8B), Color(0xFFE6C79C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Weekly Mood Tracker",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SfCartesianChart(
                        tooltipBehavior: tooltipBehavior,
                        primaryXAxis: CategoryAxis(
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D4A42),
                          ),
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          maximum: 5,
                          interval: 1,
                          labelStyle: const TextStyle(
                            color: Color(0xFF2D4A42),
                          ),
                        ),
                        series: <LineSeries<MoodData, String>>[
                          LineSeries<MoodData, String>(
                            dataSource: moodDataList,
                            xValueMapper: (MoodData data, _) => data.day,
                            yValueMapper: (MoodData data, _) => data.value,
                            color: Colors.deepPurpleAccent,
                            width: 3,
                            markerSettings:
                            const MarkerSettings(isVisible: false),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              builder: (data, point, series, pointIndex,
                                  seriesIndex) {
                                return moodIcon(
                                    moodDataList[pointIndex].mood);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    "Your moods this week have been varied — keep tracking to see patterns and improve emotional balance!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2D4A42),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
