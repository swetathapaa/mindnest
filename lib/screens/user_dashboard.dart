import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({Key? key}) : super(key: key);

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  User? user;
  String email = '';

  final Color primaryText = const Color(0xFF2D4A42); // Dark Teal
  final Color accentColor = const Color(0xFF5B9A8B); // Muted Teal
  final Color cardColor = const Color(0xFFF8F6F3); // Pearl White
  final Color backgroundColor = const Color(0xFFFEFCF8);

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      user = currentUser;
      email = currentUser.email ?? '';
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _sendPasswordReset() async {
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Do you want to receive a password reset email at $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (shouldSend == true) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reset email: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: accentColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users') // ✅ Capital U
                .doc(user?.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final displayName = userData['name'] ?? email.split('@').first;
              final lastSeen = userData['lastSeen'] is Timestamp
                  ? DateFormat('MMM d, yyyy').format(userData['lastSeen'].toDate())
                  : '-';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Users') // ✅ Capital U
                    .doc(user?.uid)
                    .collection('Entries') // ✅ Capital E
                    .orderBy('CreatedAt', descending: true) // ✅ Capital C
                    .snapshots(),
                builder: (context, entriesSnapshot) {
                  if (!entriesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = entriesSnapshot.data!.docs;
                  final totalEntries = entries.length;

                  String lastActive = lastSeen;
                  if (entries.isNotEmpty) {
                    final createdAtField = entries.first['CreatedAt'];
                    if (createdAtField is Timestamp) {
                      lastActive = DateFormat('MMM d, yyyy').format(createdAtField.toDate());
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        "Hi, $displayName 👋",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryText.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats Row
                      Row(
                        children: [
                          _buildStatCard("Total Entries", totalEntries.toString()),
                          const SizedBox(width: 10),

                          const SizedBox(width: 10),
                          _buildStatCard("Last Entry", lastActive, isDate: true),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Buttons Grid
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 3 / 2,
                          children: [
                            _DashboardButton(
                              icon: Icons.show_chart,
                              label: 'Mood Graph',
                              onTap: () {
                                Navigator.pushNamed(context, '/mood-graph');
                              },
                            ),
                            _DashboardButton(
                              icon: Icons.person,
                              label: 'Update Profile',
                              onTap: () {
                                Navigator.pushNamed(context, '/update-profile');
                              },
                            ),
                            _DashboardButton(
                              icon: Icons.lock_open,
                              label: 'Forgot Password',
                              onTap: _sendPasswordReset,
                            ),
                            _DashboardButton(
                              icon: Icons.lock,
                              label: 'Change Password',
                              onTap: () {
                                Navigator.pushNamed(context, '/change-password');
                              },
                            ),
                            _DashboardButton(
                              icon: Icons.edit_note,
                              label: 'New Entry',
                              onTap: () {
                                Navigator.pushNamed(context, '/dashboard');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, {bool isDate = false}) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isDate ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: primaryText.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF5B9A8B);
    final cardColor = const Color(0xFFF8F6F3);
    final primaryText = const Color(0xFF2D4A42);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: accentColor),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
