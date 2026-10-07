import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../student/home_screen.dart';
import '../student/student_pages.dart';
import '../admin/admin_pages.dart';
import '../admin/student_management_page.dart' as student_management;
import '../admin/attendance_admin_page.dart' as attendance_admin;
import '../../services/notification_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  int _homeRefreshToken = 0;
  Timer? _notificationTimer;
  final Set<String> _seenNotifications = {};

  @override
  void initState() {
    super.initState();
    _pollNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollNotifications());
  }

  Future<void> _pollNotifications() async {
    try {
      final records = await context.read<SessionProvider>().api.get('/notifications') as List<dynamic>;
      for (final item in records.take(20)) {
        if (item is! Map || item['readAt'] != null) continue;
        final id = item['_id']?.toString() ?? '';
        if (id.isEmpty || _seenNotifications.contains(id)) continue;
        _seenNotifications.add(id);
        await NotificationService.instance.show(
          id: id.hashCode,
          title: item['title']?.toString() ?? 'Academy update',
          body: item['message']?.toString() ?? '',
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final admin = context.watch<SessionProvider>().isAdmin;
    final pages = admin
        ? <Widget>[
            HomeScreen(refreshToken: _homeRefreshToken),
            const student_management.StudentDirectoryPage(),
            const attendance_admin.AdminAttendancePage(),
            const AdminMorePage()
          ]
        : <Widget>[
            HomeScreen(refreshToken: _homeRefreshToken),
            const TrainingPage(),
            const AttendancePage(),
            const ProfilePage()
          ];
    final labels = admin
        ? ['Dashboard', 'Students', 'Attendance', 'More']
        : ['Home', 'Training', 'Attendance', 'Profile'];
    final icons = admin
        ? [
            Icons.dashboard_outlined,
            Icons.groups_outlined,
            Icons.fact_check_outlined,
            Icons.grid_view_rounded
          ]
        : [
            Icons.home_outlined,
            Icons.fitness_center_outlined,
            Icons.calendar_month_outlined,
            Icons.person_outline
          ];
    return Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() {
                  index = i;
                  if (i == 0) _homeRefreshToken++;
                }),
            indicatorColor: AcademyColors.mint,
            destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(icons[i], color: AcademyColors.green),
                    label: labels[i]))));
  }
}
