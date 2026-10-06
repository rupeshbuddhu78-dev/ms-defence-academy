import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';

class AdminAccountPage extends StatefulWidget {
  const AdminAccountPage({super.key});

  @override
  State<AdminAccountPage> createState() => _AdminAccountPageState();
}

class _AdminAccountPageState extends State<AdminAccountPage> {
  late final TextEditingController email;
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    final current = context.read<SessionProvider>().user?['email']?.toString() ?? '';
    email = TextEditingController(text: current);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final nextEmail = email.text.trim().toLowerCase();
    final nextPassword = password.text;
    if (!nextEmail.contains('@') || !nextEmail.contains('.')) {
      _message('Enter a valid Gmail or email address.');
      return;
    }
    if (nextPassword.length < 10 || nextPassword.length > 72) {
      _message('Password must be between 10 and 72 characters.');
      return;
    }
    if (nextPassword != confirm.text) {
      _message('The passwords do not match.');
      return;
    }
    final session = context.read<SessionProvider>();
    final success = await session.updateAdminAccount(nextEmail, nextPassword);
    if (!mounted) return;
    if (success) {
      password.clear();
      confirm.clear();
      _message('Admin email and password updated successfully.');
    } else {
      _message(session.error ?? 'Account update failed.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin account')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined,
                          size: 52, color: AcademyColors.green),
                      const SizedBox(height: 12),
                      const Text('Change admin login details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'You can update the admin Gmail and password without entering the current password. You must be logged in as an admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AcademyColors.muted),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin Gmail / email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'New password (10+ characters)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirm,
                        obscureText: obscure,
                        onSubmitted: (_) => save(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Consumer<SessionProvider>(
                        builder: (context, session, _) => FilledButton.icon(
                          onPressed: session.busy ? null : save,
                          icon: const Icon(Icons.save_outlined),
                          label: session.busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Save account details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
