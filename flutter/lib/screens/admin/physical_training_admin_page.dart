import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class PhysicalTrainingAdminPage extends StatefulWidget {
  const PhysicalTrainingAdminPage({super.key});

  @override
  State<PhysicalTrainingAdminPage> createState() =>
      _PhysicalTrainingAdminPageState();
}

class _PhysicalTrainingAdminPageState extends State<PhysicalTrainingAdminPage> {
  late Future<dynamic> batchesFuture;
  late Future<dynamic> resultsFuture;
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    resultsFuture = _loadResults();
  }

  Future<dynamic> _loadResults() => context.read<SessionProvider>().api.get(
        '/physical-training-results',
        query: selectedBatchId == null ? null : {'batchId': selectedBatchId!},
      );

  Future<String?> _batchForNewResult() async {
    if (selectedBatchId != null) return selectedBatchId;
    List<dynamic> allBatches;
    try {
      allBatches = await batchesFuture as List<dynamic>;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }
    final active = allBatches
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
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Choose a batch'),
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
    if (selected != null && mounted) {
      setState(() {
        selectedBatchId = selected;
        resultsFuture = _loadResults();
      });
    }
    return selected;
  }

  void reload() => setState(() => resultsFuture = _loadResults());

  String _duration(dynamic value) {
    if (value == null) return '—';
    final seconds = (num.tryParse(value.toString()) ?? 0).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min';
  }

  Future<void> _addResult() async {
    final batchId = await _batchForNewResult();
    if (batchId == null) return;
    List<dynamic> students;
    try {
      students = await context
          .read<SessionProvider>()
          .api
          .get('/students', query: {'batchId': batchId}) as List<dynamic>;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (students.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('There are no students in this batch.')));
      return;
    }
    final run = TextEditingController();
    final beam = TextEditingController();
    final longJump = TextEditingController();
    final highJump = TextEditingController();
    final pushUps = TextEditingController();
    final sitUps = TextEditingController();
    final shuttle = TextEditingController();
    final remarks = TextEditingController();
    final form = GlobalKey<FormState>();
    String studentId = students.first['_id'].toString();
    DateTime testDate = DateTime.now();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add physical training result'),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 620.0),
            height: MediaQuery.sizeOf(context).height * .72,
            child: Form(
              key: form,
              child: ListView(children: [
                DropdownButtonFormField<String>(
                  initialValue: studentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: students.map((raw) {
                    final student = Map<String, dynamic>.from(raw as Map);
                    final user =
                        student['userId'] is Map ? student['userId'] : const {};
                    return DropdownMenuItem(
                        value: student['_id'].toString(),
                        child: Text(
                            '${user['name'] ?? 'Student'} • ${student['studentId'] ?? ''}',
                            overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (value) =>
                      update(() => studentId = value ?? studentId),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Assessment date'),
                  subtitle:
                      Text(DateFormat('EEE, dd MMM yyyy').format(testDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: testDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)));
                    if (picked != null)
                      update(() => testDate =
                          DateTime(picked.year, picked.month, picked.day));
                  },
                ),
                const Divider(),
                const Text(
                    'Enter the tests performed; all fields are optional.',
                    style: TextStyle(color: AcademyColors.muted)),
                TextFormField(
                    controller: run,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                        labelText: 'Running time',
                        hintText: '5:30, 330 sec, or 5 min 30 sec',
                        prefixIcon: Icon(Icons.directions_run))),
                TextFormField(
                    controller: beam,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Beam / pull-ups (reps)',
                        prefixIcon: Icon(Icons.fitness_center))),
                TextFormField(
                    controller: longJump,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                        labelText: 'Long jump (cm or m)',
                        hintText: '460 cm or 4.6 m',
                        prefixIcon: Icon(Icons.height))),
                TextFormField(
                    controller: highJump,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                        labelText: 'High jump (cm or m)',
                        hintText: '120 cm or 1.2 m',
                        prefixIcon: Icon(Icons.north))),
                TextFormField(
                    controller: pushUps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Push-ups (reps)',
                        prefixIcon: Icon(Icons.sports_gymnastics))),
                TextFormField(
                    controller: sitUps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Sit-ups (reps)',
                        prefixIcon: Icon(Icons.accessibility_new))),
                TextFormField(
                    controller: shuttle,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                        labelText: 'Shuttle run',
                        hintText: '1:20, 80 sec, or 1 min 20 sec',
                        prefixIcon: Icon(Icons.sync))),
                TextFormField(
                    controller: remarks,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'Coach notes (optional)',
                        prefixIcon: Icon(Icons.notes))),
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
                  double? parseDuration(String raw) {
                    final text = raw.trim().toLowerCase();
                    if (text.isEmpty) return null;
                    final clock =
                        RegExp(r'^(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)$')
                            .firstMatch(text);
                    if (clock != null) {
                      final minutes = double.parse(clock.group(1)!);
                      final seconds = double.parse(clock.group(2)!);
                      return seconds < 60 ? minutes * 60 + seconds : double.nan;
                    }
                    final minuteSeconds = RegExp(
                            r'^(\d+(?:\.\d+)?)\s*(?:m|min|mins|minute|minutes)\s*(\d+(?:\.\d+)?)?\s*(?:s|sec|secs|second|seconds)?$')
                        .firstMatch(text);
                    if (minuteSeconds != null) {
                      return double.parse(minuteSeconds.group(1)!) * 60 +
                          double.parse(minuteSeconds.group(2) ?? '0');
                    }
                    final seconds = RegExp(
                            r'^(\d+(?:\.\d+)?)\s*(?:s|sec|secs|second|seconds)?$')
                        .firstMatch(text);
                    return seconds == null
                        ? double.nan
                        : double.parse(seconds.group(1)!);
                  }

                  double? parseCentimeters(String raw) {
                    final text = raw.trim().toLowerCase();
                    if (text.isEmpty) return null;
                    final match =
                        RegExp(r'^(\d+(?:\.\d+)?)\s*(cm|m)?$').firstMatch(text);
                    if (match == null) return double.nan;
                    final value = double.parse(match.group(1)!);
                    return match.group(2) == 'm' ? value * 100 : value;
                  }

                  int? parseReps(String raw) {
                    final text = raw.trim().toLowerCase();
                    if (text.isEmpty) return null;
                    final match = RegExp(r'^(\d+)\s*(?:reps?|pull-?ups?)?$')
                        .firstMatch(text);
                    return match == null ? null : int.parse(match.group(1)!);
                  }

                  final runSeconds = parseDuration(run.text);
                  final shuttleSeconds = parseDuration(shuttle.text);
                  final metrics = <String, num?>{
                    'beamReps': parseReps(beam.text),
                    'longJumpCm': parseCentimeters(longJump.text),
                    'highJumpCm': parseCentimeters(highJump.text),
                    'pushUps': parseReps(pushUps.text),
                    'sitUps': parseReps(sitUps.text),
                  };
                  final inputs = <String, String>{
                    'beamReps': beam.text,
                    'longJumpCm': longJump.text,
                    'highJumpCm': highJump.text,
                    'pushUps': pushUps.text,
                    'sitUps': sitUps.text,
                  };
                  final enteredMetric =
                      metrics.values.any((value) => value != null) ||
                          runSeconds != null ||
                          shuttleSeconds != null;
                  final invalidMetrics = metrics.entries.any((entry) {
                    if (inputs[entry.key]!.trim().isEmpty) return false;
                    final value = entry.value;
                    return value == null ||
                        !value.isFinite ||
                        value < 0 ||
                        value > 1000;
                  });
                  bool invalidTime(String raw, double? seconds) {
                    if (raw.trim().isEmpty) return false;
                    return seconds == null ||
                        !seconds.isFinite ||
                        seconds < 0 ||
                        seconds > 86400;
                  }

                  final invalid = invalidMetrics ||
                      invalidTime(run.text, runSeconds) ||
                      invalidTime(shuttle.text, shuttleSeconds);
                  if (!enteredMetric) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Enter at least one physical result.')));
                    return;
                  }
                  if (invalid) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Check values. Enter time as mm:ss or seconds, distance in cm or m, and reps as whole numbers.')));
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'batchId': batchId,
                    'studentId': studentId,
                    'testDate': testDate.toUtc().toIso8601String(),
                    if (runSeconds != null) 'runTimeSeconds': runSeconds,
                    if (shuttleSeconds != null)
                      'shuttleRunSeconds': shuttleSeconds,
                    for (final entry in metrics.entries)
                      if (entry.value != null) entry.key: entry.value!,
                    'remarks': remarks.text.trim(),
                  });
                },
                child: const Text('Save result')),
          ],
        ),
      ),
    );
    for (final controller in [
      run,
      beam,
      longJump,
      highJump,
      pushUps,
      sitUps,
      shuttle,
      remarks
    ]) {
      controller.dispose();
    }
    if (payload == null) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .post('/physical-training-results', payload);
      reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Physical training result saved.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Physical Training Results'),
            actions: [
              IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
            ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _addResult,
            icon: const Icon(Icons.add),
            label: const Text('Add student result')),
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
                      labelText:
                          'Filter by batch (select a specific batch to add results)'),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All batches')),
                    ...batches.map((raw) {
                      final batch = Map<String, dynamic>.from(raw as Map);
                      return DropdownMenuItem(
                          value: batch['_id'].toString(),
                          child: Text(
                              '${batch['name'] ?? 'Batch'}${(batch['course'] ?? '').toString().isEmpty ? '' : ' • ${batch['course']}'}',
                              overflow: TextOverflow.ellipsis));
                    })
                  ],
                  onChanged: (value) => setState(() {
                    selectedBatchId =
                        value == null || value == 'all' ? null : value;
                    resultsFuture = _loadResults();
                  }),
                );
              },
            ),
          ),
          Expanded(
              child: FutureBuilder<dynamic>(
            future: resultsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingState();
              if (snapshot.hasError)
                return ErrorState(
                    message: snapshot.error.toString(), retry: reload);
              final records = snapshot.data as List<dynamic>? ?? [];
              if (records.isEmpty)
                return const EmptyState(
                    title: 'No results recorded',
                    subtitle:
                        'Choose a batch and add an individual student physical assessment.');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final item = Map<String, dynamic>.from(records[index] as Map);
                  final student = item['studentId'] is Map
                      ? Map<String, dynamic>.from(item['studentId'])
                      : <String, dynamic>{};
                  final user = student['userId'] is Map
                      ? Map<String, dynamic>.from(student['userId'])
                      : <String, dynamic>{};
                  final batch = item['batchId'] is Map
                      ? item['batchId']['name']?.toString() ?? ''
                      : '';
                  final date =
                      DateTime.tryParse(item['testDate']?.toString() ?? '');
                  final lines = <String>[
                    if (item['runTimeSeconds'] != null)
                      'Run ${_duration(item['runTimeSeconds'])}',
                    if (item['beamReps'] != null)
                      'Beam ${item['beamReps']} reps',
                    if (item['longJumpCm'] != null)
                      'Long jump ${item['longJumpCm']} cm',
                    if (item['highJumpCm'] != null)
                      'High jump ${item['highJumpCm']} cm',
                    if (item['pushUps'] != null) 'Push-ups ${item['pushUps']}',
                    if (item['sitUps'] != null) 'Sit-ups ${item['sitUps']}',
                    if (item['shuttleRunSeconds'] != null)
                      'Shuttle ${_duration(item['shuttleRunSeconds'])}',
                  ];
                  return Card(
                      child: ExpansionTile(
                    leading: const CircleAvatar(
                        backgroundColor: AcademyColors.mint,
                        child: Icon(Icons.fitness_center,
                            color: AcademyColors.green)),
                    title: Text(user['name']?.toString() ?? 'Student'),
                    subtitle: Text(
                        '${student['studentId'] ?? '—'} • $batch\n${date == null ? 'Date unavailable' : DateFormat('dd MMM yyyy').format(date.toLocal())} • ${lines.join('  |  ')}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    children: [
                      if (lines.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: lines
                                        .map((line) => Chip(label: Text(line)))
                                        .toList()))),
                      if ((item['remarks'] ?? '').toString().trim().isNotEmpty)
                        ListTile(
                            leading: const Icon(Icons.notes),
                            title: const Text('Coach notes'),
                            subtitle: Text(item['remarks'].toString())),
                    ],
                  ));
                },
              );
            },
          )),
        ]),
      );
}
