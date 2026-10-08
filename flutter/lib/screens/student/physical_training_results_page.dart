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
    future =
        context.read<SessionProvider>().api.get('/physical-training-results');
  }

  void reload() => setState(() {
        future = context
            .read<SessionProvider>()
            .api
            .get('/physical-training-results');
      });

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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('Physical Training Results'), actions: [
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
            final records = snapshot.data as List<dynamic>? ?? [];
            if (records.isEmpty) {
              return const EmptyState(
                title: 'No physical results yet',
                subtitle:
                    'Your academy-recorded running, beam and jump results will appear here.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.shield_outlined, color: AcademyColors.green),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              'Your physical training history is private to your student account.')),
                    ]),
                  ),
                ),
                ...records.map((raw) {
                  final item = Map<String, dynamic>.from(raw as Map);
                  final date =
                      DateTime.tryParse(item['testDate']?.toString() ?? '');
                  final batch = item['batchId'] is Map
                      ? item['batchId']['name']?.toString() ?? ''
                      : '';
                  final metrics = <Widget>[
                    if (item['runTimeSeconds'] != null)
                      _metric('Running time', _duration(item['runTimeSeconds']),
                          Icons.directions_run),
                    if (item['beamReps'] != null)
                      _metric('Beam / pull-ups', '${item['beamReps']} reps',
                          Icons.fitness_center),
                    if (item['longJumpCm'] != null)
                      _metric('Long jump', '${item['longJumpCm']} cm',
                          Icons.height),
                    if (item['highJumpCm'] != null)
                      _metric(
                          'High jump', '${item['highJumpCm']} cm', Icons.north),
                    if (item['pushUps'] != null)
                      _metric('Push-ups', '${item['pushUps']} reps',
                          Icons.sports_gymnastics),
                    if (item['sitUps'] != null)
                      _metric('Sit-ups', '${item['sitUps']} reps',
                          Icons.accessibility_new),
                    if (item['shuttleRunSeconds'] != null)
                      _metric('Shuttle run',
                          _duration(item['shuttleRunSeconds']), Icons.sync),
                  ];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const CircleAvatar(
                                  backgroundColor: AcademyColors.mint,
                                  child: Icon(Icons.emoji_events_outlined,
                                      color: AcademyColors.green)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        date == null
                                            ? 'Training assessment'
                                            : DateFormat('EEE, dd MMM yyyy')
                                                .format(date.toLocal()),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    if (batch.isNotEmpty)
                                      Text(batch,
                                          style: const TextStyle(
                                              color: AcademyColors.muted)),
                                  ])),
                            ]),
                            const SizedBox(height: 14),
                            ...metrics.map((metric) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: metric)),
                            if ((item['remarks'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const Divider(),
                              Text('Coach notes',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(item['remarks'].toString()),
                            ],
                          ]),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
}
