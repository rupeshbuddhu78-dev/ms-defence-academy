import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  final otp = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool sent = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    otp.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> requestOtp() async {
    final session = context.read<SessionProvider>();
    final ok = await session.requestPasswordReset(email.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => sent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If this email is registered, the OTP has been sent.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(session.error ?? 'Could not send OTP')));
    }
  }

  Future<void> reset() async {
    if (password.text.length < 10 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a matching password of at least 10 characters.')));
      return;
    }
    final session = context.read<SessionProvider>();
    final ok = await session.resetPassword(email.text.trim(), otp.text.trim(), password.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully. Please sign in.')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(session.error ?? 'Password reset failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<SessionProvider>().busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 54, color: AcademyColors.green),
                      const SizedBox(height: 12),
                      const Text('Reset your password', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Enter the email registered with the academy. We will send a 6-digit OTP.', textAlign: TextAlign.center, style: TextStyle(color: AcademyColors.muted)),
                      const SizedBox(height: 22),
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Registered email', prefixIcon: Icon(Icons.email_outlined))),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: busy ? null : requestOtp, child: const Text('SEND OTP')),
                      if (sent) ...[
                        const SizedBox(height: 22),
                        TextField(controller: otp, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit OTP', prefixIcon: Icon(Icons.pin_outlined))),
                        TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'New password (10+ characters)', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                        const SizedBox(height: 14),
                        TextField(controller: confirm, obscureText: obscure, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
                        const SizedBox(height: 20),
                        FilledButton(onPressed: busy ? null : reset, child: const Text('RESET PASSWORD')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
