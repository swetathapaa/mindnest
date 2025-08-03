import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  Future<void> _createOrUpdateUserProfile({
    required User user,
    String? name,
    String? gender,
    DateTime? dob,
  }) async {
    final doc = _fs.collection('users').doc(user.uid);
    final data = {
      'email': user.email,
      'displayName': name ?? user.displayName,
      'gender': gender,
      'dob': dob != null ? Timestamp.fromDate(dob) : null,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    };
    await doc.set(data, SetOptions(merge: true));
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String gender,
    required DateTime dob,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await _createOrUpdateUserProfile(
      user: cred.user!,
      name: name,
      gender: gender,
      dob: dob,
    );
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await _createOrUpdateUserProfile(user: cred.user!);
    return cred;
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign-in aborted');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    await _createOrUpdateUserProfile(user: cred.user!);
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
