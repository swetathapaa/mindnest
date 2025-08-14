import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'user_dashboard.dart';

class RecommendationScreen extends StatefulWidget {
  final String entryId;

  const RecommendationScreen({Key? key, required this.entryId})
    : super(key: key);

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _entryFuture;
  String userName = 'Friend';

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      userName =
          currentUser.displayName ??
          currentUser.email?.split('@').first ??
          'Friend';

      _entryFuture = FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('Entries')
          .doc(widget.entryId)
          .get();
    } else {
      // If no user is logged in, create a failed future to avoid null error
      _entryFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Your Recommendations'),
        leading: BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, size: 28),
            tooltip: 'User Dashboard',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserDashboardScreen(),
                ),
              );
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
          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
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
                Text(
                  'Hey $userName, here’s what I have for you today:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),

                _buildCard(
                  title: "Mood Summary",
                  content: summary,
                  theme: theme,
                ),
                const SizedBox(height: 20),

                if (reflection.isNotEmpty)
                  _buildCard(
                    title: "Reflection",
                    content: reflection,
                    theme: theme,
                  ),
                if (reflection.isNotEmpty) const SizedBox(height: 20),

                if (action.isNotEmpty)
                  _buildCard(
                    title: "Action Step",
                    content: action,
                    theme: theme,
                    icon: Icons.lightbulb_outline,
                  ),
                if (action.isNotEmpty) const SizedBox(height: 28),

                Text(
                  'Songs to Lift Your Mood 🎵',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                ...songs.map((songData) {
                  final song = songData as Map<String, dynamic>;
                  String ytLink = song['youtubeLink'] ?? '';
                  // final youtubeId = ytLink.split('v=').last.contains('&')
                  //     ? ytLink.split('v=').last.split('&').first
                  //     : ytLink.split('v=').last;
                  final youtubeId = YoutubePlayer.convertUrlToId(song['youtubeLink'] ?? '');
                  if (youtubeId == null) return const SizedBox.shrink();
                  return _SongCard(
                    title: song['title'] ?? 'Unknown Title',
                    artist: song['artist'] ?? 'Unknown Artist',
                    youtubeVideoId: youtubeId,
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

  Widget _buildCard({
    required String title,
    required String content,
    required ThemeData theme,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: theme.colorScheme.secondary, size: 28),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCard extends StatefulWidget {
  final String title;
  final String artist;
  final String youtubeVideoId;
  final ThemeData theme;

  const _SongCard({
    Key? key,
    required this.title,
    required this.artist,
    required this.youtubeVideoId,
    required this.theme,
  }) : super(key: key);

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeVideoId,
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.artist,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: theme.colorScheme.primary,
            progressColors: ProgressBarColors(
              playedColor: theme.colorScheme.primary,
              handleColor: theme.colorScheme.primary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
