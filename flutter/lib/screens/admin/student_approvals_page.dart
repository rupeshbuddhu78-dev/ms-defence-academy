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
    try { await context.read<SessionProvider>().api.post('/admin/applications/$id/review', {'action': action}); reload(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'Student approved and account created' : 'Application rejected'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Student approvals'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]), body: FutureBuilder<dynamic>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
    if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), retry: reload);
    final items = snapshot.data as List<dynamic>? ?? [];
    if (items.isEmpty) return const EmptyState(title: 'No pending applications', subtitle: 'Verified student applications will appear here.');
    return ListView(padding: const EdgeInsets.all(12), children: items.map((item) { final a = Map<String,dynamic>.from(item); final batch = a['batchId'] is Map ? a['batchId']['name'] : ''; return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [CircleAvatar(backgroundImage: (a['photo'] ?? '').toString().startsWith('http') ? NetworkImage(a['photo']) : null, child: (a['photo'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null), const SizedBox(width: 12), Expanded(child: Text(a['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]), const SizedBox(height: 8), Text('${a['email']} • ${a['phone']}\nBatch: $batch\nFather: ${a['fatherName'] ?? ''}\nAddress: ${a['address'] ?? ''}'), const SizedBox(height: 10), Row(children: [Expanded(child: FilledButton.icon(onPressed: () => review(a['_id'].toString(), 'approve'), icon: const Icon(Icons.check), label: const Text('Approve'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => review(a['_id'].toString(), 'reject'), icon: const Icon(Icons.close), label: const Text('Reject', style: TextStyle(color: Colors.red))))])]))); }).toList());
  }));
}
