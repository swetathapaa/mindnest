import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notifications
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool sendToAll = true;
  List<String> selectedUserIds = [];
  bool _isSending = false;

  // Moods
  final _newMoodCtrl = TextEditingController();
  bool showExistingMoods = false;

  // Users
  final _searchCtrl = TextEditingController();
  bool showExistingUsers = false;
  List<String> multiSelectUserIds = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _newMoodCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// ------------------ Notifications ------------------
  Future<void> _sendNotification() async {
    if (_titleCtrl.text.isEmpty || _messageCtrl.text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      List<String> userIds = sendToAll
          ? (await _firestore.collection('Users').where('userType', isEqualTo: 'general').get())
          .docs
          .map((doc) => doc.id)
          .toList()
          : selectedUserIds;

      for (String uid in userIds) {
        await _firestore
            .collection('Users')
            .doc(uid)
            .collection('notifications')
            .add({
          'title': _titleCtrl.text.trim(),
          'message': _messageCtrl.text.trim(),
          'sentAt': DateTime.now(),
          'read': false,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent successfully!')),
      );
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() {
        selectedUserIds = [];
        sendToAll = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send notification: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Widget _buildNotificationUserSelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Users').where('userType', isEqualTo: 'general').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final users = snapshot.data!.docs;
        return Column(
          children: users.map((doc) {
            final email = doc['email'] ?? '';
            final uid = doc.id;
            return CheckboxListTile(
              value: selectedUserIds.contains(uid),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    selectedUserIds.add(uid);
                  } else {
                    selectedUserIds.remove(uid);
                  }
                });
              },
              title: Text(email),
            );
          }).toList(),
        );
      },
    );
  }

  /// ------------------ Mood Management ------------------
  Future<void> _addMood() async {
    final moodName = _newMoodCtrl.text.trim();
    if (moodName.isEmpty) return;
    try {
      await _firestore.collection('Moods').add({'name': moodName});
      _newMoodCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add mood: $e')),
      );
    }
  }

  Future<void> _editMood(String docId, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Mood'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
    if (confirm ?? false) {
      try {
        await _firestore.collection('Moods').doc(docId).update({'name': ctrl.text.trim()});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mood updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update mood: $e')),
        );
      }
    }
  }

  Future<void> _deleteMood(String docId) async {
    try {
      await _firestore.collection('Moods').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete mood: $e')),
      );
    }
  }

  Widget _buildMoodList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Moods').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final moods = snapshot.data!.docs;
        return Column(
          children: moods.map((doc) {
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              child: ListTile(
                title: Text(doc['name'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.green),
                      onPressed: () => _editMood(doc.id, doc['name']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: Text('Delete mood ${doc['name']}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm ?? false) _deleteMood(doc.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// ------------------ User Management ------------------
  Future<void> _deleteUser(String uid) async {
    try {
      await _firestore.collection('Users').doc(uid).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    }
  }

  Widget _buildUserList({String searchName = ''}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Users').where('userType', isEqualTo: 'general').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final users = snapshot.data!.docs.where((doc) {
          if (searchName.isEmpty) return true;
          return doc['name'].toString().toLowerCase().contains(searchName.toLowerCase());
        }).toList();

        if (searchName.isNotEmpty && users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No user found'),
          );
        }

        return Column(
          children: users.map((doc) {
            final name = doc['name'] ?? '';
            final email = doc['email'] ?? '';
            final uid = doc.id;
            final selected = multiSelectUserIds.contains(uid);

            return Card(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              child: ListTile(
                leading: Checkbox(
                  value: selected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        multiSelectUserIds.add(uid);
                      } else {
                        multiSelectUserIds.remove(uid);
                      }
                    });
                  },
                ),
                title: Text(name),
                subtitle: Text(email),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: Text('Delete user $name?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm ?? false) _deleteUser(uid);
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// ------------------ Top Stats ------------------
  Widget _buildStatsCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: EdgeInsets.all(16.h),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<int> _getTotalUsers() async {
    final snapshot = await _firestore.collection('Users').where('userType', isEqualTo: 'general').get();
    return snapshot.docs.length;
  }

  Future<int> _getTotalEntries() async {
    final usersSnapshot = await _firestore.collection('Users').where('userType', isEqualTo: 'general').get();
    int count = 0;
    for (var doc in usersSnapshot.docs) {
      final entriesSnapshot = await doc.reference.collection('Entries').get();
      count += entriesSnapshot.docs.length;
    }
    return count;
  }

  Future<int> _getTotalMoods() async {
    final snapshot = await _firestore.collection('Moods').get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF5B9A8B);
    final cardColor = const Color(0xFFF8F6F3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm ?? false) {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------ Stats Cards ------------------
            FutureBuilder<List<int>>(
              future: Future.wait([_getTotalUsers(), _getTotalEntries(), _getTotalMoods()]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final stats = snapshot.data!;
                return Row(
                  children: [
                    _buildStatsCard('Total Users', stats[0], primary),
                    SizedBox(width: 8.w),
                    _buildStatsCard('Total Entries', stats[1], Colors.orangeAccent),
                    SizedBox(width: 8.w),
                    _buildStatsCard('Total Moods', stats[2], Colors.purpleAccent),
                  ],
                );
              },
            ),
            SizedBox(height: 16.h),
            // ------------------ User Management ------------------
            ExpansionTile(
              title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search Users by Name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (_searchCtrl.text.isNotEmpty)
                  _buildUserList(searchName: _searchCtrl.text),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => showExistingUsers = !showExistingUsers),
                  child: Text(showExistingUsers ? 'Hide Existing Users' : 'View Existing Users'),
                ),
                if (showExistingUsers) _buildUserList(),
              ],
            ),
            const SizedBox(height: 16),
            // ------------------ Mood Management ------------------
            ExpansionTile(
              title: const Text('Mood Management', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newMoodCtrl,
                        decoration: InputDecoration(
                          labelText: 'New Mood',
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addMood,
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      child: const Text('Add Mood'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => showExistingMoods = !showExistingMoods),
                  child: Text(showExistingMoods ? 'Hide Existing Moods' : 'View Existing Moods'),
                ),
                if (showExistingMoods) _buildMoodList(),
              ],
            ),
            const SizedBox(height: 16),
            // ------------------ Notifications ------------------
            ExpansionTile(
              title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notification Message',
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: sendToAll,
                      onChanged: (val) => setState(() => sendToAll = val ?? true),
                    ),
                    const Text('Send to all users'),
                  ],
                ),
                if (!sendToAll)
                  Container(
                    height: 200.h,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: _buildNotificationUserSelection(),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendNotification,
                    style: ElevatedButton.styleFrom(backgroundColor: primary, padding: EdgeInsets.symmetric(vertical: 14.h)),
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send Notification', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
