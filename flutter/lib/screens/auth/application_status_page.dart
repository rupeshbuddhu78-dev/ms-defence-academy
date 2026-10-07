import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';

class ApplicationStatusPage extends StatelessWidget {
  const ApplicationStatusPage({super.key});

  String _value(dynamic value) => value == null || value.toString().isEmpty
      ? 'Not provided'
      : value.toString();
  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not provided' : DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  Future<void> _edit(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final app = session.application!;
    const keys = [
      'name', 'phone', 'fatherName', 'motherName', 'parentPhone', 'address',
      'village', 'post', 'policeStation', 'district', 'state', 'postalCode',
      'dateOfBirth', 'heightCm', 'weightKg', 'chestCm'
    ];
    final controllers = <String, TextEditingController>{
      for (final key in keys)
        key: TextEditingController(
            text: _value(app[key]) == 'Not provided' ? '' : _value(app[key])),
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit application details'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width * .85,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final key in keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controllers[key],
                      decoration: InputDecoration(
                          labelText: key == 'dateOfBirth'
                              ? 'Date of birth (YYYY-MM-DD)'
                              : key),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              for (final entry in controllers.entries)
                entry.key: entry.value.text.trim(),
            }),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) controller.dispose();
    if (result == null || !context.mounted) return;
    final ok = await session.resubmitApplication(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Application resubmitted for admin review.'
              : (session.error ?? 'Could not resubmit'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<SessionProvider>().application!;
    final session = context.read<SessionProvider>();
    final rejected = app['status'] == 'rejected';
    final batch = app['batchId'] is Map
        ? app['batchId']['name']
        : app['batchId'];
    final details = <String, dynamic>{
      'Name': app['name'],
      'Email': app['email'],
      'Phone': app['phone'],
      'Batch': batch,
      'Father name': app['fatherName'],
      'Mother name': app['motherName'],
      'Parent phone': app['parentPhone'],
      'Date of birth': _date(app['dateOfBirth']),
      'Address': app['address'],
      'Village': app['village'],
      'Post': app['post'],
      'Police station': app['policeStation'],
      'District': app['district'],
      'State': app['state'],
      'Postal code': app['postalCode'],
      'Height': app['heightCm'],
      'Weight': app['weightKg'],
      'Chest': app['chestCm'],
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application status'),
        actions: [
          IconButton(
              tooltip: 'Logout',
              onPressed: session.logout,
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: rejected ? Colors.red.shade50 : AcademyColors.mint,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(rejected ? Icons.edit_note : Icons.hourglass_top,
                      size: 48,
                      color: rejected ? Colors.red : AcademyColors.green),
                  const SizedBox(height: 8),
                  Text(
                    rejected
                        ? 'Application needs correction'
                        : 'Waiting for verification',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejected
                        ? 'Admin rejected this application. Correct the details and resubmit.'
                        : 'Your application has been submitted. Please wait while admin verifies it.',
                    textAlign: TextAlign.center,
                  ),
                  if (rejected &&
                      _value(app['rejectionReason']) != 'Not provided') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Admin message: ${app['rejectionReason']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (rejected) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                        onPressed: () => _edit(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit & resubmit')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Submitted details',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: details.entries
                  .map((entry) => ListTile(
                        dense: true,
                        title: Text(entry.key,
                            style: const TextStyle(
                                color: AcademyColors.muted, fontSize: 12)),
                        subtitle: Text(_value(entry.value),
                            style: const TextStyle(fontSize: 16)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: session.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout')),
        ],
      ),
    );
  }
}
