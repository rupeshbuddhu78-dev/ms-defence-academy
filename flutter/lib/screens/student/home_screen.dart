import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';
import '../admin/admin_pages.dart';
import 'extras_pages.dart';
import 'student_pages.dart';

class HomeScreen extends StatefulWidget {
  final int refreshToken;
  const HomeScreen({super.key, this.refreshToken = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/dashboard');
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      future = context.read<SessionProvider>().api.get('/dashboard');
    }
  }

  void reload() => setState(() {
        future = context.read<SessionProvider>().api.get('/dashboard');
      });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final admin = session.isAdmin;
    return Scaffold(
      appBar: AppBar(
          title: Text(admin ? 'Admin Dashboard' : 'MS Defence Academy'),
          actions: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
          ]),
      body: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const LoadingState();
          if (snapshot.hasError)
            return ErrorState(
                message: snapshot.error.toString(), retry: reload);
          final data = Map<String, dynamic>.from(snapshot.data ?? {});
          return RefreshIndicator(
              onRefresh: () async {
                reload();
              },
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: admin ? _admin(data) : _student(data)));
        },
      ),
    );
  }

  List<Widget> _admin(Map<String, dynamic> data) {
    final stats = Map<String, dynamic>.from(data['stats'] ?? {});
    return [
      Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              color: AcademyColors.forest,
              borderRadius: BorderRadius.circular(24)),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DISCIPLINE • DEDICATION • SUCCESS',
                    style: TextStyle(color: Color(0xFFE4D190), fontSize: 11)),
                SizedBox(height: 10),
                Text('Good morning, Admin',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Your academy at a glance',
                    style: TextStyle(color: Colors.white70))
              ])),
      const SizedBox(height: 20),
      GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _stat('Total students', '${stats['totalStudents'] ?? 0}',
                Icons.groups_outlined),
            _stat('Present today', '${stats['todayPresent'] ?? 0}',
                Icons.how_to_reg),
            _stat('Active batches', '${stats['totalBatches'] ?? 0}',
                Icons.school_outlined),
            _stat("Today's classes", '${stats['todayClasses'] ?? 0}',
                Icons.fitness_center),
          ]),
      const SizedBox(height: 22),
      const _SectionTitle('Quick access'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _action('Scan Attendance', Icons.qr_code_scanner,
            () => _open(const ScannerPage())),
        _action('Create Test', Icons.quiz_outlined,
            () => _open(const TestManagementPage())),
        _action('Schedule Training', Icons.calendar_month,
            () => _open(const TrainingAdminPage())),
        _action('Batches & Courses', Icons.groups_2_outlined,
            () => _open(const BatchManagementPage())),
        _action('Notices', Icons.campaign_outlined,
            () => _open(const NoticesPage())),
        _action('Fees', Icons.account_balance_wallet_outlined,
            () => _open(const FeesPage())),
      ]),
    ];
  }

  List<Widget> _student(Map<String, dynamic> data) {
    final p = Map<String, dynamic>.from(data['profile'] ?? {});
    final u = Map<String, dynamic>.from(p['userId'] ?? {});
    final att = Map<String, dynamic>.from(data['attendance'] ?? {});
    final batch = p['batchId'] is Map ? (p['batchId']['name'] ?? '') : '';
    final notices = data['notices'] as List? ?? [];
    final trainings = data['trainings'] as List? ?? [];
    final tests = data['tests'] as List? ?? [];
    final photo = (p['photo'] ?? '').toString();
    final name = (u['name'] ?? 'Student').toString();
    return [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AcademyColors.forest,
              borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            CircleAvatar(
                radius: 29,
                backgroundColor: Colors.white,
                backgroundImage:
                    photo.startsWith('http') ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                            color: AcademyColors.green,
                            fontSize: 23,
                            fontWeight: FontWeight.bold))
                    : null),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Welcome back, $name',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  Text('${p['studentId'] ?? '—'}  •  $batch',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12))
                ]))
          ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: _stat('Attendance', '${att['percentage'] ?? 0}%',
                Icons.fact_check_outlined)),
        const SizedBox(width: 10),
        Expanded(
            child: _stat('Present', '${att['present'] ?? 0}',
                Icons.check_circle_outline))
      ]),
      const SizedBox(height: 22),
      const _SectionTitle('Quick actions'),
      GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.03,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _tile('My QR Code', Icons.qr_code_2, () => _open(const QrScreen())),
            _tile('Attendance', Icons.calendar_month,
                () => _open(const AttendancePage())),
            _tile('Tests', Icons.edit_note, () => _open(const TestsPage())),
            _tile('Training', Icons.fitness_center,
                () => _open(const TrainingPage())),
            _tile('Notices', Icons.campaign_outlined,
                () => _open(const NoticesPage())),
            _tile('Fees', Icons.account_balance_wallet_outlined,
                () => _open(const FeesPage())),
            _tile('Alerts', Icons.notifications_none,
                () => _open(const NotificationsPage())),
          ]),
      if (trainings.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _SectionTitle('Upcoming training'),
        ...trainings.take(2).map((x) => _infoCard(
            Icons.fitness_center,
            x['title'] ?? 'Training',
            '${x['date'] ?? ''}  •  ${x['startTime'] ?? ''}'))
      ],
      if (tests.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _SectionTitle('Available tests'),
        ...tests.take(2).map((x) => _infoCard(
            Icons.quiz_outlined,
            x['title'] ?? 'Test',
            '${x['duration'] ?? '—'} min  •  ${x['questionCount'] ?? 0} questions'))
      ],
      if (notices.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _SectionTitle('Latest notices'),
        ...notices.take(2).map((x) => _infoCard(Icons.campaign_outlined,
            x['title'] ?? 'Notice', x['description'] ?? ''))
      ],
    ];
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  Widget _stat(String label, String value, IconData icon) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AcademyColors.green),
            const SizedBox(height: 10),
            Text(value,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AcademyColors.muted))
          ])));
  Widget _tile(String label, IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Card(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AcademyColors.green, size: 25),
        const SizedBox(height: 9),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))
      ])));
  Widget _action(String label, IconData icon, VoidCallback onTap) => ActionChip(
      avatar: Icon(icon, size: 18, color: AcademyColors.green),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AcademyColors.line));
  Widget _infoCard(IconData icon, String title, String subtitle) => Card(
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: AcademyColors.mint,
              child: Icon(icon, color: AcademyColors.green)),
          title: Text(title),
          subtitle:
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis)));
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
}
