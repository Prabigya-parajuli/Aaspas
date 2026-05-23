import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({Key? key}) : super(key: key);

  @override
  State<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  final AuthService _authService = AuthService();
  bool _isVerified = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    final verified = await _authService.isEmailVerified();
    if (mounted) {
      setState(() {
        _isVerified = verified;
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isLoading = true);
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshVerification() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    await _checkVerification();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVerified ? 'Email verified!' : 'Email not verified yet',
          ),
          backgroundColor: _isVerified ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange[100],
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Email not verified',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Verify your email to create events',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _resendVerification,
                  child: const Text('Resend'),
                ),
                TextButton(
                  onPressed: _refreshVerification,
                  child: const Text('Refresh'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
