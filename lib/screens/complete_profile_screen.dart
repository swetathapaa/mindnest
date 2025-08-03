import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum FaceState { neutral, typing, error, success }

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String? _selectedGender;
  DateTime? _selectedDob;

  FaceState _faceState = FaceState.neutral;
  bool _isLoading = false;
  String? _errorText;

  // For prefill if profile exists
  bool _initialized = false;

  User? get _userFromArgs {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is User) return args;
    return null;
  }

  User get _user => _userFromArgs ?? _auth.currentUser!;

  @override
  void initState() {
    super.initState();
    // Load existing profile (if any) after first build, because context needed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadExisting());
  }

  Future<void> _maybeLoadExisting() async {
    if (_initialized) return;
    setState(() {
      _isLoading = true;
    });

    final doc = await _fs.collection('users').doc(_user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        if (data['gender'] != null) {
          _selectedGender = data['gender'] as String;
        }
        if (data['dob'] != null) {
          final dobValue = data['dob'];
          if (dobValue is Timestamp) {
            _selectedDob = dobValue.toDate();
          } else if (dobValue is String) {
            try {
              _selectedDob = DateTime.parse(dobValue);
            } catch (_) {}
          }
        }
      }
    }

    setState(() {
      _initialized = true;
      _isLoading = false;
    });
  }

  Future<void> _pickDob() async {
    setState(() => _faceState = FaceState.typing);
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    final initial = _selectedDob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _errorText = null;
      });
    }
  }

  String _formatDob(DateTime dob) {
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  Future<void> _submitProfile() async {
    if (_selectedGender == null) {
      setState(() {
        _errorText = 'Please select your gender';
        _faceState = FaceState.error;
      });
      return;
    }
    if (_selectedDob == null) {
      setState(() {
        _errorText = 'Please select your date of birth';
        _faceState = FaceState.error;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _faceState = FaceState.typing;
    });

    try {
      final uid = _user.uid;
      final name = _user.displayName ?? '';
      final email = _user.email ?? '';

      await _fs.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'gender': _selectedGender,
        'dob': Timestamp.fromDate(_selectedDob!),
        'updatedAt': FieldValue.serverTimestamp(),
        'providers': _user.providerData.map((p) => p.providerId).toList(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _faceState = FaceState.success;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() {
        _errorText = 'Failed to save profile. Try again.';
        _faceState = FaceState.error;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFace() {
    String faceEmoji;
    switch (_faceState) {
      case FaceState.typing:
        faceEmoji = '😊';
        break;
      case FaceState.error:
        faceEmoji = '😟';
        break;
      case FaceState.success:
        faceEmoji = '😄';
        break;
      case FaceState.neutral:
      default:
        faceEmoji = '🙂';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 120.w,
      height: 120.w,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        faceEmoji,
        style: TextStyle(fontSize: 48.sp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && !_initialized
          ? Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation(primary),
        ),
      )
          : SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16.h),
              Center(child: _buildFace()),
              SizedBox(height: 16.h),
              Text(
                'Almost there',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Tell us a bit more to complete your profile',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 24.h),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.transgender_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                  DropdownMenuItem(
                      value: 'Prefer not to say',
                      child: Text('Prefer not to say')),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedGender = v;
                    _errorText = null;
                    if (_faceState != FaceState.typing) {
                      _faceState = FaceState.typing;
                    }
                  });
                },
              ),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: _pickDob,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      hintText: _selectedDob != null
                          ? _formatDob(_selectedDob!)
                          : 'DD/MM/YYYY',
                    ),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                SizedBox(height: 12.h),
                Text(
                  _errorText!,
                  style: TextStyle(color: Colors.red[400], fontSize: 12.sp),
                ),
              ],
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 18.h,
                    width: 18.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'MindNest • Mood & Music Companion',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
