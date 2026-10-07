import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    try {
      await context.read<SessionProvider>().api.post('/admin/applications/$id/review', {'action': action, if (reason.isNotEmpty) 'reason': reason});
      reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'Student approved and added to Students' : 'Application rejected')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String value(dynamic item) => item == null || item.toString().isEmpty ? '—' : item.toString();
  String date(dynamic item) {
    final parsed = DateTime.tryParse(item?.toString() ?? '');
    return parsed == null ? '—' : DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }
  Widget detail(String label, dynamic item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('$label: ${value(item)}'));

  Widget _applicationCard(Map<String, dynamic> a) {
    final batch = a['batchId'] is Map ? a['batchId']['name'] : a['batchId'];
    final photo = value(a['photo']);
    final id = a['_id'].toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(radius: 25, backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null, child: photo == '—' ? const Icon(Icons.person) : null),
          title: Text(value(a['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${value(a['email'])}\n${value(a['phone'])} • Batch: ${value(batch)}', maxLines: 2, overflow: TextOverflow.ellipsis),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            const Divider(),
            detail('Father name', a['fatherName']), detail('Mother name', a['motherName']), detail('Parent phone', a['parentPhone']), detail('Date of birth', date(a['dateOfBirth'])), detail('Address', a['address']), detail('Village', a['village']), detail('Post', a['post']), detail('Police station', a['policeStation']), detail('District', a['district']), detail('State', a['state']), detail('Postal code', a['postalCode']), detail('Height / Weight / Chest', '${value(a['heightCm'])} / ${value(a['weightKg'])} / ${value(a['chestCm'])}'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [Expanded(child: FilledButton.icon(onPressed: () => review(id, 'approve'), icon: const Icon(Icons.check), label: const Text('Approve'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => review(id, 'reject'), icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject', style: TextStyle(color: Colors.red))))]),
        ),
      ]),
    );
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Student approvals'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]), body: FutureBuilder<dynamic>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
    if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), retry: reload);
    final items = snapshot.data as List<dynamic>? ?? [];
    if (items.isEmpty) return const EmptyState(title: 'No pending applications', subtitle: 'Verified student applications will appear here.');
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) => _applicationCard(Map<String, dynamic>.from(items[index])));
  }));
}
