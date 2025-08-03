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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    if (_faceState != FaceState.typing) {
      setState(() => _faceState = FaceState.typing);
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
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
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  String _formatDob(DateTime dob) {
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
    });

    final nameError = _validateName(_nameCtrl.text);
    final emailError = _validateEmail(_emailCtrl.text);
    final passwordError = _validatePassword(_passwordCtrl.text);
    final confirmError = _validatePassword(_confirmCtrl.text);

    if (nameError != null) {
      setState(() {
        _errorText = nameError;
        _faceState = FaceState.error;
      });
      return;
    }
    if (emailError != null) {
      setState(() {
        _errorText = emailError;
        _faceState = FaceState.error;
      });
      return;
    }
    if (_selectedGender == null) {
      setState(() {
        _errorText = 'Select your gender';
        _faceState = FaceState.error;
      });
      return;
    }
    if (_selectedDob == null) {
      setState(() {
        _errorText = 'Select your date of birth';
        _faceState = FaceState.error;
      });
      return;
    }
    if (passwordError != null) {
      setState(() {
        _errorText = passwordError;
        _faceState = FaceState.error;
      });
      return;
    }
    if (confirmError != null) {
      setState(() {
        _errorText = confirmError;
        _faceState = FaceState.error;
      });
      return;
    }
    if (_passwordCtrl.text.trim() != _confirmCtrl.text.trim()) {
      setState(() {
        _errorText = 'Passwords do not match';
        _faceState = FaceState.error;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _faceState = FaceState.typing;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        // Save extra info to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'gender': _selectedGender,
          'dob': _selectedDob!.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _faceState = FaceState.success;
        });

        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/preference'); // or dashboard
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Registration failed';
        _faceState = FaceState.error;
      });
    } catch (e) {
      setState(() {
        _errorText = 'An error occurred, please try again.';
        _faceState = FaceState.error;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _errorText = 'Google sign-in cancelled';
          _faceState = FaceState.error;
          _isLoading = false;
        });
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        setState(() {
          _errorText = 'Google sign-in failed';
          _faceState = FaceState.error;
          _isLoading = false;
        });
        return;
      }

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // New user - redirect to complete profile screen to get gender and dob
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete-profile', arguments: user);
      } else {
        // Existing user - proceed to dashboard
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorText = 'Google sign-in error: $e';
        _faceState = FaceState.error;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: 40.h),
                  CharacterFace(state: _faceState),
                  SizedBox(height: 16.h),
                  Text(
                    'Create your MindNest',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Sign up to get started',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 32.h),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: _validateName,
                        ),
                        SizedBox(height: 16.h),
                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: _validateEmail,
                        ),
                        SizedBox(height: 16.h),
                        // Gender dropdown
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
                            });
                          },
                        ),
                        SizedBox(height: 16.h),
                        // DOB picker
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
                        SizedBox(height: 16.h),
                        // Password
                        TextFormField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          validator: _validatePassword,
                        ),
                        SizedBox(height: 16.h),
                        // Confirm password
                        TextFormField(
                          controller: _confirmCtrl,
                          focusNode: _confirmFocus,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          validator: _validatePassword,
                        ),
                        if (_errorText != null) ...[
                          SizedBox(height: 8.h),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                color: Colors.red[400],
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 28.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? SizedBox(
                              height: 18.h,
                              width: 18.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Google sign up button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Image.asset(
                              'assets/images/google.png', // your Google icon asset
                              height: 20.h,
                              width: 20.h,
                            ),
                            label: Text(
                              'Sign up with Google',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black87,
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleGoogleSignUp,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: secondary,
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'MindNest • Mood & Music Companion',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CharacterFace widget (from your original code)
class CharacterFace extends StatelessWidget {
  final FaceState state;
  const CharacterFace({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    String faceEmoji;
    switch (state) {
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
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: 140.w,
      height: 140.w,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        faceEmoji,
        style: TextStyle(fontSize: 52.sp),
      ),
    );
  }
}
