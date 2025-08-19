import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum FaceState { neutral, typing, error, success }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(); // <-- DOB controller

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  FaceState _faceState = FaceState.neutral;
  bool _isLoading = false;
  String? _errorText;

  String? _selectedGender;
  DateTime? _selectedDob;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> allowedGenders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    signInOption: SignInOption.standard,
  );

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_updateFaceOnFocus);
    _emailFocus.addListener(_updateFaceOnFocus);
    _passwordFocus.addListener(_updateFaceOnFocus);
    _confirmFocus.addListener(_updateFaceOnFocus);
    _nameCtrl.addListener(_onTyping);
    _emailCtrl.addListener(_onTyping);
    _passwordCtrl.addListener(_onTyping);
    _confirmCtrl.addListener(_onTyping);
  }

  void _updateFaceOnFocus() {
    if (_nameFocus.hasFocus ||
        _emailFocus.hasFocus ||
        _passwordFocus.hasFocus ||
        _confirmFocus.hasFocus) {
      setState(() => _faceState = FaceState.typing);
    } else if (_errorText != null) {
      setState(() => _faceState = FaceState.error);
    } else {
      setState(() => _faceState = FaceState.neutral);
    }
  }

  void _onTyping() {
    if (_faceState != FaceState.typing) setState(() => _faceState = FaceState.typing);
    if (_errorText != null) setState(() => _errorText = null);
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your name';
    if (v.trim().length < 2) return 'Name too short';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your password';
    if (v.trim().length < 6) return 'Password too short';
    return null;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    final initial = _selectedDob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text = _formatDob(picked); // ✅ immediately preview the selected date
      });
    }
  }

  String _formatDob(DateTime dob) =>
      '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() {
      _errorText = null;
      _isLoading = true;
      _faceState = FaceState.typing;
    });

    // Validation
    final nameError = _validateName(_nameCtrl.text);
    final emailError = _validateEmail(_emailCtrl.text);
    final passwordError = _validatePassword(_passwordCtrl.text);
    final confirmError = _validatePassword(_confirmCtrl.text);
    if (nameError != null || emailError != null || passwordError != null || confirmError != null) {
      setState(() {
        _errorText = nameError ?? emailError ?? passwordError ?? confirmError;
        _faceState = FaceState.error;
        _isLoading = false;
      });
      return;
    }
    if (_selectedGender == null || _selectedDob == null) {
      setState(() {
        _errorText = _selectedGender == null ? 'Select your gender' : 'Select your date of birth';
        _faceState = FaceState.error;
        _isLoading = false;
      });
      return;
    }
    if (_passwordCtrl.text.trim() != _confirmCtrl.text.trim()) {
      setState(() {
        _errorText = 'Passwords do not match';
        _faceState = FaceState.error;
        _isLoading = false;
      });
      return;
    }

    try {
      // Step 1: Create Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      final user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-null', message: 'User creation failed');

      // Step 2: Store in Firestore (skip FCM for now)
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gender': _selectedGender,
        'dob': Timestamp.fromDate(_selectedDob!),
        'userType': 'general',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Step 3: Show formal success message and redirect to login
      setState(() {
        _faceState = FaceState.success;
        _errorText = 'Account created! Please login.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          _errorText = 'Your account already exists. Redirecting to login...';
          _faceState = FaceState.error;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _errorText = e.message ?? 'Registration failed';
          _faceState = FaceState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorText = 'Something went wrong. Please try again.';
        _faceState = FaceState.error;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _dobCtrl.dispose(); // dispose DOB controller
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),
              Text(
                _faceState == FaceState.neutral
                    ? '🙂'
                    : _faceState == FaceState.typing
                    ? '✍️'
                    : _faceState == FaceState.error
                    ? '😟'
                    : '😃',
                style: TextStyle(fontSize: 60.sp),
              ),
              SizedBox(height: 16.h),
              Text('Create your MindNest',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 4.h),
              Text('Sign up to get started', style: TextStyle(fontSize: 14.sp)),
              SizedBox(height: 32.h),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateName,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: allowedGenders.contains(_selectedGender) ? _selectedGender : null,
                      hint: const Text('Select Gender'),
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.transgender_outlined),
                      ),
                      items: allowedGenders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGender = v),
                      validator: (v) => v == null ? 'Select your gender' : null,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      onTap: _pickDob,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: _validatePassword,
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _errorText!,
                            style: TextStyle(color: Colors.red[400], fontSize: 12.sp),
                          ),
                        ),
                      ),
                    SizedBox(height: 28.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
                        child: _isLoading
                            ? SizedBox(
                          height: 18.h,
                          width: 18.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                            : const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
