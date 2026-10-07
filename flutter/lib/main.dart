import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/session_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/shared/app_shell.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(ChangeNotifierProvider(
      create: (_) => SessionProvider()..restore(), child: const AcademyApp()));
}

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MS Defence Academy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Consumer<SessionProvider>(
            builder: (context, session, _) => !session.isLoggedIn
                ? const LoginScreen()
                : session.mustChangePassword
                    ? const ChangePasswordScreen()
                    : const AppShell()),
      );
}
