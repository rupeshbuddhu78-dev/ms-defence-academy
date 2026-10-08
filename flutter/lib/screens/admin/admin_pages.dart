import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';
import '../student/extras_pages.dart';
import 'admin_account_page.dart';
import 'security_logs_page.dart';
import '../shared/content_pages.dart';
import 'student_approvals_page.dart';
import 'physical_training_admin_page.dart';
import 'physical_training_sheets_admin_page.dart';

class _BulkQuestionDraft {
  final question = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  final marks = TextEditingController(text: '1');
  int correctAnswer = 0;

  void dispose() {
    question.dispose();
    marks.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool busy = false;
  String? error;
  String? token;
  Map<String, dynamic>? student;
  Map<String, dynamic>? currentAttendance;
  bool attendanceMarked = false;

  String _localDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get _inside => currentAttendance?['state'] == 'inside';

  String _entryExitSummary() {
    if (currentAttendance == null) return 'No entry recorded today';
    final entry =
        DateTime.tryParse(currentAttendance!['entryAt']?.toString() ?? '')
            ?.toLocal();
    final exit =
        DateTime.tryParse(currentAttendance!['exitAt']?.toString() ?? '')
            ?.toLocal();
    String fmt(DateTime? value) =>
        value == null ? '—' : DateFormat('hh:mm a').format(value);
    return 'Entry: ${fmt(entry)}   •   Exit: ${fmt(exit)}';
  }

  String _scanDetails() {
    final profile = student ?? const <String, dynamic>{};
    final lines = <String>[];
    final phone = profile['phone']?.toString() ?? '';
    final course = profile['course']?.toString() ?? '';
    if (phone.isNotEmpty) lines.add('Phone: $phone');
    if (course.isNotEmpty) lines.add('Course: $course');
    final measurements = <String>[
      if (profile['heightCm'] != null) 'Height ${profile['heightCm']} cm',
      if (profile['weightKg'] != null) 'Weight ${profile['weightKg']} kg',
      if (profile['chestCm'] != null) 'Chest ${profile['chestCm']} cm',
    ];
    if (measurements.isNotEmpty) lines.add(measurements.join(' • '));
    final dob = DateTime.tryParse(profile['dateOfBirth']?.toString() ?? '');
    if (dob != null) {
      lines.add('DOB: ${DateFormat('dd MMM yyyy').format(dob.toLocal())}');
    }
    final joined = DateTime.tryParse(profile['joiningDate']?.toString() ?? '');
    if (joined != null) {
      lines
          .add('Joined: ${DateFormat('dd MMM yyyy').format(joined.toLocal())}');
    }
    return lines.isEmpty ? 'No additional profile details' : lines.join('\n');
  }

  Future<void> _scan(String value) async {
    if (busy || student != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await context.read<SessionProvider>().api.post(
          '/attendance/lookup-qr',
          {'token': value, 'attendanceDate': _localDate()});
      if (!mounted) return;
      setState(() {
        token = value;
        student = Map<String, dynamic>.from(result['profile']);
        currentAttendance = result['currentAttendance'] == null
            ? null
            : Map<String, dynamic>.from(result['currentAttendance']);
      });
      await controller.stop();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _markAttendance() async {
    final scannedToken = token;
    if (scannedToken == null || (attendanceMarked && !_inside)) return;
    final now = DateTime.now();
    final localDate = _localDate();
    setState(() => busy = true);
    try {
      final result =
          await context.read<SessionProvider>().api.post('/attendance/mark', {
        'token': scannedToken,
        'status': 'present',
        'action': _inside ? 'exit' : 'entry',
        'attendanceDate': localDate,
        'markedAt': now.toUtc().toIso8601String(),
      });
      if (mounted) {
        final record = Map<String, dynamic>.from(result['attendance'] ?? {});
        setState(() {
          attendanceMarked = true;
          currentAttendance = {
            'entryAt': record['entryAt'] ?? record['time'],
            'exitAt': record['exitAt'],
            'state': result['action'] == 'exit' ? 'exited' : 'inside',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['action'] == 'exit'
                ? 'Exit recorded for ${student?['name'] ?? 'student'}'
                : result['action'] == 'already_inside'
                    ? '${student?['name'] ?? 'Student'} is already inside'
                    : 'Entry recorded for ${student?['name'] ?? 'student'}')));
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Attendance')),
        body: Column(children: [
          Expanded(
              flex: student == null ? 4 : 2,
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (capture.barcodes.isNotEmpty) {
                        final value = capture.barcodes.first.rawValue;
                        if (value != null) _scan(value);
                      }
                    }),
                Center(
                    child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: AcademyColors.green, width: 3),
                            borderRadius: BorderRadius.circular(26)))),
                Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: Text(
                        student == null
                            ? 'Scan student QR code'
                            : 'Student details verified',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
              ])),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Text(error!, style: const TextStyle(color: Colors.red))),
          if (student != null)
            Expanded(
                flex: 5,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: AcademyColors.mint,
                                  backgroundImage: (student!['photo'] ?? '')
                                          .toString()
                                          .startsWith('http')
                                      ? NetworkImage(
                                          student!['photo'].toString())
                                      : null,
                                  child: (student!['photo'] ?? '')
                                          .toString()
                                          .isEmpty
                                      ? const Icon(Icons.person,
                                          color: AcademyColors.green)
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Text(student!['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                Text(
                                    'ID: ${student!['studentId'] ?? '—'} • ${student!['batch'] ?? 'No batch'}'),
                                const SizedBox(height: 6),
                                Text(_scanDetails(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AcademyColors.muted)),
                                const SizedBox(height: 8),
                                Text(_entryExitSummary(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AcademyColors.green)),
                                const Spacer(),
                                if (attendanceMarked && !_inside)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AcademyColors.mint,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: AcademyColors.green),
                                        SizedBox(width: 8),
                                        Text('Entry and exit record saved',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AcademyColors.green)),
                                      ],
                                    ),
                                  )
                                else
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                          onPressed:
                                              busy ? null : _markAttendance,
                                          icon: Icon(_inside
                                              ? Icons.logout
                                              : Icons.login),
                                          label: Text(busy
                                              ? 'Saving…'
                                              : _inside
                                                  ? 'Mark exit'
                                                  : 'Mark entry'))),
                                TextButton(
                                    onPressed: () async {
                                      setState(() {
                                        student = null;
                                        token = null;
                                        currentAttendance = null;
                                        error = null;
                                        attendanceMarked = false;
                                      });
                                      await controller.start();
                                    },
                                    child: const Text('Scan another student')),
                              ],
                            ))))),
        ]),
      );
}

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});
  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/attendance');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/attendance'));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attendance Report'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScannerPage()))
              .then((_) => reload()),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'),
        ),
        body: FutureBuilder<dynamic>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingState();
              if (snapshot.hasError)
                return ErrorState(
                    message: snapshot.error.toString(), retry: reload);
              final data = Map<String, dynamic>.from(snapshot.data ?? {});
              final records = data['records'] as List<dynamic>? ?? [];
              if (records.isEmpty)
                return const EmptyState(
                    title: 'No attendance records',
                    subtitle: 'Use Scan to mark a student present.');
              return ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Attendance records: ${records.length}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)))),
                ...records.map((record) => Card(
                        child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                          record['studentId']?['userId']?['name'] ?? 'Student'),
                      subtitle: Text(
                          '${record['batchId']?['name'] ?? ''} • ${record['date'] ?? ''}'),
                      trailing: Text(
                          (record['status'] ?? '').toString().toUpperCase(),
                          style: const TextStyle(
                              color: AcademyColors.green,
                              fontWeight: FontWeight.bold)),
                    ))),
              ]);
            }),
      );
}

class StudentDirectoryPage extends StatefulWidget {
  const StudentDirectoryPage({super.key});
  @override
  State<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends State<StudentDirectoryPage> {
  final TextEditingController search = TextEditingController();
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() => context
      .read<SessionProvider>()
      .api
      .get('/students', query: search.text.isEmpty ? null : {'q': search.text});
  void reload() => setState(() => future = _load());
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    final random = Random.secure();
    return List.generate(14, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }

  Future<void> _createStudent() async {
    final api = context.read<SessionProvider>().api;
    List<dynamic> batches;
    try {
      batches = await api.get('/batches') as List<dynamic>;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    final activeBatches = batches
        .where((batch) => batch is Map && batch['status'] == 'active')
        .toList();
    if (activeBatches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Create an active batch before adding students.')));
      }
      return;
    }

    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final studentId = TextEditingController();
    final password = TextEditingController(text: _generateTempPassword());
    final course = TextEditingController();
    final address = TextEditingController();
    final totalFees = TextEditingController(text: '0');
    final paidAmount = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    String? selectedBatchId = activeBatches.first['_id']?.toString();
    DateTime joiningDate = DateTime.now();
    File? photo;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add student'),
          content: Form(
            key: form,
            child: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundImage: photo == null ? null : FileImage(photo!),
                    backgroundColor: AcademyColors.mint,
                    child: photo == null
                        ? const Icon(Icons.person,
                            size: 38, color: AcademyColors.green)
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 82,
                        maxWidth: 1280,
                        maxHeight: 1280,
                      );
                      if (picked != null)
                        update(() => photo = File(picked.path));
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(photo == null
                        ? 'Choose photo (optional)'
                        : 'Change photo'),
                  ),
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name *'),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                            ? 'Enter the student name'
                            : null,
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Phone number *'),
                    validator: (value) => value == null ||
                            value.replaceAll(RegExp(r'\\D'), '').length < 7
                        ? 'Enter a valid phone number'
                        : null,
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Login email *'),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: studentId,
                    decoration: const InputDecoration(
                        labelText: 'Student ID (leave blank to auto-generate)'),
                  ),
                  TextFormField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: 'Initial password *',
                      suffixIcon: IconButton(
                        tooltip: 'Generate a new password',
                        onPressed: () => update(
                            () => password.text = _generateTempPassword()),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 10
                        ? 'Use at least 10 characters'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBatchId,
                    decoration:
                        const InputDecoration(labelText: 'Assign batch *'),
                    items: activeBatches
                        .map((batch) => DropdownMenuItem<String>(
                              value: batch['_id'].toString(),
                              child: Text(batch['name']?.toString() ?? 'Batch'),
                            ))
                        .toList(),
                    onChanged: (value) => update(() => selectedBatchId = value),
                    validator: (value) =>
                        value == null ? 'Select a batch' : null,
                  ),
                  TextFormField(
                    controller: course,
                    decoration:
                        const InputDecoration(labelText: 'Course (optional)'),
                  ),
                  TextFormField(
                    controller: address,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Address (optional)'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final chosen = await showDatePicker(
                          context: dialogContext,
                          initialDate: joiningDate,
                          firstDate: DateTime(1980),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (chosen != null) update(() => joiningDate = chosen);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                          'Joining date: ${DateFormat('dd MMM yyyy').format(joiningDate)}'),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                      controller: totalFees,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Total fee (₹)'),
                      validator: (value) => num.tryParse(value ?? '') == null ||
                              num.parse(value!) < 0
                          ? 'Enter a valid amount'
                          : null,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                      controller: paidAmount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Paid now (₹)'),
                      validator: (value) {
                        final paid = num.tryParse(value ?? '');
                        final total = num.tryParse(totalFees.text);
                        if (paid == null || paid < 0)
                          return 'Enter a valid amount';
                        if (total != null && paid > total)
                          return 'Cannot exceed total';
                        return null;
                      },
                    )),
                  ]),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'phone': phone.text.trim(),
                  'studentId': studentId.text.trim(),
                  'password': password.text,
                  'batchId': selectedBatchId,
                  'course': course.text.trim(),
                  'address': address.text.trim(),
                  'joiningDate': joiningDate,
                  'totalFees': totalFees.text,
                  'paidAmount': paidAmount.text,
                  'photo': photo,
                });
              },
              child: const Text('Create student'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;
    try {
      final fields = <String, String>{
        'name': values['name'],
        'email': values['email'],
        'phone': values['phone'],
        'studentId': values['studentId'],
        'password': values['password'],
        'batchId': values['batchId'],
        'course': values['course'],
        'address': values['address'],
        'joiningDate':
            (values['joiningDate'] as DateTime).toUtc().toIso8601String(),
        'totalFees': values['totalFees'],
        'paidAmount': values['paidAmount'],
      };
      final result = await api.postMultipart(
        '/students',
        fields,
        file: values['photo'] as File?,
      );
      reload();
      dynamic generatedId;
      if (result is Map && result['credentials'] is Map) {
        generatedId = (result['credentials'] as Map)['studentId'];
      }
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Student account created'),
            content: SelectableText(
              'Student ID: ${generatedId ?? values['studentId']}\n'
              'Login email: ${values['email']}\n'
              'Initial password: ${values['password']}\n\n'
              'Share these login details with the student securely.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'))
            ],
          ),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Students'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: FloatingActionButton(
            onPressed: _createStudent,
            child: const Icon(Icons.person_add_alt_1)),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: search,
                decoration: InputDecoration(
                    hintText: 'Search students',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        onPressed: reload,
                        icon: const Icon(Icons.arrow_forward))),
                onSubmitted: (_) => reload(),
              )),
          Expanded(
              child: FutureBuilder<dynamic>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return const LoadingState();
                    if (snapshot.hasError)
                      return ErrorState(
                          message: snapshot.error.toString(), retry: reload);
                    final students = snapshot.data as List<dynamic>? ?? [];
                    if (students.isEmpty)
                      return const EmptyState(
                          title: 'No students found',
                          subtitle: 'Add a student or change the search.');
                    return ListView(
                        children: students.map((profile) {
                      final photo = (profile['photo'] ?? '').toString();
                      final user = profile['userId'] is Map
                          ? Map<String, dynamic>.from(profile['userId'])
                          : <String, dynamic>{};
                      final fees = profile['feeSummary'] is Map
                          ? Map<String, dynamic>.from(profile['feeSummary'])
                          : <String, dynamic>{};
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photo.startsWith('http')
                                ? NetworkImage(photo)
                                : null,
                            child:
                                photo.isEmpty ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${profile['studentId'] ?? ''} • ${profile['batchId']?['name'] ?? 'No batch'}\n'
                            '${user['phone'] ?? ''} • Fee due: ₹${fees['remainingAmount'] ?? 0}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    }).toList());
                  })),
        ]),
      );
}

class AdminMorePage extends StatelessWidget {
  const AdminMorePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Academy Management')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _link(context, 'Batches & courses', Icons.groups_2_outlined,
              const BatchManagementPage()),
          _link(context, 'Tests & questions', Icons.quiz_outlined,
              const TestManagementPage()),
          _link(context, 'Batch physical marks sheets', Icons.table_chart,
              const PhysicalTrainingSheetsAdminPage()),
          _link(context, 'Individual physical records', Icons.fitness_center,
              const PhysicalTrainingAdminPage()),
          _link(context, 'Training schedule', Icons.fitness_center,
              const TrainingAdminPage()),
          _link(
              context, 'Notices', Icons.campaign_outlined, const NoticesPage()),
          _link(context, 'Notifications', Icons.notifications_outlined,
              const NotificationsPage()),
          _link(context, 'Fees management',
              Icons.account_balance_wallet_outlined, const FeesPage()),
          _link(context, 'Admin account', Icons.admin_panel_settings_outlined,
              const AdminAccountPage()),
          _link(context, 'Security logs', Icons.security_outlined,
              const SecurityLogsPage()),
          _link(context, 'Branding, files & videos',
              Icons.cloud_upload_outlined, const AdminContentPage()),
          _link(context, 'Student approvals', Icons.how_to_reg_outlined,
              const StudentApprovalsPage()),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.logout, color: AcademyColors.green),
                  title: const Text('Sign out'),
                  onTap: () => context.read<SessionProvider>().logout())),
        ]),
      );
  Widget _link(
          BuildContext context, String title, IconData icon, Widget page) =>
      Card(
          child: ListTile(
        leading: Icon(icon, color: AcademyColors.green),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ));
}

class BatchManagementPage extends StatefulWidget {
  const BatchManagementPage({super.key});
  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/batches');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/batches'));

  Future<void> _saveBatch([Map<String, dynamic>? initial]) async {
    final editing = initial != null;
    final name =
        TextEditingController(text: initial?['name']?.toString() ?? '');
    final course =
        TextEditingController(text: initial?['course']?.toString() ?? '');
    final trainer =
        TextEditingController(text: initial?['trainer']?.toString() ?? '');
    final location =
        TextEditingController(text: initial?['location']?.toString() ?? '');
    final startTime = TextEditingController(
        text: initial?['startTime']?.toString() ?? '06:00');
    final endTime =
        TextEditingController(text: initial?['endTime']?.toString() ?? '08:00');
    final form = GlobalKey<FormState>();
    var status = initial?['status']?.toString() ?? 'active';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title:
              Text(editing ? 'Edit batch & course' : 'Create batch & course'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Batch name *'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Enter a batch name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: course,
                    decoration: const InputDecoration(labelText: 'Course')),
                const SizedBox(height: 12),
                TextField(
                    controller: trainer,
                    decoration: const InputDecoration(labelText: 'Trainer')),
                const SizedBox(height: 12),
                TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: startTime,
                          decoration: const InputDecoration(
                              labelText: 'Start (HH:mm)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: endTime,
                          decoration:
                              const InputDecoration(labelText: 'End (HH:mm)'))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive / archived')),
                  ],
                  onChanged: (value) => update(() => status = value ?? status),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'course': course.text.trim(),
                  'trainer': trainer.text.trim(),
                  'location': location.text.trim(),
                  'startTime': startTime.text.trim(),
                  'endTime': endTime.text.trim(),
                  'status': status,
                });
              },
              child: Text(editing ? 'Save changes' : 'Save batch'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      name,
      course,
      trainer,
      location,
      startTime,
      endTime
    ]) {
      controller.dispose();
    }
    if (values == null) return;
    try {
      final api = context.read<SessionProvider>().api;
      if (editing) {
        await api.patch('/batches/${initial['_id']}', values);
      } else {
        await api.post('/batches', values);
      }
      reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _archiveBatch(Map<String, dynamic> batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this batch/course?'),
        content: Text(
          '${batch['name'] ?? 'This batch'} will be archived and hidden from new enrollments. Existing students, tests and history are preserved; you can reactivate it later.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive batch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .delete('/batches/${batch['_id']}');
      reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _activateBatch(Map<String, dynamic> batch) async {
    try {
      await context
          .read<SessionProvider>()
          .api
          .patch('/batches/${batch['_id']}', {'status': 'active'});
      reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Batches & Courses'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveBatch,
          icon: const Icon(Icons.add),
          label: const Text('Add batch'),
        ),
        body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final batches = snapshot.data as List<dynamic>? ?? [];
            if (batches.isEmpty) {
              return const EmptyState(
                  title: 'No batches yet',
                  subtitle:
                      'Create a batch first, then enroll students into it.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: batches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final batch = Map<String, dynamic>.from(batches[index]);
                final active = batch['status'] == 'active';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          active ? AcademyColors.mint : Colors.grey.shade200,
                      child: Icon(Icons.groups_2_outlined,
                          color: active ? AcademyColors.green : Colors.grey),
                    ),
                    title: Text(batch['name']?.toString() ?? ''),
                    subtitle: Text(
                      '${batch['course'] ?? 'Course'} • ${batch['trainer'] ?? 'Trainer not set'}\n'
                      '${batch['startTime'] ?? ''}–${batch['endTime'] ?? ''} • ${batch['location'] ?? ''}\n'
                      '${active ? 'ACTIVE' : 'ARCHIVED'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Batch actions',
                      onSelected: (action) {
                        if (action == 'edit') _saveBatch(batch);
                        if (action == 'archive') _archiveBatch(batch);
                        if (action == 'activate') _activateBatch(batch);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Edit batch/course')),
                        if (active)
                          const PopupMenuItem(
                              value: 'archive', child: Text('Delete / archive'))
                        else
                          const PopupMenuItem(
                              value: 'activate',
                              child: Text('Reactivate batch')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class TestManagementPage extends StatefulWidget {
  const TestManagementPage({super.key});
  @override
  State<TestManagementPage> createState() => _TestManagementPageState();
}

class _TestManagementPageState extends State<TestManagementPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/tests');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/tests'));

  Future<DateTime?> _pickDate(
      BuildContext pickerContext, DateTime initial) async {
    final date = await showDatePicker(
      context: pickerContext,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  Future<TimeOfDay?> _pickTime(
      BuildContext pickerContext, DateTime initial) async {
    return showTimePicker(
      context: pickerContext,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
  }

  Future<void> _createTest({Map<String, dynamic>? existing}) async {
    final api = context.read<SessionProvider>().api;
    List<dynamic> batches;
    try {
      batches = await api.get('/batches') as List<dynamic>;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    final activeBatches = batches
        .where((batch) => batch is Map && batch['status'] == 'active')
        .toList();
    if (activeBatches.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create an active batch first.')));
      return;
    }
    final title =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final description =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final duration =
        TextEditingController(text: '${existing?['duration'] ?? 30}');
    final form = GlobalKey<FormState>();
    final existingBatchId = existing?['batchId'] is Map
        ? existing!['batchId']['_id']?.toString()
        : existing?['batchId']?.toString();
    String? batchId = existing == null
        ? ''
        : activeBatches
                .any((batch) => batch['_id']?.toString() == existingBatchId)
            ? existingBatchId
            : '';
    DateTime start =
        DateTime.tryParse(existing?['startTime']?.toString() ?? '') ??
            DateTime.now().add(const Duration(hours: 1));
    DateTime end =
        start.add(Duration(minutes: int.tryParse(duration.text) ?? 30));
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? 'Schedule a test' : 'Edit test'),
          content: Form(
            key: form,
            child: SizedBox(
              width:
                  (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 700.0),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: title,
                    decoration:
                        const InputDecoration(labelText: 'Test title *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a test title'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)')),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: batchId,
                    decoration:
                        const InputDecoration(labelText: 'Target batch'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: '', child: Text('All batches')),
                      ...activeBatches.map((batch) => DropdownMenuItem<String>(
                            value: batch['_id'].toString(),
                            child: Text(batch['name']?.toString() ?? 'Batch'),
                          )),
                    ],
                    onChanged: (value) => update(() => batchId = value),
                    validator: (_) => null,
                  ),
                  TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Test duration in minutes *'),
                    onChanged: (value) => update(() {
                      final minutes = int.tryParse(value);
                      if (minutes != null && minutes > 0) {
                        end = start.add(Duration(minutes: minutes));
                      }
                    }),
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      return parsed == null || parsed < 1 || parsed > 300
                          ? 'Use 1–300 minutes'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Test starts'),
                    subtitle:
                        Text(DateFormat('EEE, dd MMM yyyy').format(start)),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(DateFormat('hh:mm a').format(start)),
                      onPressed: () async {
                        final selected = await _pickTime(dialogContext, start);
                        if (selected != null) {
                          update(() {
                            start = DateTime(start.year, start.month, start.day,
                                selected.hour, selected.minute);
                            end = start.add(Duration(
                                minutes: int.tryParse(duration.text) ?? 30));
                          });
                        }
                      },
                    ),
                    onTap: () async {
                      final selected = await _pickDate(dialogContext, start);
                      if (selected != null) {
                        update(() {
                          start = DateTime(selected.year, selected.month,
                              selected.day, start.hour, start.minute);
                          end = start.add(Duration(
                              minutes: int.tryParse(duration.text) ?? 30));
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Calculated closing time'),
                    subtitle: Text(
                        '${DateFormat('EEE, dd MMM yyyy • hh:mm a').format(end)} (start + duration)'),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Only the first timed attempt is recorded as the official result. Practice unlocks 24 hours later; practice answers and scores are not saved.',
                        style: TextStyle(fontSize: 11)),
                  ),
                  const Text(
                      'After saving, add questions, then publish. Select All batches to show it to every student.',
                      style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                if (!end.isAfter(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Close time must be after start time.')));
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  // Send null explicitly so an existing batch-specific test
                  // can be changed to All batches during edit.
                  'batchId':
                      batchId == null || batchId!.isEmpty ? null : batchId,
                  'duration': int.parse(duration.text),
                  'startTime': start.toUtc().toIso8601String(),
                  'endTime': end.toUtc().toIso8601String(),
                  'instructions': 'Choose one answer per question.',
                });
              },
              child: Text(existing == null ? 'Create test' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;
    try {
      if (existing == null) {
        await api.post('/tests', values);
      } else {
        await api.patch('/tests/${existing['_id']}', values);
      }
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(existing == null ? 'Test created.' : 'Test updated.')));
      }
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  Future<void> _addQuestion(Map<String, dynamic> test) async {
    final question = TextEditingController();
    final optionA = TextEditingController();
    final optionB = TextEditingController();
    final optionC = TextEditingController();
    final optionD = TextEditingController();
    var correctAnswer = 0;
    final payload = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Add MCQ'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: question,
                        decoration:
                            const InputDecoration(labelText: 'Question')),
                    const SizedBox(height: 14),
                    TextField(
                        controller: optionA,
                        decoration:
                            const InputDecoration(labelText: 'Option A')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: optionB,
                        decoration:
                            const InputDecoration(labelText: 'Option B')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: optionC,
                        decoration:
                            const InputDecoration(labelText: 'Option C')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: optionD,
                        decoration:
                            const InputDecoration(labelText: 'Option D')),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: correctAnswer,
                      decoration: const InputDecoration(
                          labelText: 'Correct answer (not shown to students)'),
                      items: List.generate(
                          4,
                          (index) => DropdownMenuItem(
                              value: index,
                              child: Text(
                                  'Option ${String.fromCharCode(65 + index)}'))),
                      onChanged: (value) =>
                          update(() => correctAnswer = value ?? 0),
                    ),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, {
                              'questionText': question.text,
                              'options': [
                                optionA.text,
                                optionB.text,
                                optionC.text,
                                optionD.text
                              ],
                              'correctAnswer': correctAnswer,
                              'marks': 1,
                            }),
                        child: const Text('Save question')),
                  ],
                )));
    if (payload == null) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .post('/tests/${test['_id']}/questions', payload);
      reload();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  Future<void> _addQuestions(Map<String, dynamic> test) async {
    final drafts = List.generate(10, (_) => _BulkQuestionDraft());
    final size = MediaQuery.sizeOf(context);
    final payload = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Add questions • ${drafts.length}/100'),
          content: SizedBox(
            width: (size.width - 48).clamp(280.0, 760.0),
            height: size.height * .72,
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: drafts.length >= 100
                      ? null
                      : () => update(() => drafts.addAll(List.generate(
                            (100 - drafts.length).clamp(0, 10).toInt(),
                            (_) => _BulkQuestionDraft(),
                          ))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add 10 more (maximum 100)'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: drafts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text('Question ${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (drafts.length > 1)
                                IconButton(
                                  tooltip: 'Remove this question',
                                  onPressed: () => update(() {
                                    drafts.removeAt(index).dispose();
                                  }),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                ),
                            ]),
                            TextField(
                              controller: draft.question,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Question text *'),
                            ),
                            const SizedBox(height: 6),
                            ...List.generate(
                              4,
                              (optionIndex) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: TextField(
                                  controller: draft.options[optionIndex],
                                  decoration: InputDecoration(
                                      labelText:
                                          'Option ${String.fromCharCode(65 + optionIndex)} *'),
                                ),
                              ),
                            ),
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: draft.correctAnswer,
                                  decoration: const InputDecoration(
                                      labelText: 'Correct option'),
                                  items: List.generate(
                                    4,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                          'Option ${String.fromCharCode(65 + i)}'),
                                    ),
                                  ),
                                  onChanged: (value) => update(
                                      () => draft.correctAnswer = value ?? 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: draft.marks,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'Marks'),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                for (var i = 0; i < drafts.length; i++) {
                  final draft = drafts[i];
                  final marks = num.tryParse(draft.marks.text);
                  if (draft.question.text.trim().isEmpty ||
                      draft.options
                          .any((option) => option.text.trim().isEmpty) ||
                      marks == null ||
                      marks < .5 ||
                      marks > 100) {
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                        content: Text(
                            'Complete question ${i + 1}, all four options, and valid marks (0.5–100).')));
                    return;
                  }
                }
                Navigator.pop(
                  dialogContext,
                  drafts
                      .map((draft) => <String, dynamic>{
                            'questionText': draft.question.text.trim(),
                            'options': draft.options
                                .map((option) => option.text.trim())
                                .toList(),
                            'correctAnswer': draft.correctAnswer,
                            'marks': num.parse(draft.marks.text),
                          })
                      .toList(),
                );
              },
              child: Text('Save ${drafts.length} questions'),
            ),
          ],
        ),
      ),
    );
    for (final draft in drafts) {
      draft.dispose();
    }
    if (payload == null) return;
    try {
      await context.read<SessionProvider>().api.patch(
          '/tests/${test['_id']}/questions/bulk', {'questions': payload});
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${payload.length} questions saved together.')));
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  Future<void> _publish(Map<String, dynamic> test) async {
    try {
      final result = await context
          .read<SessionProvider>()
          .api
          .patch('/tests/${test['_id']}/publish', {'status': 'published'});
      reload();
      if (mounted) {
        final warning = result is Map ? result['notificationWarning'] : null;
        final sent = result is Map ? result['notificationsSent'] ?? 0 : 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(warning?.toString() ??
              'Test published. $sent students notified.'),
        ));
      }
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  Future<void> _deleteTest(Map<String, dynamic> test) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete this test?'),
        content: Text(
          '“${test['title'] ?? 'Test'}” and all its questions, attempts, results and test notifications will be permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<SessionProvider>().api.delete('/tests/${test['_id']}');
      reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test and its results were deleted')));
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tests & Questions'), actions: [
          IconButton(
              tooltip: 'View results',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminResultsPage())),
              icon: const Icon(Icons.emoji_events_outlined)),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createTest(),
            icon: const Icon(Icons.add),
            label: const Text('Create test')),
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
                    title: 'No tests created',
                    subtitle: 'Create a test and add MCQ questions.');
              return ListView(
                  padding: const EdgeInsets.all(14),
                  children: tests.map((rawTest) {
                    final test = Map<String, dynamic>.from(rawTest);
                    return Card(
                        child: ExpansionTile(
                      title: Text(test['title'] ?? ''),
                      subtitle: Text(
                          '${test['status'] ?? 'draft'} • ${test['questionCount'] ?? 0} questions\n'
                          '${test['batchId']?['name'] ?? 'Batch'} • ${test['startTime'] == null ? 'No schedule' : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(test['startTime']).toLocal())}'),
                      trailing: IconButton(
                        tooltip: 'Delete test and results',
                        onPressed: () => _deleteTest(test),
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      children: [
                        ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: const Text('Edit test schedule and details'),
                            onTap: () => _createTest(existing: test)),
                        ListTile(
                            leading: const Icon(Icons.library_add_outlined),
                            title:
                                const Text('Add up to 100 questions together'),
                            onTap: () => _addQuestions(test)),
                        ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Add one question'),
                            onTap: () => _addQuestion(test)),
                        ListTile(
                            leading: const Icon(Icons.publish),
                            title: const Text('Publish test'),
                            onTap: () => _publish(test)),
                      ],
                    ));
                  }).toList());
            }),
      );
}

class AdminResultsPage extends StatefulWidget {
  const AdminResultsPage({super.key});

  @override
  State<AdminResultsPage> createState() => _AdminResultsPageState();
}

class _AdminResultsPageState extends State<AdminResultsPage> {
  late Future<dynamic> future;
  late Future<dynamic> batchesFuture;
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    future = _load();
  }

  Future<dynamic> _load() => context.read<SessionProvider>().api.get(
        '/tests/results',
        query: selectedBatchId == null ? null : {'batchId': selectedBatchId!},
      );

  void reload() => setState(() => future = _load());

  void _showResult(Map<String, dynamic> result) {
    final student = result['studentId'] is Map
        ? Map<String, dynamic>.from(result['studentId'])
        : <String, dynamic>{};
    final user = student['userId'] is Map
        ? Map<String, dynamic>.from(student['userId'])
        : <String, dynamic>{};
    final batch = student['batchId'] is Map
        ? student['batchId']['name']?.toString() ?? ''
        : '';
    final test = result['testId'] is Map ? result['testId'] : const {};
    final dob = DateTime.tryParse(student['dateOfBirth']?.toString() ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(user['name']?.toString() ?? 'Student result'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 620.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Student ID: ${student['studentId'] ?? '—'}'),
                Text('Batch: ${batch.isEmpty ? '—' : batch}'),
                Text('Phone: ${user['phone'] ?? '—'}'),
                Text('Course: ${student['course'] ?? '—'}'),
                Text(
                    'Date of birth: ${dob == null ? '—' : DateFormat('dd MMM yyyy').format(dob.toLocal())}'),
                Text('Height: ${student['heightCm'] ?? '—'} cm'),
                Text('Weight: ${student['weightKg'] ?? '—'} kg'),
                Text('Chest: ${student['chestCm'] ?? '—'} cm'),
                Text('Father: ${student['fatherName'] ?? '—'}'),
                Text('Mother: ${student['motherName'] ?? '—'}'),
                Text('Parent phone: ${student['parentPhone'] ?? '—'}'),
                Text('Address: ${student['address'] ?? '—'}'),
                const Divider(height: 24),
                Text('Test: ${test['title'] ?? 'Test'}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'Score: ${result['obtainedMarks'] ?? 0}/${result['totalMarks'] ?? 0} • ${result['percentage'] ?? 0}%'),
                Text(
                    'Correct: ${result['correct'] ?? 0} • Wrong: ${result['wrong'] ?? 0} • Attempted: ${result['attempted'] ?? 0}'),
                if (result['autoSubmitted'] == true)
                  const Text('Submitted automatically when time expired.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Exam Results'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FutureBuilder<dynamic>(
              future: batchesFuture,
              builder: (context, snapshot) {
                final batches = snapshot.data as List<dynamic>? ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: selectedBatchId ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Filter results by batch',
                      prefixIcon: Icon(Icons.groups_outlined)),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All batches')),
                    ...batches.map((batch) => DropdownMenuItem<String>(
                          value: batch['_id'].toString(),
                          child: Text(batch['name']?.toString() ?? 'Batch'),
                        )),
                  ],
                  onChanged: (value) => setState(() {
                    selectedBatchId = value == 'all' ? null : value;
                    future = _load();
                  }),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<dynamic>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState();
                }
                if (snapshot.hasError) {
                  return ErrorState(
                      message: snapshot.error.toString(), retry: reload);
                }
                final results = snapshot.data as List<dynamic>? ?? [];
                if (results.isEmpty) {
                  return const EmptyState(
                      title: 'No exam results yet',
                      subtitle:
                          'Submitted and automatically closed attempts appear here.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = Map<String, dynamic>.from(results[index]);
                    final student = result['studentId'] is Map
                        ? Map<String, dynamic>.from(result['studentId'])
                        : <String, dynamic>{};
                    final user = student['userId'] is Map
                        ? Map<String, dynamic>.from(student['userId'])
                        : <String, dynamic>{};
                    final test = result['testId'] is Map
                        ? Map<String, dynamic>.from(result['testId'])
                        : <String, dynamic>{};
                    final batch = test['batchId'] is Map
                        ? test['batchId']['name']?.toString() ?? ''
                        : '';
                    final photo = student['photo']?.toString() ?? '';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AcademyColors.mint,
                          backgroundImage: photo.startsWith('http')
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline,
                                  color: AcademyColors.green)
                              : null,
                        ),
                        title: Text(user['name']?.toString() ?? 'Student'),
                        subtitle: Text(
                            '${student['studentId'] ?? '—'} • ${batch.isEmpty ? 'Batch' : batch}\n${test['title'] ?? 'Test'}${result['autoSubmitted'] == true ? ' • Auto-submitted' : ''}'),
                        trailing: Text(
                          '${result['obtainedMarks'] ?? 0}/${result['totalMarks'] ?? 0}\n${result['percentage'] ?? 0}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AcademyColors.green),
                        ),
                        onTap: () => _showResult(result),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}

class TrainingAdminPage extends StatefulWidget {
  const TrainingAdminPage({super.key});
  @override
  State<TrainingAdminPage> createState() => _TrainingAdminPageState();
}

class _TrainingAdminPageState extends State<TrainingAdminPage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/training');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/training'));

  TimeOfDay _parseTime(dynamic value, TimeOfDay fallback) {
    final parts = value?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    final parts = text.split(':');
    if (parts.length < 2) return text.isEmpty ? 'Time not set' : text;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) return text;
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  Future<void> _saveTraining([Map<String, dynamic>? initial]) async {
    final editing = initial != null;
    final api = context.read<SessionProvider>().api;
    List<dynamic> batches;
    try {
      batches = await api.get('/batches') as List<dynamic>;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    final active = batches
        .where((batch) => batch is Map && batch['status'] == 'active')
        .toList();
    final initialBatch = initial?['batchId'] is Map
        ? initial!['batchId']['_id']?.toString()
        : initial?['batchId']?.toString();
    if (editing &&
        initialBatch != null &&
        !active.any((batch) => batch['_id']?.toString() == initialBatch)) {
      final former = batches
          .where((batch) => batch['_id']?.toString() == initialBatch)
          .toList();
      if (former.isNotEmpty) active.insert(0, former.first);
    }
    if (active.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create an active batch first.')));
      return;
    }
    final title =
        TextEditingController(text: initial?['title']?.toString() ?? '');
    final location =
        TextEditingController(text: initial?['location']?.toString() ?? '');
    final form = GlobalKey<FormState>();
    String? batchId =
        active.any((batch) => batch['_id']?.toString() == initialBatch)
            ? initialBatch
            : active.first['_id']?.toString();
    final initialDate =
        DateTime.tryParse(initial?['date']?.toString() ?? '')?.toLocal();
    DateTime date = initialDate ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay start =
        _parseTime(initial?['startTime'], const TimeOfDay(hour: 6, minute: 0));
    TimeOfDay end =
        _parseTime(initial?['endTime'], const TimeOfDay(hour: 8, minute: 0));
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(editing ? 'Edit training schedule' : 'Schedule training'),
          content: Form(
            key: form,
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 544
                  ? MediaQuery.of(context).size.width - 64
                  : 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: title,
                    decoration:
                        const InputDecoration(labelText: 'Training name *'),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                            ? 'Enter a title'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: batchId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Target batch *'),
                    items: active
                        .map((batch) => DropdownMenuItem<String>(
                              value: batch['_id'].toString(),
                              child: Text(
                                  '${batch['name'] ?? 'Batch'}${batch['status'] == 'inactive' ? ' (archived)' : ''}'),
                            ))
                        .toList(),
                    onChanged: (value) => update(() => batchId = value),
                    validator: (value) =>
                        value == null ? 'Select a batch' : null,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                      controller: location,
                      decoration: const InputDecoration(labelText: 'Location')),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Training date'),
                    subtitle: Text(DateFormat('EEE, dd MMM yyyy').format(date)),
                    onTap: () async {
                      final chosen = await showDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 1825)),
                      );
                      if (chosen != null)
                        update(() => date = DateTime(chosen.year, chosen.month,
                            chosen.day, start.hour, start.minute));
                    },
                  ),
                  Row(children: [
                    Expanded(
                        child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start time'),
                      subtitle: Text(start.format(context)),
                      onTap: () async {
                        final chosen = await showTimePicker(
                            context: dialogContext, initialTime: start);
                        if (chosen != null)
                          update(() {
                            start = chosen;
                            date = DateTime(date.year, date.month, date.day,
                                start.hour, start.minute);
                          });
                      },
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End time'),
                      subtitle: Text(end.format(context)),
                      onTap: () async {
                        final chosen = await showTimePicker(
                            context: dialogContext, initialTime: end);
                        if (chosen != null) update(() => end = chosen);
                      },
                    )),
                  ]),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false) ||
                    batchId == null) return;
                if ((end.hour * 60 + end.minute) <=
                    (start.hour * 60 + start.minute)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('End time must be after start time.')));
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': title.text.trim(),
                  'batchId': batchId!,
                  'location': location.text.trim(),
                  'date': DateTime(date.year, date.month, date.day, start.hour,
                          start.minute)
                      .toUtc()
                      .toIso8601String(),
                  'startTime':
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                  'endTime':
                      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                });
              },
              child:
                  Text(editing ? 'Save schedule' : 'Schedule & notify batch'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    location.dispose();
    if (values == null) return;
    try {
      final result = editing
          ? await api.patch('/training/${initial['_id']}', values)
          : await api.post('/training', values);
      reload();
      if (mounted) {
        final warning = result is Map ? result['notificationWarning'] : null;
        final sent = result is Map ? result['notificationsSent'] ?? 0 : 0;
        final fallback = editing
            ? 'Training updated. $sent students notified.'
            : 'Training scheduled. $sent students notified.';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(warning?.toString() ?? fallback)));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteTraining(Map<String, dynamic> session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete training schedule?'),
        content: Text(
            '${session['title'] ?? 'This session'} will be cancelled and removed from active schedules. Existing records are preserved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete schedule'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .delete('/training/${session['_id']}');
      reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Training schedule deleted.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Training Schedule'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveTraining,
          icon: const Icon(Icons.add),
          label: const Text('Schedule'),
        ),
        body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final sessions = snapshot.data as List<dynamic>? ?? [];
            if (sessions.isEmpty)
              return const EmptyState(
                  title: 'No training scheduled',
                  subtitle: 'Add a batch training session.');
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = Map<String, dynamic>.from(sessions[index]);
                final date =
                    DateTime.tryParse(session['date']?.toString() ?? '')
                        ?.toLocal();
                final dateLabel = date == null
                    ? 'Date not set'
                    : DateFormat('EEE, dd MMM yyyy').format(date);
                final batch = session['batchId'] is Map
                    ? session['batchId']['name']?.toString()
                    : '';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: AcademyColors.mint,
                        child: Icon(Icons.fitness_center,
                            color: AcademyColors.green)),
                    title: Text(session['title']?.toString() ?? ''),
                    subtitle: Text(
                        '$dateLabel • ${_formatTime(session['startTime'])}–${_formatTime(session['endTime'])}\n${batch ?? 'Batch'} • ${session['location'] ?? 'Location not set'}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Training actions',
                      onSelected: (action) {
                        if (action == 'edit') _saveTraining(session);
                        if (action == 'delete') _deleteTraining(session);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'edit', child: Text('Edit schedule')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete schedule')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
