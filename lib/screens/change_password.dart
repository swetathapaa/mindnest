import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  late bool isGoogleUser;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    isGoogleUser = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  }

  String? _validatePassword(String? val) {
    if (val == null || val.isEmpty) return "Please enter a password";

    if (val.length < 8) return "Password must be at least 8 characters";

    final upperCaseReg = RegExp(r'[A-Z]');
    final lowerCaseReg = RegExp(r'[a-z]');
    final digitReg = RegExp(r'\d');
    final specialCharReg = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

    if (!upperCaseReg.hasMatch(val)) return "Must contain at least one uppercase letter";
    if (!lowerCaseReg.hasMatch(val)) return "Must contain at least one lowercase letter";
    if (!digitReg.hasMatch(val)) return "Must contain at least one number";
    if (!specialCharReg.hasMatch(val)) return "Must contain at least one special character";

    return null; // valid
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      setState(() {
        _error = "New passwords do not match.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _error = "No user logged in.";
          _isLoading = false;
        });
        return;
      }

      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password changed successfully! Please log in again.")),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          _error = "Current password is incorrect.";
        } else {
          _error = e.message;
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openGooglePasswordSettings() async {
    final Uri url = Uri.parse('https://myaccount.google.com/security');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open Google Account settings.")),
      );
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 16),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        obscureText: true,
        style: TextStyle(fontSize: 16),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: isGoogleUser
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You signed in with Google.\nPlease change your password via your Google Account settings.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.open_in_new),
                label: Text("Open Google Account Security"),
                onPressed: _openGooglePasswordSettings,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        )
            : Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              _buildPasswordField(
                label: "Current Password",
                controller: _currentPasswordController,
                validator: (val) =>
                val == null || val.isEmpty ? "Please enter current password" : null,
              ),
              _buildPasswordField(
                label: "New Password",
                controller: _newPasswordController,
                validator: _validatePassword,
              ),
              _buildPasswordField(
                label: "Confirm New Password",
                controller: _confirmPasswordController,
                validator: (val) => val == null || val.isEmpty
                    ? "Please confirm new password"
                    : null,
              ),
              SizedBox(height: 32),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _changePassword,
                  child: Text(
                      "Change Password",
                      style: TextStyle(fontSize: 20), // increased font size only
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
