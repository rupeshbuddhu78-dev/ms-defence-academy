import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});
  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/training');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/training'));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Training Schedule'), actions: [
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
            final items = snapshot.data as List<dynamic>? ?? [];
            if (items.isEmpty)
              return const EmptyState(
                  title: 'No training scheduled',
                  subtitle:
                      'Your upcoming training sessions will appear here.');
            return ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map((item) {
                      final date = DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal();
                      final dateLabel = date == null ? 'Date not set' : DateFormat('EEE, dd MMM yyyy').format(date);
                      return Card(
                          child: ListTile(
                            isThreeLine: true,
                            leading: const CircleAvatar(
                                backgroundColor: AcademyColors.mint,
                                child: Icon(Icons.fitness_center,
                                    color: AcademyColors.green)),
                            title: Text(item['title'] ?? 'Training'),
                            subtitle: Text(
                                '${item['type'] ?? 'Physical Training'}\n$dateLabel • ${item['startTime'] ?? ''}–${item['endTime'] ?? ''}\n${item['location'] ?? ''}'),
                          ),
                        );
                    })
                    .toList());
          },
        ),
      );
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = _loadMonth(focusedDay);
  }

  Future<dynamic> _loadMonth(DateTime month) {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(days: 1));
    return context.read<SessionProvider>().api.get('/attendance', query: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    });
  }

  void reload() => setState(() => future = _loadMonth(focusedDay));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Attendance'), actions: [
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
            final records = (data['records'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final summary = Map<String, dynamic>.from(data['summary'] ?? {});
            final eventDays = <DateTime>{};
            for (final record in records) {
              final date = DateTime.tryParse(record['date']?.toString() ?? '');
              if (date != null)
                eventDays.add(DateTime(date.year, date.month, date.day));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TableCalendar<String>(
                      firstDay: DateTime.utc(2022, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, selectedDay),
                      eventLoader: (day) => eventDays
                              .contains(DateTime(day.year, day.month, day.day))
                          ? ['attendance']
                          : [],
                      calendarFormat: CalendarFormat.month,
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false, titleCentered: true),
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                            color: AcademyColors.mint, shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(
                            color: AcademyColors.green, shape: BoxShape.circle),
                        markerDecoration: BoxDecoration(
                            color: AcademyColors.orange,
                            shape: BoxShape.circle),
                      ),
                      onDaySelected: (selected, focused) => setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                      }),
                      onPageChanged: (focused) => setState(() {
                        focusedDay = focused;
                        future = _loadMonth(focused);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _summary(
                          'Total classes', '${summary['totalClasses'] ?? 0}')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _summary('Present', '${summary['present'] ?? 0}')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _summary(
                          'Attendance', '${summary['percentage'] ?? 0}%')),
                ]),
                const SizedBox(height: 18),
                Text('Records • ${DateFormat('MMMM yyyy').format(focusedDay)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (records.isEmpty)
                  const EmptyState(
                      title: 'No attendance records',
                      subtitle: 'Your marked classes appear here.')
                else
                  ...records.map((record) {
                    final date =
                        DateTime.tryParse(record['date']?.toString() ?? '') ??
                            DateTime.now();
                    final time =
                        DateTime.tryParse(record['time']?.toString() ?? '');
                    final entry = DateTime.tryParse(record['entryAt']?.toString() ?? '') ?? time;
                    final exit = DateTime.tryParse(record['exitAt']?.toString() ?? '');
                    final present = record['status'] == 'present';
                    return Card(
                        child: ListTile(
                      leading: Icon(present ? Icons.check_circle : Icons.cancel,
                          color:
                              present ? AcademyColors.green : Colors.redAccent),
                      title: Text(DateFormat('EEE, d MMM yyyy').format(date)),
                      subtitle: Text('${record['status'] ?? ''}\nEntry: ${entry == null ? '—' : DateFormat('h:mm a').format(entry.toLocal())}  •  Exit: ${exit == null ? '—' : DateFormat('h:mm a').format(exit.toLocal())}'),
                      isThreeLine: true,
                    ));
                  }),
              ],
            );
          },
        ),
      );

  Widget _summary(String title, String value) => Card(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
            child: Column(children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, color: AcademyColors.muted)),
            ])),
      );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<dynamic> future;
  bool _uploadingPhoto = false;
  double _photoUploadProgress = 0;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/students/profile');
  }

  void reload() => setState(() =>
      future = context.read<SessionProvider>().api.get('/students/profile'));

  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (picked == null) return;
    setState(() {
      _uploadingPhoto = true;
      _photoUploadProgress = 0;
    });
    try {
      await context.read<SessionProvider>().api.postMultipart(
        '/students/profile/photo',
        const {},
        file: File(picked.path),
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() => _photoUploadProgress =
              total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0).toDouble());
        },
      );
      if (mounted) {
        reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _photoUploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Profile'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () => context.read<SessionProvider>().logout(),
              icon: const Icon(Icons.logout)),
        ]),
        body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final profile = Map<String, dynamic>.from(snapshot.data ?? {});
            final user = Map<String, dynamic>.from(profile['userId'] ?? {});
            final batch = profile['batchId'] is Map
                ? profile['batchId'] as Map
                : <String, dynamic>{};
            final fees = profile['feeSummary'] is Map
                ? Map<String, dynamic>.from(profile['feeSummary'])
                : <String, dynamic>{};
            final photo = (profile['photo'] ?? '').toString();
            final joined = DateTime.tryParse('${profile['joiningDate'] ?? ''}');
            final dob = DateTime.tryParse('${profile['dateOfBirth'] ?? ''}');
            final addressParts = [
              profile['village'],
              profile['post'],
              profile['policeStation'],
              profile['district'],
              profile['state'],
              profile['postalCode'],
            ]
                .where(
                    (part) => part != null && part.toString().trim().isNotEmpty)
                .join(', ');
            final fullAddress = addressParts.isNotEmpty
                ? addressParts
                : (profile['address'] ?? 'Address not added').toString();
            return ListView(padding: const EdgeInsets.all(18), children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AcademyColors.mint,
                          backgroundImage: photo.startsWith('http')
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person,
                                  size: 44, color: AcademyColors.green)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(user['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('ID: ${profile['studentId'] ?? '—'}',
                            style: const TextStyle(color: AcademyColors.muted)),
                        Text(batch['name'] ?? '',
                            style: const TextStyle(color: AcademyColors.green)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _uploadingPhoto ? null : _uploadPhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(_uploadingPhoto
                              ? 'Uploading photo ${(100 * _photoUploadProgress).round()}%'
                              : 'Change profile photo'),
                        ),
                        if (_uploadingPhoto) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: _photoUploadProgress),
                        ],
                      ]))),
              const SizedBox(height: 12),
              _line(Icons.phone,
                  'Student phone: ${user['phone'] ?? 'Not added'}'),
              if ((user['email'] ?? '').toString().isNotEmpty &&
                  !(user['email']
                          ?.toString()
                          .endsWith('@students.msda.local') ??
                      false))
                _line(Icons.email_outlined, user['email'].toString()),
              if ((profile['fatherName'] ?? '').toString().isNotEmpty)
                _line(
                    Icons.family_restroom, 'Father: ${profile['fatherName']}'),
              if ((profile['motherName'] ?? '').toString().isNotEmpty)
                _line(
                    Icons.family_restroom, 'Mother: ${profile['motherName']}'),
              if ((profile['parentPhone'] ?? '').toString().isNotEmpty)
                _line(Icons.call_outlined,
                    'Parent phone: ${profile['parentPhone']}'),
              _line(Icons.cake_outlined,
                  'Date of birth: ${dob == null ? 'Not provided' : DateFormat('dd MMM yyyy').format(dob.toLocal())}'),
              _line(Icons.location_on_outlined, fullAddress),
              _line(Icons.height,
                  'Height: ${profile['heightCm'] == null ? 'Not provided' : '${profile['heightCm']} cm'}'),
              _line(Icons.monitor_weight_outlined,
                  'Weight: ${profile['weightKg'] == null ? 'Not provided' : '${profile['weightKg']} kg'}'),
              _line(Icons.straighten,
                  'Chest: ${profile['chestCm'] == null ? 'Not provided' : '${profile['chestCm']} cm'}'),
              if ((profile['aadhaarNumber'] ?? '').toString().isNotEmpty)
                _line(Icons.verified_user_outlined,
                    'Aadhaar: ${profile['aadhaarNumber']}'),
              _line(
                  Icons.school_outlined,
                  profile['course']?.toString().isNotEmpty == true
                      ? profile['course'].toString()
                      : 'Course not added'),
              _line(Icons.calendar_today,
                  'Joined ${joined == null ? '—' : DateFormat('dd MMM yyyy').format(joined.toLocal())}'),
              if ((fees['totalFees'] ?? 0) > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fee summary',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Total: ₹${fees['totalFees'] ?? 0}'),
                        Text('Paid: ₹${fees['paidAmount'] ?? 0}'),
                        Text('Remaining: ₹${fees['remainingAmount'] ?? 0}',
                            style: const TextStyle(
                                color: AcademyColors.green,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const QrScreen())),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('My QR Code')),
            ]);
          },
        ),
      );

  Widget _line(IconData icon, String text) => Card(
      child: ListTile(
          leading: Icon(icon, color: AcademyColors.green), title: Text(text)));
}

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/students/profile/qr');
  }

  void reload() => setState(() =>
      future = context.read<SessionProvider>().api.get('/students/profile/qr'));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My QR Code'), actions: [
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
              return Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                      radius: 34,
                                      backgroundColor: AcademyColors.mint,
                                      child: Icon(Icons.person,
                                          size: 38,
                                          color: AcademyColors.green)),
                                  const SizedBox(height: 12),
                                  Text(data['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text('ID: ${data['studentId'] ?? ''}'),
                                  Text('Batch: ${data['batch'] ?? ''}',
                                      style: const TextStyle(
                                          color: AcademyColors.muted)),
                                  const SizedBox(height: 16),
                                  QrImageView(
                                      data: data['token'] ?? '',
                                      size: 220,
                                      backgroundColor: Colors.white),
                                  const Text(
                                      'Show this secure code to mark attendance',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AcademyColors.muted)),
                                  const SizedBox(height: 12),
                                  const Chip(
                                      avatar: Icon(Icons.verified,
                                          color: AcademyColors.green),
                                      label: Text(
                                          'Personal details are not encoded in QR')),
                                ],
                              )))));
            }),
      );
}

class TestsPage extends StatefulWidget {
  const TestsPage({super.key});
  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  late Future<dynamic> future;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/tests');
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => reload());
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/tests'));

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Written Preparation'), actions: [
          IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ResultHistoryPage())),
              icon: const Icon(Icons.history)),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        body: FutureBuilder<dynamic>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingState();
              if (snapshot.hasError)
                return ErrorState(
                    message: snapshot.error.toString(), retry: reload);
              final tests = snapshot.data as List<dynamic>? ?? [];
              if (tests.isEmpty)
                return const EmptyState(
                    title: 'No tests available',
                    subtitle: 'Your upcoming tests will appear here.');
              return ListView(
                  padding: const EdgeInsets.all(16),
                  children: tests.map((test) {
                    final attempt = test['attempt'];
                    final submitted =
                        attempt is Map && attempt['status'] == 'submitted';
                    final starts =
                        DateTime.tryParse('${test['startTime'] ?? ''}');
                    final ends = DateTime.tryParse('${test['endTime'] ?? ''}');
                    final now = DateTime.now();
                    final scheduled = starts != null && now.isBefore(starts);
                    final closed = ends != null && now.isAfter(ends);
                    final inProgress =
                        attempt is Map && attempt['status'] == 'in_progress';
                    final canStart = test['canStart'] == true ||
                        (test['canStart'] == null &&
                            starts != null &&
                            !scheduled &&
                            !closed);
                    final startLabel = starts == null
                        ? 'Schedule not available'
                        : DateFormat('dd MMM yyyy, hh:mm a')
                            .format(starts.toLocal());
                    final endLabel = ends == null
                        ? 'Close time not available'
                        : DateFormat('dd MMM yyyy, hh:mm a')
                            .format(ends.toLocal());
                    return Card(
                        child: ListTile(
                      isThreeLine: true,
                      leading: const CircleAvatar(
                          backgroundColor: AcademyColors.mint,
                          child: Icon(Icons.quiz_outlined,
                              color: AcademyColors.green)),
                      title: Text(test['title'] ?? 'Test'),
                      subtitle: Text(
                          '${test['questionCount'] ?? 0} questions • ${test['duration'] ?? 0} min\nStarts: $startLabel\nEnds: $endLabel${(test['description'] ?? '').toString().isEmpty ? '' : '\n${test['description']}'}'),
                      trailing: FilledButton(
                        onPressed: submitted
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ResultHistoryPage()),
                                )
                            : !canStart
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ExamPage(
                                              test: Map<String, dynamic>.from(
                                                  test))),
                                    ).then((_) => reload()),
                        child: Text(submitted
                            ? 'Result'
                            : closed
                                ? 'Closed'
                                : scheduled
                                    ? 'Locked'
                                    : canStart
                                        ? (inProgress ? 'Resume' : 'Start')
                                        : 'Locked'),
                      ),
                    ));
                  }).toList());
            }),
      );
}

class ExamPage extends StatefulWidget {
  final Map<String, dynamic> test;
  const ExamPage({super.key, required this.test});
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> with WidgetsBindingObserver {
  final Map<String, int> answers = {};
  List<dynamic> questions = [];
  Timer? timer;
  Timer? draftTimer;
  bool started = false;
  bool sending = false;
  bool _savingDraft = false;
  bool _draftDirty = false;
  String? error;
  int seconds = 0;
  int index = 0;
  DateTime? deadlineAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && started) {
      draftTimer?.cancel();
      _saveDraft();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> start() async {
    setState(() => sending = true);
    try {
      final data = await context
          .read<SessionProvider>()
          .api
          .post('/tests/${widget.test['_id']}/start');
      questions = List<dynamic>.from(data['questions'] ?? []);
      final attempt = data['attempt'] is Map
          ? Map<String, dynamic>.from(data['attempt'])
          : <String, dynamic>{};
      for (final raw in attempt['answers'] as List<dynamic>? ?? []) {
        if (raw is! Map) continue;
        final questionId = raw['questionId'] is Map
            ? raw['questionId']['_id']?.toString()
            : raw['questionId']?.toString();
        final selected = int.tryParse('${raw['selected'] ?? ''}');
        if (questionId != null && selected != null) {
          answers[questionId] = selected;
        }
      }
      deadlineAt =
          DateTime.tryParse(data['deadlineAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now().add(Duration(
                  minutes: (widget.test['duration'] as num? ?? 30).toInt()));
      seconds = deadlineAt!
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 18000)
          .toInt();
      started = true;
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (seconds <= 1) {
          seconds = 0;
          timer.cancel();
          if (mounted) setState(() {});
          submit(auto: true);
        } else if (mounted) {
          setState(() => seconds--);
        }
      });
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  List<Map<String, dynamic>> _answerPayload() => answers.entries
      .map((entry) => {'questionId': entry.key, 'selected': entry.value})
      .toList();

  void _scheduleDraftSave() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (!started || !mounted) return;
    _draftDirty = true;
    if (_savingDraft) return;
    _savingDraft = true;
    try {
      while (_draftDirty && mounted) {
        _draftDirty = false;
        await context.read<SessionProvider>().api.patch(
            '/tests/${widget.test['_id']}/answers',
            {'answers': _answerPayload()});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Answer auto-save failed: $e')));
      }
    } finally {
      _savingDraft = false;
    }
  }

  Future<void> submit({bool auto = false}) async {
    if (sending) return;
    draftTimer?.cancel();
    setState(() => sending = true);
    timer?.cancel();
    try {
      final payload = _answerPayload();
      final result = await context
          .read<SessionProvider>()
          .api
          .post('/tests/${widget.test['_id']}/submit', {'answers': payload});
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Test submitted'),
                content: Text(
                    'Score: ${result['obtainedMarks']}/${result['totalMarks']}\nPercentage: ${result['percentage']}%${auto ? '\nTime is up — your answers were submitted.' : ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.popUntil(
                          dialogContext, (route) => route.isFirst),
                      child: const Text('Done'))
                ],
              ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.test['title'] ?? 'Test')),
        body: !started
            ? _intro()
            : questions.isEmpty
                ? const EmptyState(
                    title: 'No questions returned',
                    subtitle: 'Ask your instructor for help.')
                : _questionView(),
      );

  Widget _intro() => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.test['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                          '${widget.test['questionCount'] ?? 0} questions • ${widget.test['duration'] ?? 0} minutes'),
                      const SizedBox(height: 10),
                      Text(widget.test['instructions'] ??
                          'Choose one answer per question. The test submits automatically when time expires.'),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: sending ? null : start,
                          child: sending
                              ? const CircularProgressIndicator()
                              : const Text('Start Test')),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  )))));

  Widget _questionView() {
    final question = questions[index];
    final options = question['options'] as List<dynamic>? ?? [];
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Question ${index + 1} of ${questions.length}'),
        Chip(
            avatar: const Icon(Icons.timer_outlined),
            label: Text(
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}')),
      ]),
      LinearProgressIndicator(
          value: (index + 1) / questions.length, color: AcademyColors.green),
      const SizedBox(height: 22),
      Text(question['questionText'] ?? '',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      RadioGroup<int>(
        groupValue: answers[question['_id']],
        onChanged: (value) {
          if (value != null) {
            setState(() => answers[question['_id']] = value);
            _scheduleDraftSave();
          }
        },
        child: Column(
          children: List.generate(
            4,
            (optionIndex) => Card(
              child: RadioListTile<int>(
                value: optionIndex,
                title: Text(optionIndex < options.length
                    ? options[optionIndex].toString()
                    : ''),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        if (index > 0)
          OutlinedButton(
              onPressed: () => setState(() => index--),
              child: const Text('Previous')),
        const Spacer(),
        if (index < questions.length - 1)
          FilledButton(
              onPressed: () => setState(() => index++),
              child: const Text('Next'))
        else
          FilledButton(
              onPressed: sending ? null : () => submit(),
              child: Text(sending ? 'Submitting…' : 'Submit Test')),
      ]),
    ]);
  }
}

class ResultHistoryPage extends StatefulWidget {
  const ResultHistoryPage({super.key});
  @override
  State<ResultHistoryPage> createState() => _ResultHistoryPageState();
}

class _ResultHistoryPageState extends State<ResultHistoryPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/tests/results');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/tests/results'));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Test History'), actions: [
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
              final results = snapshot.data as List<dynamic>? ?? [];
              final profile = context.read<SessionProvider>().profile ?? {};
              final user = profile['userId'] is Map
                  ? Map<String, dynamic>.from(profile['userId'])
                  : <String, dynamic>{};
              final batch = profile['batchId'] is Map
                  ? profile['batchId']['name']?.toString() ?? ''
                  : '';
              final photo = profile['photo']?.toString() ?? '';
              return ListView(padding: const EdgeInsets.all(14), children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AcademyColors.mint,
                      backgroundImage:
                          photo.startsWith('http') ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? const Icon(Icons.person_outline,
                              color: AcademyColors.green)
                          : null,
                    ),
                    title: Text(user['name']?.toString() ?? 'Student'),
                    subtitle: Text(
                        'Student ID: ${profile['studentId'] ?? '—'} • ${batch.isEmpty ? 'No batch' : batch}'),
                  ),
                ),
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: EmptyState(
                        title: 'No test results yet',
                        subtitle:
                            'Submitted and timed-out test results will appear here.'),
                  ),
                ...results.map((result) {
                  final test = result['testId'];
                  final submittedAt = DateTime.tryParse(
                      result['submittedAt']?.toString() ?? '');
                  return Card(
                      child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: AcademyColors.mint,
                        child: Icon(Icons.emoji_events_outlined,
                            color: AcademyColors.green)),
                    title: Text(test is Map ? test['title'] ?? 'Test' : 'Test'),
                    subtitle: Text(
                        '${test is Map && test['batchId'] is Map ? '${test['batchId']['name']} • ' : ''}${submittedAt == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(submittedAt.toLocal())} • ${result['attempted'] ?? 0} attempted${result['autoSubmitted'] == true ? ' • Auto-submitted' : ''}'),
                    trailing: Text(
                        '${result['obtainedMarks'] ?? 0}/${result['totalMarks'] ?? 0}\n${result['percentage'] ?? 0}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AcademyColors.green)),
                  ));
                }),
              ]);
            }),
      );
}
