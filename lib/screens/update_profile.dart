import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({Key? key}) : super(key: key);

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String _gender = 'Female';
  String _email = '';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';

        if (data['dob'] != null && data['dob'] is Timestamp) {
          DateTime dob = (data['dob'] as Timestamp).toDate();
          _dobController.text = DateFormat('yyyy-MM-dd').format(dob);
        }

        _gender = data['gender'] ?? 'Female';
      }
    } catch (e) {
      debugPrint('Failed to load user data: $e');
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    DateTime? initialDate;
    if (_dobController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(_dobController.text);
      } catch (_) {
        initialDate = DateTime(2000, 1, 1);
      }
    } else {
      initialDate = DateTime(2000, 1, 1);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'dob': _dobController.text.isNotEmpty
            ? Timestamp.fromDate(DateFormat('yyyy-MM-dd').parse(_dobController.text))
            : null,
        'gender': _gender,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }

    setState(() {
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF5B9A8B);
    final bgColor = const Color(0xFFFEFCF8);
    final cardColor = const Color(0xFFF8F6F3);
    final textColor = const Color(0xFF2D4A42);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: primaryColor,
      ),
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Email (read-only)
              TextFormField(
                initialValue: _email,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your full name',
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // DOB
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      hintText: 'YYYY-MM-DD',
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your date of birth';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Gender
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                    DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _gender = val;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: primaryColor,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
