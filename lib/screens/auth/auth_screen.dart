import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;

  void _toggleAuthMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoginMode
        ? LoginPage(onSignupTap: _toggleAuthMode)
        : SignupPage(onLoginTap: _toggleAuthMode);
  }
}