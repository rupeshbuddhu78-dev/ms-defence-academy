import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final session = context.read<SessionProvider>();
    final success = await session.login(email.text.trim(), password.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(session.error ?? 'Sign in failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<SessionProvider>().settings;
    final appName = branding['name']?.toString() ?? 'MS Defence Academy';
    final logoUrl = branding['logoUrl']?.toString() ?? '';
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  Container(
                    height: 230,
                    decoration: BoxDecoration(
                      color: AcademyColors.forest,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -35,
                          child: Icon(Icons.shield_outlined,
                              size: 190,
                              color: Colors.white.withValues(alpha: .06)),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF101311),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFD7B65B),
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: logoUrl.startsWith('http')
                                    ? Image.network(logoUrl, fit: BoxFit.contain)
                                    : Image.asset('assets/academy_app_icon.png', fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 16),
                              Text(appName.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              const Text('DISCIPLINE • DEDICATION • SUCCESS',
                                  style: TextStyle(
                                      color: Color(0xFFE4D190),
                                      fontSize: 10,
                                      letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Welcome back',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text('Sign in to continue your academy journey.',
                      style: TextStyle(color: AcademyColors.muted)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Phone number or email',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Consumer<SessionProvider>(
                    builder: (context, session, _) => FilledButton(
                      onPressed: session.busy ? null : submit,
                      child: session.busy
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('CONNECTING...'),
                              ],
                            )
                          : const Text('SIGN IN'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                      child: Text(
                          'Role-based access for students and academy staff',
                          style: TextStyle(
                              fontSize: 11, color: AcademyColors.muted))),
                  const SizedBox(height: 34),
                  const Center(
                      child: Text('Shahpur Patori, Samastipur  •  8228949212',
                          style: TextStyle(
                              fontSize: 11, color: AcademyColors.muted))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
