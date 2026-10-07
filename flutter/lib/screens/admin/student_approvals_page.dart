import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class StudentApprovalsPage extends StatefulWidget {
  const StudentApprovalsPage({super.key});
  @override State<StudentApprovalsPage> createState() => _StudentApprovalsPageState();
}

class _StudentApprovalsPageState extends State<StudentApprovalsPage> {
  late Future<dynamic> future;
  @override void initState() { super.initState(); future = _load(); }
  Future<dynamic> _load() => context.read<SessionProvider>().api.get('/admin/applications');
  void reload() => setState(() => future = _load());

  Future<void> review(String id, String action) async {
    String reason = '';
    if (action == 'reject') {
      final controller = TextEditingController();
      reason = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Reason for rejection'), content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: 'Explain what the student must correct')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Reject'))])) ?? '';
      controller.dispose();
      if (reason.length < 3) return;
    }
    try { await context.read<SessionProvider>().api.post('/admin/applications/$id/review', {'action': action, if (reason.isNotEmpty) 'reason': reason}); reload(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'Student approved and account created' : 'Application rejected'))); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }

  String value(dynamic value) => value == null || value.toString().isEmpty ? '—' : value.toString();
  Widget detail(String label, dynamic item) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('$label: ${value(item)}'));

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Student approvals'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]), body: FutureBuilder<dynamic>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
    if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), retry: reload);
    final items = snapshot.data as List<dynamic>? ?? [];
    if (items.isEmpty) return const EmptyState(title: 'No pending applications', subtitle: 'Verified student applications will appear here.');
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
      final a = Map<String, dynamic>.from(items[index]);
      final batch = a['batchId'] is Map ? a['batchId']['name'] : a['batchId'];
      final photo = value(a['photo']);
      return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 30, backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null, child: photo == '—' ? const Icon(Icons.person) : null), const SizedBox(width: 12), Expanded(child: Text(value(a['name']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)))]), const Divider(height: 24),
        detail('Email', a['email']), detail('Phone', a['phone']), detail('Batch', batch), detail('Father name', a['fatherName']), detail('Mother name', a['motherName']), detail('Parent phone', a['parentPhone']), detail('Date of birth', a['dateOfBirth']), detail('Address', a['address']), detail('Village', a['village']), detail('Post', a['post']), detail('Police station', a['policeStation']), detail('District', a['district']), detail('State', a['state']), detail('Postal code', a['postalCode']), detail('Height / Weight / Chest', '${value(a['heightCm'])} / ${value(a['weightKg'])} / ${value(a['chestCm'])}'),
        const SizedBox(height: 12), Row(children: [Expanded(child: FilledButton.icon(onPressed: () => review(a['_id'].toString(), 'approve'), icon: const Icon(Icons.check), label: const Text('Approve'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => review(a['_id'].toString(), 'reject'), icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject', style: TextStyle(color: Colors.red))))]),
      ])));
    });
  }));
}
