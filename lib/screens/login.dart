import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your reference/dashboard screens
import 'recommendation_screen.dart';
import 'dashboard.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _redirectBasedOnLatestEntry() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      return;
    }

    try {
      final entriesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('entries');

      final querySnapshot = await entriesRef
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }

      final docSnapshot = querySnapshot.docs.first;
      final doc = docSnapshot.data();
      final createdAtValue = doc['createdAt'];

      if (createdAtValue == null || createdAtValue is! Timestamp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }

      final DateTime createdAt = createdAtValue.toDate();
      final DateTime now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inMinutes <= 15) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RecommendationScreen(
              entryId: docSnapshot.id,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e, st) {
      debugPrint('Error checking latest entry: $e\n$st');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  Future<bool> _checkUserDocExists(String uid) async {
    final userDoc = await _firestore.collection('Users').doc(uid).get();
    return userDoc.exists;
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorText = null;
      _isLoading = true;
      _faceState = FaceState.typing;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
            code: 'user-not-found', message: 'User not found after sign-in');
      }

      final userDocExists = await _checkUserDocExists(user.uid);

      if (!userDocExists) {
        await _auth.signOut();

        setState(() {
          _errorText = 'No account found. Please create an account.';
          _faceState = FaceState.error;
          _isLoading = false;
        });
        return;
      }

      setState(() => _faceState = FaceState.success);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _redirectBasedOnLatestEntry();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = 'FirebaseAuth error: ${e.code} - ${e.message}';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Sign-in failed: $e';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _validateEmail(email) != null) {
      setState(() {
        _errorText = 'Enter a valid email for password reset';
        _faceState = FaceState.error;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() {
        _errorText = 'Password reset email sent. Check your inbox.';
        _faceState = FaceState.success;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Failed to send reset email';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Failed to send reset email';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _errorText = null;
      _isLoading = true;
      _faceState = FaceState.typing;
    });

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _faceState = FaceState.neutral;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _auth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
            code: 'user-not-found', message: 'User not found after Google sign-in');
      }

      final userDocExists = await _checkUserDocExists(user.uid);

      if (!userDocExists) {
        await _auth.signOut();

        setState(() {
          _errorText = 'No account found. Please create an account.';
          _faceState = FaceState.error;
          _isLoading = false;
        });
        return;
      }

      setState(() => _faceState = FaceState.success);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _redirectBasedOnLatestEntry();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message ?? 'Google sign-in failed';
        _faceState = FaceState.error;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Google sign-in failed';
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
    final primary = Theme.of(context).colorScheme.primary; // #5B9A8B Muted Teal
    final secondary = Theme.of(context).colorScheme.secondary; // #E6C79C Soft Gold
    final background = const Color(0xFFFEFCF8); // Light Cream
    final cardColor = const Color(0xFFF8F6F3); // Pearl White

    return Scaffold(
      backgroundColor: background,
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
                      color:
                      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Log in to continue',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: secondary,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, color: primary),
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: _validateEmail,
                          style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                        SizedBox(height: 16.h),
                        TextFormField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline, color: primary),
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: _validatePassword,
                          style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color),
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
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signInWithEmailPassword,
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
                                const AlwaysStoppedAnimation(Colors.white),
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
                        GestureDetector(
                          onTap: _isLoading ? null : _forgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Or',
                          style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: Image.asset(
                              'assets/images/google.png',
                              height: 22.h,
                              width: 22.h,
                            ),
                            label: Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r)),
                              side: BorderSide(color: Colors.grey.shade400),
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
        color: const Color(0xFFF8F6F3), // Pearl White circle background
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1), // subtle teal shadow
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
