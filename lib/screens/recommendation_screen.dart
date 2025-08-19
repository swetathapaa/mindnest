import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'user_dashboard.dart';

class RecommendationScreen extends StatefulWidget {
  final String entryId;
  const RecommendationScreen({Key? key, required this.entryId}) : super(key: key);

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _entryFuture;
  String userName = 'Friend';
  Timer? _timer;
  Duration? _timeLeft;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userName = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Friend';
      _entryFuture = FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('Entries')
          .doc(widget.entryId)
          .get();
      _startTimerForNextEntry();
    } else {
      _entryFuture = Future.value(null);
    }
  }

  void _startTimerForNextEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Entries')
        .orderBy('CreatedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final lastEntry = query.docs.first;
    final lastTime = (lastEntry['CreatedAt'] as Timestamp?)?.toDate();
    if (lastTime == null) return;

    final now = DateTime.now();
    final diff = lastTime.add(const Duration(minutes: 15)).difference(now);

    setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft != null) {
        setState(() {
          if (_timeLeft!.inSeconds > 0) {
            _timeLeft = _timeLeft! - const Duration(seconds: 1);
          } else {
            _timer?.cancel();
            _timeLeft = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFCF8),
      appBar: AppBar(
        title: const Text('Your Recommendations'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, size: 28),
            tooltip: 'User Dashboard',
            onPressed: () {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserDashboardScreen()));
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _entryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Oops, I couldn’t find your recommendation right now. Try again later.',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          final data = snapshot.data!.data()!;
          final String summary = data['Summary'] ?? '';
          final String reflection = data['Reflection'] ?? '';
          final String action = data['Action'] ?? '';
          final List<dynamic> songs = data['Songs'] ?? [];

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Healing Space',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D4A42),
                      ),
                    ),
                    if (_timeLeft != null)
                      Flexible(
                        child: _timeLeft!.inSeconds > 0
                            ? Text(
                          'Next entry in: ${_timeLeft!.inMinutes}:${(_timeLeft!.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        )
                            : GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/dashboard');
                          },
                          child: Text(
                            'Add New Entry!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                              fontSize: 14,

                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildCard(summary, "Mood Summary", Icons.sentiment_satisfied, theme, true),
                const SizedBox(height: 20),
                if (reflection.isNotEmpty)
                  _buildCard(reflection, "Reflection", Icons.psychology, theme, false),
                if (reflection.isNotEmpty) const SizedBox(height: 20),
                if (action.isNotEmpty)
                  _buildCard(action, "Action Step", Icons.lightbulb_outline, theme, true),
                if (action.isNotEmpty) const SizedBox(height: 28),
                Text(
                  'Songs to Lift Your Mood 🎵',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D4A42),
                  ),
                ),
                const SizedBox(height: 12),
                ...songs.map((songData) {
                  final song = songData as Map<String, dynamic>;
                  final youtubeId = YoutubePlayer.convertUrlToId(song['youtubeLink'] ?? '');
                  return _SongCard(
                    title: song['title'] ?? 'Unknown Title',
                    artist: song['artist'] ?? 'Unknown Artist',
                    youtubeVideoId: youtubeId ?? '',
                    youtubeLink: song['youtubeLink'],
                    theme: theme,
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String content, String title, IconData icon, ThemeData theme, bool iconLeft) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: iconLeft ? TextDirection.ltr : TextDirection.rtl,
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D4A42))),
                const SizedBox(height: 8),
                Text(content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF2D4A42), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Updated SongCard =================
class _SongCard extends StatefulWidget {
  final String title;
  final String artist;
  final String youtubeVideoId;
  final String? youtubeLink;
  final ThemeData theme;

  const _SongCard({
    Key? key,
    required this.title,
    required this.artist,
    required this.youtubeVideoId,
    this.youtubeLink,
    required this.theme,
  }) : super(key: key);

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  YoutubePlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.youtubeVideoId.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: widget.youtubeVideoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      )..addListener(() {
        final value = _controller?.value;
        if (value != null && value.hasError) {
          setState(() => _hasError = true);
        }
      });
    } else {
      _hasError = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openInYoutube() async {
    if (widget.youtubeLink == null) return;
    final url = Uri.parse(widget.youtubeLink!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open YouTube')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + YouTube button (text and logo side by side)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2D4A42),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.youtubeLink != null)
                InkWell(
                  onTap: _openInYoutube,
                  child: Row(
                    children: [
                      const Text(
                        'Open in',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Image.asset(
                        'assets/images/youtube.png',
                        width: 50,
                        height: 50,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.artist, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),

          // Error or Player
          if (_hasError || widget.youtubeVideoId.isEmpty)
            const Text(
              '⚠️ Playback on this app is disabled by the video owner. Please open in YouTube.',
              style: TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            )
          else if (_controller != null)
            YoutubePlayer(
              controller: _controller!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
            ),
        ],
      ),
    );
  }
}
