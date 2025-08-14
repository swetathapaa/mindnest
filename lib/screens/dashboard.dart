import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'recommendation_screen.dart';
import 'user_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _journalController = TextEditingController();
  final Set<String> selectedMoods = {};
  bool _loadingUser = true;
  String _displayName = '';
  bool _isSubmitting = false;

  final Map<String, IconData> moodIconData = {
    'Calm': Icons.self_improvement,
    'Happy': Icons.sentiment_very_satisfied,
    'Energetic': Icons.flash_on,
    'Frisky': Icons.emoji_emotions,
    'Mood Swings': Icons.sync_problem,
    'Irritated': Icons.mood_bad,
    'Sad': Icons.sentiment_dissatisfied,
    'Anxious': Icons.warning_amber,
    'Depressed': Icons.cloud,
    'Feeling Guilty': Icons.sentiment_neutral,
    'Low Energy': Icons.battery_alert,
    'Apathetic': Icons.remove_circle_outline,
    'Confused': Icons.help_outline,
    'Very Self-Critical': Icons.person_off,
  };

  @override
  void initState() {
    super.initState();
    _fetchDisplayName();
  }

  Future<void> _fetchDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _displayName = 'there';
        _loadingUser = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final name =
        data != null && data['name'] != null ? data['name'] as String : null;
        if (name != null && name.isNotEmpty) {
          setState(() {
            _displayName = name;
            _loadingUser = false;
          });
          return;
        }
      }

      final email = user.email ?? '';
      setState(() {
        _displayName = email.contains('@')
            ? email.split('@')[0]
            : (email.isNotEmpty ? email : 'there');
        _loadingUser = false;
      });
    } catch (_) {
      final email = user.email ?? '';
      setState(() {
        _displayName = email.contains('@')
            ? email.split('@')[0]
            : (email.isNotEmpty ? email : 'there');
        _loadingUser = false;
      });
    }
  }

  void toggleMood(String mood) {
    setState(() {
      if (selectedMoods.contains(mood)) {
        selectedMoods.remove(mood);
      } else {
        selectedMoods.add(mood);
      }
    });
  }

  Future<void> submit() async {
    if (selectedMoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one mood')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final moodsList = selectedMoods.toList();
    final journalText = _journalController.text.trim();

    try {
      final uri = Uri.parse('http://10.0.2.2:3000/getMoodResponse'); // Change as needed
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'moods': moodsList,
          'journal': journalText,
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('AI backend error: ${resp.body}');
      }

      final data = json.decode(resp.body);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final entryRef = FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Entries')
            .doc();

        await entryRef.set({
          'Moods': moodsList,
          'Journal': journalText,
          'CreatedAt': FieldValue.serverTimestamp(),
          'Summary': data['summary'] ?? '',
          'Reflection': data['reflection'] ?? '',
          'Action': data['action'] ?? '',
          'Songs': (data['songs'] as List<dynamic>? ?? []).map((song) {
            return {
              'title': song['title'] ?? '',
              'artist': song['artist'] ?? '',
              'youtubeLink': song['youtubeLink'] ?? '',
            };
          }).toList(),
        });

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecommendationScreen(
              entryId: entryRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get recommendation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFFFEFCF8); // Light Cream
    final primaryText = const Color(0xFF2D4A42); // Dark Teal
    final secondaryText = const Color(0xFF5B9A8B); // Muted Teal
    final cardColor = const Color(0xFFF8F6F3); // Pearl White
    final accentColor = const Color(0xFFE6C79C); // Soft Gold
    final buttonColor = const Color(0xFF5B9A8B); // Muted Teal

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: buttonColor,
        elevation: 0,
        centerTitle: true,
        title: _loadingUser
            ? const Text(
          'Your space to breathe...',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
            : Text(
          'Your space to breathe, ${_displayName.split(' ').first}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserDashboardScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let’s check in—how’s your day been so far?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                // Horizontal moods scroll
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: moodIconData.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final mood = moodIconData.keys.elementAt(index);
                      final icon = moodIconData[mood]!;
                      final selected = selectedMoods.contains(mood);
                      return GestureDetector(
                        onTap: () => toggleMood(mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected ? accentColor.withOpacity(0.2) : cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? accentColor : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon,
                                  size: 32,
                                  color: selected ? accentColor : secondaryText),
                              const SizedBox(height: 6),
                              Text(
                                mood,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? accentColor : secondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Your thoughts & feelings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  height: 200,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _journalController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(color: primaryText),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write anything—no judgment, just you.',
                      hintStyle: TextStyle(color: secondaryText),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                        : const Text(
                      'Continue',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
