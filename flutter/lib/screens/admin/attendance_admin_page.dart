import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';
import 'admin_pages.dart' show ScannerPage;

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime focusedDay = DateTime.now();
  DateTime selectedDay = DateTime.now();
  late Future<dynamic> monthFuture;
  late Future<dynamic> dayFuture;
  late Future<dynamic> batchesFuture;
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    monthFuture = _loadMonth(focusedDay);
    dayFuture = _loadDay(selectedDay);
  }

  Future<dynamic> _loadMonth(DateTime month) {
    final from = DateTime.utc(month.year, month.month, 1);
    final to = DateTime.utc(month.year, month.month + 1, 1);
    final query = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };
    if (selectedBatchId != null) query['batchId'] = selectedBatchId!;
    return context
        .read<SessionProvider>()
        .api
        .get('/attendance/calendar', query: query);
  }

  Future<dynamic> _loadDay(DateTime day) {
    final from = DateTime.utc(day.year, day.month, day.day);
    final to = DateTime.utc(day.year, day.month, day.day + 1)
        .subtract(const Duration(milliseconds: 1));
    final query = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };
    if (selectedBatchId != null) query['batchId'] = selectedBatchId!;
    return context.read<SessionProvider>().api.get('/attendance', query: query);
  }

  void reload() => setState(() {
        monthFuture = _loadMonth(focusedDay);
        dayFuture = _loadDay(selectedDay);
      });

  DateTime? _calendarDate(dynamic value) {
    final parts = value.toString().split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  void _openStudentHistory(
      Map<String, dynamic> student, Map<String, dynamic> user) {
    final profileId = student['_id']?.toString();
    if (profileId == null || profileId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAttendanceHistoryPage(
          studentProfileId: profileId,
          studentName: user['name']?.toString() ?? 'Student',
          studentCode: student['studentId']?.toString() ?? '—',
          studentPhoto: student['photo']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attendance Calendar'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerPage()),
          ).then((_) => reload()),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan attendance'),
        ),
        body: FutureBuilder<dynamic>(
          future: monthFuture,
          builder: (context, monthSnapshot) {
            if (monthSnapshot.connectionState != ConnectionState.done) {
              return const LoadingState();
            }
            if (monthSnapshot.hasError) {
              return ErrorState(
                  message: monthSnapshot.error.toString(), retry: reload);
            }
            final monthData =
                Map<String, dynamic>.from(monthSnapshot.data ?? {});
            final rawDays = monthData['days'] as List<dynamic>? ?? [];
            final eventMap = <DateTime, Map<String, dynamic>>{};
            for (final raw in rawDays) {
              final item = Map<String, dynamic>.from(raw);
              final date = _calendarDate(item['date']);
              if (date != null) eventMap[date] = item;
            }
            final summary = monthData['summary'] is Map
                ? Map<String, dynamic>.from(monthData['summary'])
                : <String, dynamic>{};
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              children: [
                FutureBuilder<dynamic>(
                  future: batchesFuture,
                  builder: (context, batchSnapshot) {
                    final batches = batchSnapshot.data as List<dynamic>? ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedBatchId ?? 'all',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Attendance batch',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('All batches')),
                          ...batches.map((batch) => DropdownMenuItem<String>(
                                value: batch['_id'].toString(),
                                child:
                                    Text(batch['name']?.toString() ?? 'Batch'),
                              )),
                        ],
                        onChanged: (value) => setState(() {
                          selectedBatchId = value == 'all' ? null : value;
                          monthFuture = _loadMonth(focusedDay);
                          dayFuture = _loadDay(selectedDay);
                        }),
                      ),
                    );
                  },
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: TableCalendar<Map<String, dynamic>>(
                      firstDay: DateTime.utc(2022, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, selectedDay),
                      eventLoader: (day) {
                        final item =
                            eventMap[DateTime(day.year, day.month, day.day)];
                        return item == null ? const [] : [item];
                      },
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
                        dayFuture = _loadDay(selected);
                      }),
                      onPageChanged: (focused) => setState(() {
                        focusedDay = focused;
                        selectedDay = DateTime(focused.year, focused.month, 1);
                        monthFuture = _loadMonth(focused);
                        dayFuture = _loadDay(selectedDay);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _summary('Marked', '${summary['total'] ?? 0}')),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _summary('Present', '${summary['present'] ?? 0}')),
                  const SizedBox(width: 7),
                  Expanded(
                      child: _summary('Absent', '${summary['absent'] ?? 0}')),
                  const SizedBox(width: 7),
                  Expanded(
                      child:
                          _summary('Rate', '${summary['percentage'] ?? 0}%')),
                ]),
                const SizedBox(height: 16),
                Text(DateFormat('EEEE, dd MMMM yyyy').format(selectedDay),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                FutureBuilder<dynamic>(
                  future: dayFuture,
                  builder: (context, daySnapshot) {
                    if (daySnapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (daySnapshot.hasError) {
                      return ErrorState(
                          message: daySnapshot.error.toString(), retry: reload);
                    }
                    final data =
                        Map<String, dynamic>.from(daySnapshot.data ?? {});
                    final records = data['records'] as List<dynamic>? ?? [];
                    if (records.isEmpty) {
                      return const EmptyState(
                          title: 'No attendance for this date',
                          subtitle:
                              'Select a marked day or scan a student QR code.');
                    }
                    return Column(
                        children: records.map((raw) {
                      final record = Map<String, dynamic>.from(raw);
                      final student = record['studentId'] is Map
                          ? Map<String, dynamic>.from(record['studentId'])
                          : <String, dynamic>{};
                      final user = student['userId'] is Map
                          ? Map<String, dynamic>.from(student['userId'])
                          : <String, dynamic>{};
                      final batch = record['batchId'] is Map
                          ? record['batchId']['name']?.toString() ?? ''
                          : '';
                      final time =
                          DateTime.tryParse(record['time']?.toString() ?? '');
                      final present = record['status'] == 'present';
                      final photo = (student['photo'] ?? '').toString();
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photo.startsWith('http')
                                ? NetworkImage(photo)
                                : null,
                            backgroundColor: present
                                ? AcademyColors.mint
                                : Colors.red.shade50,
                            child: photo.isNotEmpty
                                ? null
                                : Icon(
                                    present
                                        ? Icons.check_circle_outline
                                        : Icons.cancel_outlined,
                                    color: present
                                        ? AcademyColors.green
                                        : Colors.red),
                          ),
                          title: Text(user['name']?.toString() ?? 'Student',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '$batch${student['studentId'] == null ? '' : ' • ${student['studentId']}'}'),
                          trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    present
                                        ? 'PRESENT'
                                        : (record['status'] ?? '')
                                            .toString()
                                            .toUpperCase(),
                                    style: TextStyle(
                                        color: present
                                            ? AcademyColors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(time == null
                                    ? '—'
                                    : DateFormat('h:mm a')
                                        .format(time.toLocal())),
                              ]),
                          onTap: () => _openStudentHistory(student, user),
                        ),
                      );
                    }).toList());
                  },
                ),
              ],
            );
          },
        ),
      );

  Widget _summary(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AcademyColors.green)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, color: AcademyColors.muted)),
          ]),
        ),
      );
}

class StudentAttendanceHistoryPage extends StatefulWidget {
  final String studentProfileId;
  final String studentName;
  final String studentCode;
  final String studentPhoto;

  const StudentAttendanceHistoryPage({
    super.key,
    required this.studentProfileId,
    required this.studentName,
    required this.studentCode,
    required this.studentPhoto,
  });

  @override
  State<StudentAttendanceHistoryPage> createState() =>
      _StudentAttendanceHistoryPageState();
}

class _StudentAttendanceHistoryPageState
    extends State<StudentAttendanceHistoryPage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() => context.read<SessionProvider>().api.get(
        '/attendance',
        query: {'studentId': widget.studentProfileId},
      );

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.studentName),
          actions: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
          ],
        ),
        body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingState();
            }
            if (snapshot.hasError) {
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            }
            final data = Map<String, dynamic>.from(snapshot.data ?? {});
            final summary = data['summary'] is Map
                ? Map<String, dynamic>.from(data['summary'])
                : <String, dynamic>{};
            final records = data['records'] as List<dynamic>? ?? [];
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: records.isEmpty ? 2 : records.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(children: [
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AcademyColors.mint,
                          backgroundImage:
                              widget.studentPhoto.startsWith('http')
                                  ? NetworkImage(widget.studentPhoto)
                                  : null,
                          child: widget.studentPhoto.isEmpty
                              ? const Icon(Icons.person,
                                  color: AcademyColors.green)
                              : null,
                        ),
                        title: Text(widget.studentName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Student ID: ${widget.studentCode}'),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                          child: _historyStat(
                              'Marked', '${summary['totalClasses'] ?? 0}')),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _historyStat(
                              'Present', '${summary['present'] ?? 0}')),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _historyStat(
                              'Absent', '${summary['absent'] ?? 0}')),
                      const SizedBox(width: 6),
                      Expanded(
                          child: _historyStat(
                              'Rate', '${summary['percentage'] ?? 0}%')),
                    ]),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Full attendance history • newest first',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                  ]);
                }
                if (records.isEmpty) {
                  return const EmptyState(
                      title: 'No attendance history',
                      subtitle: 'This student has no attendance records yet.');
                }
                final record = Map<String, dynamic>.from(records[index - 1]);
                final date = DateTime.tryParse(record['date']?.toString() ?? '')
                        ?.toLocal() ??
                    DateTime.now();
                final time =
                    DateTime.tryParse(record['time']?.toString() ?? '');
                final status = (record['status'] ?? 'unknown').toString();
                final present = status == 'present';
                final batch = record['batchId'] is Map
                    ? record['batchId']['name']?.toString() ?? ''
                    : '';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          present ? AcademyColors.mint : Colors.red.shade50,
                      child: Icon(present ? Icons.check_circle : Icons.cancel,
                          color: present ? AcademyColors.green : Colors.red),
                    ),
                    title: Text(DateFormat('EEE, dd MMM yyyy').format(date)),
                    subtitle: Text(
                        '${status.toUpperCase()}${batch.isEmpty ? '' : ' • $batch'}'),
                    trailing: Text(time == null
                        ? '—'
                        : DateFormat('h:mm a').format(time.toLocal())),
                  ),
                );
              },
            );
          },
        ),
      );

  Widget _historyStat(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AcademyColors.green)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, color: AcademyColors.muted)),
          ]),
        ),
      );
}
