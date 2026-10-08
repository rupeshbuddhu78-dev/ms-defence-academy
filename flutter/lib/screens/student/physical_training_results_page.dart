import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class PhysicalTrainingResultsPage extends StatefulWidget {
  const PhysicalTrainingResultsPage({super.key});

  @override
  State<PhysicalTrainingResultsPage> createState() =>
      _PhysicalTrainingResultsPageState();
}

class _PhysicalTrainingResultsPageState
    extends State<PhysicalTrainingResultsPage> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = _loadData();
  }

  Future<dynamic> _loadData() => Future.wait<dynamic>([
        context.read<SessionProvider>().api.get('/physical-training-sheets'),
        context.read<SessionProvider>().api.get('/physical-training-results'),
      ]);

  void reload() => setState(() => future = _loadData());

  String _duration(dynamic value) {
    if (value == null) return '—';
    final seconds = (num.tryParse(value.toString()) ?? 0).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min';
  }

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AcademyColors.mint.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: AcademyColors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  Map<String, dynamic> _student(dynamic row) {
    final raw = row is Map ? row['studentId'] : null;
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String _studentName(dynamic row) {
    final student = _student(row);
    final user = student['userId'] is Map
        ? Map<String, dynamic>.from(student['userId'])
        : <String, dynamic>{};
    return user['name']?.toString() ??
        student['studentId']?.toString() ??
        'Student';
  }

  bool _isOwnRow(dynamic row, SessionProvider session) {
    final student = _student(row);
    final profileId = session.profile?['_id']?.toString() ?? '';
    final studentCode = session.profile?['studentId']?.toString() ?? '';
    return (profileId.isNotEmpty && student['_id']?.toString() == profileId) ||
        (studentCode.isNotEmpty &&
            student['studentId']?.toString() == studentCode);
  }

  String _cellValue(dynamic row, Map<String, dynamic> column) {
    final values = row is Map && row['values'] is Map
        ? Map<String, dynamic>.from(row['values'] as Map)
        : <String, dynamic>{};
    final value = values[column['key']?.toString()];
    if (value == null || value.toString().trim().isEmpty) return '—';
    if (column['type'] == 'passfail') {
      return value.toString().toLowerCase() == 'pass' ? '✓' : '✗';
    }
    return value.toString();
  }

  Widget _personalRowSummary(dynamic row, List<Map<String, dynamic>> columns) {
    final values = row is Map && row['values'] is Map
        ? Map<String, dynamic>.from(row['values'] as Map)
        : <String, dynamic>{};
    final valuesShown = <Widget>[
      for (final column in columns)
        if (values[column['key']] != null &&
            values[column['key']].toString().trim().isNotEmpty)
          Chip(
              label: Text('${column['label']}: ${_cellValue({
                'values': values
              }, column)}')),
      if (!columns.any((column) => column['key'] == 'total_marks'))
        Chip(
            backgroundColor: AcademyColors.mint,
            label: Text('Total: ${row['totalMarks'] ?? 0}')),
    ];
    return Card(
      color: AcademyColors.mint.withValues(alpha: .35),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your individual result',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_studentName(row)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 2, children: valuesShown),
        ]),
      ),
    );
  }

  Widget _sheetCard(dynamic rawSheet, SessionProvider session) {
    final sheet = Map<String, dynamic>.from(rawSheet as Map);
    final rawColumns = sheet['columns'] as List<dynamic>? ?? [];
    final columns =
        rawColumns.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
    final hasOverallMarks =
        columns.any((column) => column['key'] == 'total_marks');
    final rows = sheet['rows'] as List<dynamic>? ?? [];
    final ownRows = rows.where((row) => _isOwnRow(row, session)).toList();
    final batch = sheet['batchId'] is Map
        ? sheet['batchId']['name']?.toString() ?? ''
        : '';
    final date = DateTime.tryParse(sheet['testDate']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: AcademyColors.mint,
          child: Icon(Icons.table_chart, color: AcademyColors.green),
        ),
        title: Text(sheet['title']?.toString() ?? 'Physical test'),
        subtitle: Text(
            '$batch • ${date == null ? 'Date unavailable' : DateFormat('dd MMM yyyy').format(date.toLocal())}\n${rows.length} students • ${columns.where((column) => column['key'] != 'total_marks').length} events'),
        children: [
          if (ownRows.isNotEmpty) _personalRowSummary(ownRows.first, columns),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No student rows are available yet.'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AcademyColors.forest),
                  headingTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  columns: [
                    const DataColumn(label: Text('S.N.')),
                    const DataColumn(label: Text('विद्यार्थी का नाम')),
                    ...columns.map((column) => DataColumn(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(column['label']?.toString() ?? '',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        )),
                    if (!hasOverallMarks)
                      const DataColumn(label: Text('Total')),
                  ],
                  rows: rows.asMap().entries.map((entry) {
                    final row = entry.value;
                    final isOwn = _isOwnRow(row, session);
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>(
                          (states) => isOwn ? AcademyColors.mint : null),
                      cells: [
                        DataCell(Text('${entry.key + 1}')),
                        DataCell(Text(_studentName(row),
                            style: TextStyle(
                                fontWeight: isOwn
                                    ? FontWeight.bold
                                    : FontWeight.normal))),
                        ...columns.map((column) => DataCell(Text(
                              _cellValue(row, column),
                              style: TextStyle(
                                  fontWeight: column['type'] == 'marks'
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            ))),
                        if (!hasOverallMarks)
                          DataCell(Text('${row['totalMarks'] ?? 0}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          if (ownRows.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                  'Your row is highlighted. This table is shared only with students in your batch.'),
            ),
        ],
      ),
    );
  }

  Widget _individualRecord(dynamic raw) {
    final item = Map<String, dynamic>.from(raw as Map);
    final date = DateTime.tryParse(item['testDate']?.toString() ?? '');
    final metrics = <Widget>[
      if (item['runTimeSeconds'] != null)
        _metric('Running time', _duration(item['runTimeSeconds']),
            Icons.directions_run),
      if (item['beamReps'] != null)
        _metric('Beam / pull-ups', '${item['beamReps']} reps',
            Icons.fitness_center),
      if (item['longJumpCm'] != null)
        _metric('Long jump', '${item['longJumpCm']} cm', Icons.height),
      if (item['highJumpCm'] != null)
        _metric('High jump', '${item['highJumpCm']} cm', Icons.north),
      if (item['pushUps'] != null)
        _metric('Push-ups', '${item['pushUps']} reps', Icons.sports_gymnastics),
      if (item['sitUps'] != null)
        _metric('Sit-ups', '${item['sitUps']} reps', Icons.accessibility_new),
      if (item['shuttleRunSeconds'] != null)
        _metric(
            'Shuttle run', _duration(item['shuttleRunSeconds']), Icons.sync),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              date == null
                  ? 'Individual assessment'
                  : DateFormat('EEE, dd MMM yyyy').format(date.toLocal()),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...metrics.map((metric) => Padding(
              padding: const EdgeInsets.only(bottom: 7), child: metric)),
          if ((item['remarks'] ?? '').toString().trim().isNotEmpty) ...[
            const Divider(),
            Text('Coach notes: ${item['remarks']}'),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Physical Training Results'), actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
      ]),
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
          final response = snapshot.data as List<dynamic>? ?? [];
          final sheets = response.isNotEmpty
              ? (response[0] as List<dynamic>? ?? [])
              : <dynamic>[];
          final records = response.length > 1
              ? (response[1] as List<dynamic>? ?? [])
              : <dynamic>[];
          if (sheets.isEmpty && records.isEmpty) {
            return const EmptyState(
              title: 'No physical results yet',
              subtitle:
                  'Your batch marks sheets and individual physical results will appear here after the coach saves them.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sheets.isNotEmpty) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.groups, color: AcademyColors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'Batch marks sheets are visible to students in your batch. Your row is highlighted.'),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Batch physical marks sheets',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...sheets.map((sheet) => _sheetCard(sheet, session)),
              ],
              if (records.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('My individual physical history',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...records.map(_individualRecord),
              ],
            ],
          );
        },
      ),
    );
  }
}
