import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum FaceState { neutral, typing, error, success }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  FaceState _faceState = FaceState.neutral;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_updateFaceOnFocusChange);
    _passwordFocus.addListener(_updateFaceOnFocusChange);
    _emailCtrl.addListener(_onTyping);
    _passwordCtrl.addListener(_onTyping);
  }

  void _updateFaceOnFocusChange() {
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) {
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

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
    });

    final emailError = _validateEmail(_emailCtrl.text);
    final passwordError = _validatePassword(_passwordCtrl.text);

    if (emailError != null) {
      setState(() {
        _errorText = emailError;
        _faceState = FaceState.error;
        _isLoading = false;
      });
      return;
    }

    if (passwordError != null) {
      setState(() {
        _errorText = passwordError;
        _faceState = FaceState.error;
        _isLoading = false;
      });
      return;
    }

    // All validations passed
    setState(() {
      _isLoading = true;
      _faceState = FaceState.typing;
    });

    await Future.delayed(const Duration(seconds: 1)); // simulate auth delay

    // Dummy check: password must be "flutter123"
    if (_passwordCtrl.text.trim() == 'flutter123') {
      setState(() {
        _faceState = FaceState.success;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _errorText = 'Invalid credentials. Try again.';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
                    'Welcome to MindNest',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Log in to continue',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 32.h),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                              'Login',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/signup');
                              },
                              child: Text(
                                'Sign up',
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

/// Reactive character face widget adapted for yellowish theme.
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
        color: const Color(0xFFFFF8EE), // soft creamy background (leans yellow)
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
