import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';
import '../admin/admin_pages.dart';
import '../admin/attendance_admin_page.dart' as attendance_admin;
import '../admin/student_management_page.dart' as student_management;
import '../admin/student_approvals_page.dart';
import 'extras_pages.dart';
import 'student_pages.dart';
import 'physical_training_results_page.dart';
import '../admin/physical_training_admin_page.dart';
import '../shared/content_pages.dart';

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
    if (widget.refreshToken != oldWidget.refreshToken) reload();
  }

  void reload() => setState(() {
        future = context.read<SessionProvider>().api.get('/dashboard');
      });
  String _trainingDateTime(dynamic item) {
    final date = DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal();
    final dateLabel =
        date == null ? 'Date not set' : DateFormat('dd MMM yyyy').format(date);
    return '$dateLabel  •  ${item['startTime'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final admin = session.isAdmin;
    return Scaffold(
      backgroundColor: AcademyColors.surface,
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
            color: AcademyColors.green,
            onRefresh: () async => reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _Header(
                  admin: admin,
                  onRefresh: reload,
                  studentName: session.user?['name']?.toString() ?? '',
                  studentPhoto: session.profile?['photo']?.toString() ?? '',
                  appName: session.settings['name']?.toString() ??
                      'MS Defence Academy',
                  logoUrl: session.settings['logoUrl']?.toString() ?? '',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: Column(
                    children: admin ? _admin(data) : _student(data),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _admin(Map<String, dynamic> data) {
    final stats = Map<String, dynamic>.from(data['stats'] ?? {});
    return [
      _HeroCard(
          eyebrow: 'DISCIPLINE  •  DEDICATION  •  SUCCESS',
          title: _greeting(),
          highlight: 'Admin',
          subtitle: 'Your academy at a glance',
          backgroundUrl: context
                  .read<SessionProvider>()
                  .settings['backgroundUrl']
                  ?.toString() ??
              ''),
      const SizedBox(height: 22),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.28,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _StatCard(
              'Total Students',
              '${stats['totalStudents'] ?? 0}',
              Icons.groups_rounded,
              AcademyColors.green,
              () => _open(const student_management.StudentDirectoryPage())),
          _StatCard(
              'Present Today',
              '${stats['todayPresent'] ?? 0}',
              Icons.person_add_alt_1_rounded,
              const Color(0xFF1688C7),
              () => _open(const attendance_admin.AdminAttendancePage())),
          _StatCard(
              'Active Batches',
              '${stats['totalBatches'] ?? 0}',
              Icons.school_rounded,
              const Color(0xFFB68A08),
              () => _open(const BatchManagementPage())),
          _StatCard(
              "Today's Classes",
              '${stats['todayClasses'] ?? 0}',
              Icons.calendar_month_rounded,
              const Color(0xFF15558A),
              () => _open(const TrainingAdminPage())),
        ],
      ),
      const SizedBox(height: 26),
      const _SectionHeading('Quick Access'),
      const SizedBox(height: 12),
      _WideAction(
          'Scan Attendance',
          'Mark student attendance quickly',
          Icons.qr_code_scanner_rounded,
          AcademyColors.green,
          () => _open(const ScannerPage())),
      const SizedBox(height: 10),
      _WideAction(
          'Create Test',
          'Build and manage tests',
          Icons.description_outlined,
          const Color(0xFFB68A08),
          () => _open(const TestManagementPage())),
      const SizedBox(height: 10),
      _WideAction(
          'Test Results',
          'View submitted results batch by batch',
          Icons.assessment_outlined,
          const Color(0xFF1688C7),
          () => _open(const AdminResultsPage())),
      const SizedBox(height: 10),
      _WideAction(
          'Physical Training Results',
          'Record and review student physical assessments',
          Icons.fitness_center,
          const Color(0xFF15934F),
          () => _open(const PhysicalTrainingAdminPage())),
      const SizedBox(height: 10),
      _WideAction(
          'Schedule Training',
          'Plan and manage training sessions',
          Icons.calendar_month_rounded,
          const Color(0xFF15558A),
          () => _open(const TrainingAdminPage())),
      const SizedBox(height: 10),
      _WideAction(
          'Student Approvals',
          'Review verified account requests',
          Icons.how_to_reg_outlined,
          const Color(0xFFB68A08),
          () => _open(const StudentApprovalsPage())),
    ];
  }

  List<Widget> _student(Map<String, dynamic> data) {
    final p = Map<String, dynamic>.from(data['profile'] ?? {});
    final u = Map<String, dynamic>.from(p['userId'] ?? {});
    final att = Map<String, dynamic>.from(data['attendance'] ?? {});
    final batch = p['batchId'] is Map ? (p['batchId']['name'] ?? '') : '';
    final notices = data['notices'] as List? ?? [],
        trainings = data['trainings'] as List? ?? [],
        tests = data['tests'] as List? ?? [];
    final photo = (p['photo'] ?? '').toString(),
        name = (u['name'] ?? 'Student').toString();
    return [
      _HeroCard(
          eyebrow: 'DISCIPLINE  •  DEDICATION  •  SUCCESS',
          title: _greeting(),
          highlight: name,
          subtitle: '${p['studentId'] ?? '—'}  •  $batch',
          photo: photo,
          backgroundUrl: context
                  .read<SessionProvider>()
                  .settings['backgroundUrl']
                  ?.toString() ??
              ''),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(
            child: _StatCard(
                'Attendance',
                '${att['percentage'] ?? 0}%',
                Icons.groups_rounded,
                const Color(0xFF15934F),
                () => _open(const AttendancePage()))),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard(
                'Present',
                '${att['present'] ?? 0}',
                Icons.check_circle_rounded,
                const Color(0xFF1688C7),
                () => _open(const AttendancePage())))
      ]),
      const SizedBox(height: 26),
      const _SectionHeading('Quick actions', lightning: true),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: .92,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          _ActionTile('My QR Code', Icons.qr_code_2_rounded,
              () => _open(const QrScreen())),
          _ActionTile('Attendance', Icons.calendar_month_rounded,
              () => _open(const AttendancePage())),
          _ActionTile(
              'Tests', Icons.edit_note_rounded, () => _open(const TestsPage())),
          _ActionTile('Physical results', Icons.fitness_center_rounded,
              () => _open(const PhysicalTrainingResultsPage())),
          _ActionTile('Training', Icons.fitness_center_rounded,
              () => _open(const TrainingPage())),
          _ActionTile('Notices', Icons.campaign_rounded,
              () => _open(const NoticesPage())),
          _ActionTile('Fees', Icons.account_balance_wallet_rounded,
              () => _open(const FeesPage())),
          _ActionTile('Alerts', Icons.notifications_rounded,
              () => _open(const NotificationsPage()),
              gold: true),
          _ActionTile('Files', Icons.folder_copy_outlined,
              () => _open(const StudentMediaPage(kind: 'file'))),
          _ActionTile('Videos', Icons.video_library_outlined,
              () => _open(const StudentMediaPage(kind: 'video'))),
        ],
      ),
      if (trainings.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _SectionHeading('Upcoming training'),
        ...trainings.take(2).map((x) => _InfoCard(Icons.fitness_center,
            x['title'] ?? 'Training', _trainingDateTime(x)))
      ],
      if (tests.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _SectionHeading('Available tests'),
        ...tests.take(2).map((x) => _InfoCard(
            Icons.quiz_outlined,
            x['title'] ?? 'Test',
            '${x['duration'] ?? '—'} min  •  ${x['questionCount'] ?? 0} questions'))
      ],
      if (notices.isNotEmpty) ...[
        const SizedBox(height: 22),
        const _SectionHeading('Latest notices'),
        ...notices.take(2).map((x) => _InfoCard(Icons.campaign_outlined,
            x['title'] ?? 'Notice', x['description'] ?? ''))
      ],
    ];
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';
  }
}

class _Header extends StatelessWidget {
  final bool admin;
  final VoidCallback onRefresh;
  final String studentName, studentPhoto, appName, logoUrl;
  const _Header(
      {required this.admin,
      required this.onRefresh,
      this.studentName = '',
      this.studentPhoto = '',
      this.appName = 'MS Defence Academy',
      this.logoUrl = ''});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 16),
        decoration: const BoxDecoration(
            color: AcademyColors.forest,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
        child: SafeArea(
            bottom: false,
            child: Row(children: [
              logoUrl.startsWith('http')
                  ? Image.network(logoUrl,
                      width: 48, height: 48, fit: BoxFit.contain)
                  : Image.asset('assets/academy_app_icon.png',
                      width: 48, height: 48),
              Container(
                  width: 1,
                  height: 42,
                  color: Colors.white30,
                  margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(appName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('DISCIPLINE  •  DEDICATION  •  SUCCESS',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                            color: Color(0xFFE4D190),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .5)),
                  ])),
              if (admin)
                const CircleAvatar(
                    radius: 19,
                    backgroundColor: Color(0xFFE4D190),
                    child: Icon(Icons.person, color: AcademyColors.forest))
              else
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AcademyColors.mint,
                  backgroundImage: studentPhoto.startsWith('http')
                      ? NetworkImage(studentPhoto)
                      : null,
                  child: studentPhoto.startsWith('http')
                      ? null
                      : Text(
                          studentName.isNotEmpty
                              ? studentName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                              color: AcademyColors.green,
                              fontWeight: FontWeight.bold)),
                ),
              IconButton(
                  onPressed: () {},
                  color: Colors.white,
                  icon: const Icon(Icons.notifications_none_rounded)),
              IconButton(
                  onPressed: onRefresh,
                  color: Colors.white,
                  icon: const Icon(Icons.refresh_rounded)),
            ])),
      );
}

class _HeroCard extends StatelessWidget {
  final String eyebrow, title, highlight, subtitle, photo, backgroundUrl;
  const _HeroCard(
      {required this.eyebrow,
      required this.title,
      required this.highlight,
      required this.subtitle,
      this.photo = '',
      this.backgroundUrl = ''});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
            height: 198,
            child: Stack(fit: StackFit.expand, children: [
              backgroundUrl.startsWith('http')
                  ? Image.network(backgroundUrl, fit: BoxFit.cover)
                  : Image.asset('assets/academy_hero_mobile.jpg',
                      fit: BoxFit.cover),
              Container(color: AcademyColors.forest.withValues(alpha: .68)),
              Positioned(
                  right: -28,
                  bottom: -34,
                  child: Transform.rotate(
                      angle: -.65,
                      child: Container(
                          width: 130,
                          height: 18,
                          color: const Color(0xFFE4D190)))),
              Positioned(
                  right: -12,
                  bottom: -16,
                  child: Transform.rotate(
                      angle: -.65,
                      child: Container(
                          width: 120, height: 8, color: AcademyColors.green))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
                  child: Row(children: [
                    if (photo.isNotEmpty) ...[
                      CircleAvatar(
                        radius: 33,
                        backgroundColor: Colors.white,
                        backgroundImage: photo.startsWith('http')
                            ? NetworkImage(photo)
                            : null,
                        child: photo.startsWith('http')
                            ? null
                            : Text(
                                highlight.isNotEmpty
                                    ? highlight[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                    color: AcademyColors.green,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(eyebrow,
                              style: const TextStyle(
                                  color: Color(0xFFE4D190),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          SizedBox(
                              height: 31,
                              child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700)))),
                          SizedBox(
                              height: 36,
                              child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(highlight,
                                      style: const TextStyle(
                                          color: Color(0xFFF0D36F),
                                          fontSize: 27,
                                          fontWeight: FontWeight.w800)))),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ])),
                  ])),
            ])),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  const _StatCard(this.label, this.value, this.icon, this.accent, [this.onTap]);
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AcademyColors.line),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ]),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Stack(children: [
            Positioned(
                bottom: -2,
                left: 0,
                right: 0,
                child:
                    Container(height: 8, color: accent.withValues(alpha: .85))),
            Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 20,
                          backgroundColor: accent,
                          child: Icon(icon, color: Colors.white, size: 23)),
                      const Spacer(),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 29,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: AcademyColors.ink)),
                      const SizedBox(height: 5),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AcademyColors.muted)),
                    ])),
            const Positioned(
                right: 10,
                bottom: 18,
                child: Icon(Icons.chevron_right_rounded,
                    color: AcademyColors.muted, size: 23)),
          ]),
        ),
      );
}

class _WideAction extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _WideAction(
      this.title, this.subtitle, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AcademyColors.line),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 7,
                    offset: Offset(0, 3))
              ]),
          child: Row(children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: Colors.white, size: 28)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AcademyColors.muted))
                ])),
            const Icon(Icons.chevron_right_rounded,
                size: 28, color: AcademyColors.ink),
          ]),
        ),
      ));
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool gold;
  const _ActionTile(this.label, this.icon, this.onTap, {this.gold = false});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 8, 9),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AcademyColors.line),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0B000000),
                    blurRadius: 7,
                    offset: Offset(0, 3))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                      color:
                          gold ? const Color(0xFFFFF1C6) : AcademyColors.mint,
                      shape: BoxShape.circle),
                  child: Icon(icon,
                      color:
                          gold ? const Color(0xFF9B7700) : AcademyColors.green,
                      size: 22)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 21, color: AcademyColors.muted)
            ]),
            const Spacer(),
            SizedBox(
              height: 34,
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ));
}

class _SectionHeading extends StatelessWidget {
  final String text;
  final bool lightning;
  const _SectionHeading(this.text, {this.lightning = false});
  @override
  Widget build(BuildContext context) => Row(children: [
        if (lightning) ...[
          const Icon(Icons.bolt_rounded, color: AcademyColors.green, size: 28),
          const SizedBox(width: 4)
        ],
        Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AcademyColors.line)),
        if (lightning) ...[
          const SizedBox(width: 8),
          Container(width: 38, height: 8, color: AcademyColors.green)
        ],
      ]);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _InfoCard(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(top: 10),
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: AcademyColors.mint,
              child: Icon(icon, color: AcademyColors.green)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle:
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis)));
}
