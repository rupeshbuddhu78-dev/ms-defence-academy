import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

Map<String, dynamic> _singleValueEvent(
        String id, String label, String valueHint) =>
    {
      'id': id,
      'label': label,
      'columns': <Map<String, String>>[
        {'key': id, 'label': label, 'type': 'measurement'},
      ],
      'valueHint': valueHint,
    };

Map<String, dynamic> _runningEvent(String id, String label) => {
      'id': id,
      'label': '$label (दूरी + समय)',
      'columns': <Map<String, String>>[
        {
          'key': '${id}_distance_km',
          'label': '$label दूरी (KM)',
          'type': 'measurement',
        },
        {
          'key': '${id}_time',
          'label': '$label का समय',
          'type': 'measurement',
        },
      ],
    };

Map<String, dynamic> _passEvent(String id, String label) => {
      'id': id,
      'label': label,
      'columns': <Map<String, String>>[
        {'key': id, 'label': label, 'type': 'passfail'},
      ],
    };

const _testTemplates = <Map<String, String>>[
  {'id': 'army_agniveer', 'name': 'Army Agniveer'},
  {'id': 'bhg', 'name': 'BHG / Home Guard'},
  {'id': 'bsf', 'name': 'BSF'},
  {'id': 'bihar_police', 'name': 'Bihar Police'},
  {'id': 'cisf', 'name': 'CISF'},
  {'id': 'crpf', 'name': 'CRPF'},
  {'id': 'itbp', 'name': 'ITBP'},
  {'id': 'police_si', 'name': 'Police Sub-Inspector'},
  {'id': 'ssb', 'name': 'SSB'},
  {'id': 'ssc_gd', 'name': 'SSC-GD'},
];

List<Map<String, dynamic>> _eventsFor(String template) {
  if (template == 'army_agniveer') {
    return [
      _runningEvent('run_1600', 'दौड़'),
      _singleValueEvent('pull_ups', 'Pull-Ups', 'reps'),
      _passEvent('ditch_9ft', '9 फीट Ditch'),
      _passEvent('zigzag_balance', 'Zig-Zag Balance'),
      _singleValueEvent('long_jump', 'Long Jump', 'cm / metres'),
      _singleValueEvent('high_jump', 'High Jump', 'cm / metres'),
      _singleValueEvent('push_ups', 'Push-Ups', 'reps'),
    ];
  }
  if (['bhg', 'bihar_police', 'police_si'].contains(template)) {
    return [
      _runningEvent('run', 'दौड़'),
      _singleValueEvent('shot_put', 'गोला फेंक', 'cm / metres'),
      _singleValueEvent('high_jump', 'हाई जंप', 'cm / metres'),
      _singleValueEvent('long_jump', 'लॉन्ग जंप', 'cm / metres'),
      _passEvent('ditch_9ft', '9 फीट Ditch (optional)'),
      _passEvent('zigzag_balance', 'Zig-Zag Balance (optional)'),
    ];
  }
  return [
    _runningEvent('run', 'दौड़'),
    _singleValueEvent('pull_ups', 'Pull-Ups', 'reps'),
    _singleValueEvent('shot_put', 'Shot Put / गोला फेंक', 'cm / metres'),
    _singleValueEvent('high_jump', 'High Jump', 'cm / metres'),
    _singleValueEvent('long_jump', 'Long Jump', 'cm / metres'),
    _passEvent('ditch_9ft', '9 फीट Ditch'),
    _passEvent('zigzag_balance', 'Zig-Zag Balance'),
  ];
}

class PhysicalTrainingSheetsAdminPage extends StatefulWidget {
  const PhysicalTrainingSheetsAdminPage({super.key});

  @override
  State<PhysicalTrainingSheetsAdminPage> createState() =>
      _PhysicalTrainingSheetsAdminPageState();
}

class _PhysicalTrainingSheetsAdminPageState
    extends State<PhysicalTrainingSheetsAdminPage> {
  late Future<dynamic> batchesFuture;
  late Future<dynamic> sheetsFuture;
  String? selectedBatchId;
  String? deletingSheetId;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    sheetsFuture = _loadSheets();
  }

  Future<dynamic> _loadSheets() => context.read<SessionProvider>().api.get(
        '/physical-training-sheets',
        query: selectedBatchId == null ? null : {'batchId': selectedBatchId!},
      );

  void reload() => setState(() => sheetsFuture = _loadSheets());

  Future<String?> _batchForSheet() async {
    if (selectedBatchId != null) return selectedBatchId;
    List<dynamic> all;
    try {
      all = await batchesFuture as List<dynamic>;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }
    final active = all
        .where((raw) => raw is Map && raw['status'] == 'active')
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    if (active.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('There are no active batches available.')));
      }
      return null;
    }
    var choice = active.first['_id'].toString();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Choose the batch for this marks sheet'),
          content: DropdownButtonFormField<String>(
            initialValue: choice,
            isExpanded: true,
            items: active
                .map((batch) => DropdownMenuItem(
                      value: batch['_id'].toString(),
                      child: Text(batch['name']?.toString() ?? 'Batch'),
                    ))
                .toList(),
            onChanged: (value) => updateDialog(() {
              if (value != null) choice = value;
            }),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, choice),
                child: const Text('Continue')),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        selectedBatchId = result;
        sheetsFuture = _loadSheets();
      });
    }
    return result;
  }

  String _guessTemplate(Map<String, dynamic> batch) {
    final text =
        '${batch['name'] ?? ''} ${batch['course'] ?? ''}'.toLowerCase();
    if (text.contains('army') || text.contains('agniveer'))
      return 'army_agniveer';
    if (text.contains('home guard') || text.contains('bhg')) return 'bhg';
    if (text.contains('bihar police')) return 'bihar_police';
    if (text.contains('sub-inspector') || text.contains('daroga'))
      return 'police_si';
    if (text.contains('bsf')) return 'bsf';
    if (text.contains('cisf')) return 'cisf';
    if (text.contains('crpf')) return 'crpf';
    if (text.contains('itbp')) return 'itbp';
    if (text.contains('ssb')) return 'ssb';
    if (text.contains('ssc')) return 'ssc_gd';
    return 'army_agniveer';
  }

  Future<String?> _addCustomEvent(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add an event column'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Test name', hintText: 'e.g. 5 KM run'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _createSheet() async {
    final batchId = await _batchForSheet();
    if (batchId == null) return;
    List<dynamic> rawBatches;
    try {
      rawBatches = await batchesFuture as List<dynamic>;
    } catch (_) {
      rawBatches = [];
    }
    final matchingBatches = rawBatches
        .where((item) => item is Map && item['_id']?.toString() == batchId)
        .toList();
    final batch = matchingBatches.isEmpty ? null : matchingBatches.first;
    final suggestedTemplate = _guessTemplate(
      batch == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(batch),
    );
    var template = suggestedTemplate;
    var testDate = DateTime.now();
    final titleController = TextEditingController(
        text:
            '${_testTemplates.firstWhere((item) => item['id'] == template)['name']} Physical Test');
    final initialGroups = _eventsFor(template);
    final enabled = initialGroups.map((group) => group['id'] as String).toSet();
    final customGroups = <Map<String, dynamic>>[];
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) {
          final groups = [..._eventsFor(template), ...customGroups];
          return AlertDialog(
            title: const Text('Create batch marks sheet'),
            content: SizedBox(
              width: (MediaQuery.sizeOf(dialogContext).width - 48)
                  .clamp(280.0, 620.0),
              height: MediaQuery.sizeOf(dialogContext).height * .72,
              child: ListView(children: [
                DropdownButtonFormField<String>(
                  initialValue: template,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Recruitment / test template'),
                  items: _testTemplates
                      .map((item) => DropdownMenuItem(
                          value: item['id'], child: Text(item['name']!)))
                      .toList(),
                  onChanged: (value) => updateDialog(() {
                    if (value == null) return;
                    final previousName = _testTemplates
                        .firstWhere((item) => item['id'] == template)['name'];
                    final nextName = _testTemplates
                        .firstWhere((item) => item['id'] == value)['name'];
                    if (titleController.text.trim() ==
                        '$previousName Physical Test') {
                      titleController.text = '$nextName Physical Test';
                    }
                    template = value;
                    enabled
                      ..clear()
                      ..addAll(_eventsFor(template)
                          .map((group) => group['id'] as String));
                  }),
                ),
                TextField(
                  controller: titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Sheet title'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Test date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(testDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: testDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      updateDialog(() => testDate =
                          DateTime(picked.year, picked.month, picked.day));
                    }
                  },
                ),
                const Divider(),
                const Text(
                    'Switch on only the events you want. Event-wise marks are not entered; one overall Total Marks field is added for each student.'),
                ...groups.map((group) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: enabled.contains(group['id']),
                      title: Text(group['label'] as String),
                      subtitle: Text((group['columns'] as List)
                          .map((column) => column['label'])
                          .join('  •  ')),
                      onChanged: (value) => updateDialog(() {
                        final id = group['id'] as String;
                        if (value == true) {
                          enabled.add(id);
                        } else {
                          enabled.remove(id);
                        }
                      }),
                    )),
                OutlinedButton.icon(
                  onPressed: () async {
                    final name = await _addCustomEvent(dialogContext);
                    if (name == null) return;
                    final key = 'custom_${customGroups.length + 1}';
                    updateDialog(() {
                      customGroups
                          .add(_singleValueEvent(key, name, 'Enter a result'));
                      enabled.add(key);
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add custom event'),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final selectedGroups = groups
                      .where((group) => enabled.contains(group['id']))
                      .toList();
                  final columns = selectedGroups
                      .expand((group) => (group['columns'] as List)
                          .cast<Map<String, String>>())
                      .toList();
                  if (columns.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text('Turn on at least one event.')));
                    return;
                  }
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Enter a sheet title.')));
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'batchId': batchId,
                    'title': title,
                    'template': template,
                    'testDate': testDate.toUtc().toIso8601String(),
                    'columns': columns,
                  });
                },
                child: const Text('Create sheet'),
              ),
            ],
          );
        },
      ),
    );
    titleController.dispose();
    if (payload == null || !mounted) return;
    try {
      final created = await context
          .read<SessionProvider>()
          .api
          .post('/physical-training-sheets', payload);
      reload();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhysicalTrainingSheetEditorPage(
            sheet: Map<String, dynamic>.from(created as Map),
          ),
        ),
      );
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _openSheet(Map<String, dynamic> sheet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhysicalTrainingSheetEditorPage(sheet: sheet),
      ),
    );
    reload();
  }

  Future<void> _deleteSheet(Map<String, dynamic> sheet) async {
    final id = sheet['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final title = sheet['title']?.toString() ?? 'Physical marks sheet';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete marks sheet?'),
        content: Text(
            'Delete "$title" and all student results in this shared sheet? This cannot be undone. Individual physical assessment records will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deletingSheetId = id);
    try {
      await context
          .read<SessionProvider>()
          .api
          .delete('/physical-training-sheets/$id');
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deleted "$title". Create a new sheet when ready.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => deletingSheetId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Batch Physical Marks Sheets'),
          actions: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createSheet,
          icon: const Icon(Icons.add),
          label: const Text('Create marks sheet'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FutureBuilder<dynamic>(
              future: batchesFuture,
              builder: (context, snapshot) {
                final batches = (snapshot.data as List<dynamic>? ?? [])
                    .where((raw) => raw is Map && raw['status'] == 'active')
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: selectedBatchId ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Filter marks sheets by batch'),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All batches')),
                    ...batches.map((raw) {
                      final batch = Map<String, dynamic>.from(raw as Map);
                      return DropdownMenuItem(
                        value: batch['_id'].toString(),
                        child: Text(
                            '${batch['name'] ?? 'Batch'}${(batch['course'] ?? '').toString().isEmpty ? '' : ' • ${batch['course']}'}',
                            overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() {
                    selectedBatchId =
                        value == null || value == 'all' ? null : value;
                    sheetsFuture = _loadSheets();
                  }),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<dynamic>(
              future: sheetsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState();
                }
                if (snapshot.hasError) {
                  return ErrorState(
                      message: snapshot.error.toString(), retry: reload);
                }
                final sheets = snapshot.data as List<dynamic>? ?? [];
                if (sheets.isEmpty) {
                  return const EmptyState(
                    title: 'No batch marks sheets yet',
                    subtitle:
                        'Create a marks sheet, switch optional events on or off, then enter every student’s scores.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                  itemCount: sheets.length,
                  itemBuilder: (context, index) {
                    final sheet =
                        Map<String, dynamic>.from(sheets[index] as Map);
                    final batch = sheet['batchId'] is Map
                        ? sheet['batchId']['name']?.toString() ?? ''
                        : '';
                    final date =
                        DateTime.tryParse(sheet['testDate']?.toString() ?? '');
                    final rows = sheet['rows'] as List<dynamic>? ?? [];
                    final columns = sheet['columns'] as List<dynamic>? ?? [];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AcademyColors.mint,
                          child: Icon(Icons.table_chart,
                              color: AcademyColors.green),
                        ),
                        title:
                            Text(sheet['title']?.toString() ?? 'Physical test'),
                        subtitle: Text(
                            '$batch • ${date == null ? 'Date unavailable' : DateFormat('dd MMM yyyy').format(date.toLocal())}\n${rows.length} students • ${columns.length} active columns'),
                        isThreeLine: true,
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Delete marks sheet',
                            onPressed:
                                deletingSheetId == sheet['_id']?.toString()
                                    ? null
                                    : () => _deleteSheet(sheet),
                            icon: deletingSheetId == sheet['_id']?.toString()
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(Icons.delete_outline,
                                    color: Colors.red.shade700),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                        onTap: () => _openSheet(sheet),
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

class PhysicalTrainingSheetEditorPage extends StatefulWidget {
  final Map<String, dynamic> sheet;
  const PhysicalTrainingSheetEditorPage({super.key, required this.sheet});

  @override
  State<PhysicalTrainingSheetEditorPage> createState() =>
      _PhysicalTrainingSheetEditorPageState();
}

class _PhysicalTrainingSheetEditorPageState
    extends State<PhysicalTrainingSheetEditorPage> {
  late Map<String, dynamic> sheet;
  final Map<String, TextEditingController> _controllers = {};
  bool saving = false;

  List<dynamic> get rows => sheet['rows'] as List<dynamic>? ?? [];
  List<dynamic> get columns => sheet['columns'] as List<dynamic>? ?? [];

  @override
  void initState() {
    super.initState();
    sheet = Map<String, dynamic>.from(widget.sheet);
    _initializeControllers();
  }

  String _studentId(dynamic row) {
    final raw = row['studentId'];
    return raw is Map ? (raw['_id']?.toString() ?? '') : raw.toString();
  }

  String _controllerKey(String studentId, String columnKey) =>
      '$studentId::$columnKey';

  void _initializeControllers() {
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final studentId = _studentId(row);
      final values = row['values'] is Map
          ? Map<String, dynamic>.from(row['values'] as Map)
          : <String, dynamic>{};
      for (final rawColumn in columns) {
        final column = Map<String, dynamic>.from(rawColumn as Map);
        final key = _controllerKey(studentId, column['key'].toString());
        _controllers.putIfAbsent(
            key,
            () => TextEditingController(
                text: values[column['key']]?.toString() ?? ''));
      }
    }
  }

  TextEditingController _controller(String studentId, String key) =>
      _controllers[_controllerKey(studentId, key)] ??
      (_controllers[_controllerKey(studentId, key)] = TextEditingController());

  String _studentName(dynamic rawRow) {
    final rawStudent = rawRow['studentId'];
    final student = rawStudent is Map
        ? Map<String, dynamic>.from(rawStudent)
        : <String, dynamic>{};
    final user = student['userId'] is Map
        ? Map<String, dynamic>.from(student['userId'])
        : <String, dynamic>{};
    return user['name']?.toString() ??
        student['studentId']?.toString() ??
        'Student';
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final payloadRows = rows.map((rawRow) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final studentId = _studentId(row);
        final values = <String, String>{};
        for (final rawColumn in columns) {
          final column = Map<String, dynamic>.from(rawColumn as Map);
          final text =
              _controller(studentId, column['key'].toString()).text.trim();
          if (text.isNotEmpty) values[column['key'].toString()] = text;
        }
        return {'studentId': studentId, 'values': values};
      }).toList();
      final updated = await context.read<SessionProvider>().api.patch(
        '/physical-training-sheets/${sheet['_id']}/rows',
        {'rows': payloadRows},
      );
      if (!mounted) return;
      setState(() => sheet = Map<String, dynamic>.from(updated as Map));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch marks sheet saved.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batch = sheet['batchId'] is Map
        ? sheet['batchId']['name']?.toString() ?? ''
        : '';
    return Scaffold(
      appBar: AppBar(title: Text(sheet['title']?.toString() ?? 'Marks sheet')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving…' : 'Save all student results'),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.groups, color: AcademyColors.green),
              title: Text(batch),
              subtitle: Text(
                  '${sheet['template'] ?? ''} • ${DateFormat('dd MMM yyyy').format(DateTime.tryParse(sheet['testDate']?.toString() ?? '')?.toLocal() ?? DateTime.now())} • ${columns.length} active events/marks columns'),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const EmptyState(
                  title: 'No students in this batch',
                  subtitle: 'Add students to the batch first.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = Map<String, dynamic>.from(rows[index] as Map);
                    final studentId = _studentId(row);
                    final rowValues = row['values'] is Map
                        ? Map<String, dynamic>.from(row['values'] as Map)
                        : <String, dynamic>{};
                    final total = rowValues['total_marks'] ??
                        (columns.any((column) =>
                                column is Map && column['key'] == 'total_marks')
                            ? '—'
                            : row['totalMarks'] ?? 0);
                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: AcademyColors.mint,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(_studentName(row)),
                        subtitle: Text('Overall total marks: $total'),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        children: columns.map((rawColumn) {
                          final column =
                              Map<String, dynamic>.from(rawColumn as Map);
                          final key = column['key'].toString();
                          final controller = _controller(studentId, key);
                          if (column['type'] == 'passfail') {
                            final selected =
                                ['pass', 'fail'].contains(controller.text)
                                    ? controller.text
                                    : '';
                            return DropdownButtonFormField<String>(
                              initialValue: selected,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: column['label']?.toString()),
                              items: const [
                                DropdownMenuItem(
                                    value: '', child: Text('Not entered')),
                                DropdownMenuItem(
                                    value: 'pass', child: Text('✓ Pass')),
                                DropdownMenuItem(
                                    value: 'fail', child: Text('✗ Fail')),
                              ],
                              onChanged: (value) =>
                                  controller.text = value ?? '',
                            );
                          }
                          final isDistance = key.endsWith('_distance_km');
                          final isRunningTime = key.endsWith('_time');
                          final isOverallMarks =
                              column['type'] == 'marks' || key == 'total_marks';
                          final hint = isOverallMarks
                              ? 'Enter total marks once for this student'
                              : isDistance
                                  ? 'Enter distance in KM, e.g. 1.6'
                                  : isRunningTime
                                      ? 'Enter time, e.g. 5:30 or 330 sec'
                                      : column['type'] == 'measurement'
                                          ? 'Enter measurement / result'
                                          : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: controller,
                              keyboardType: isOverallMarks || isDistance
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true)
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: column['label']?.toString(),
                                hintText: hint,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
