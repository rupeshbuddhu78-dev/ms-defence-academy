import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class SecurityLogsPage extends StatefulWidget {
  const SecurityLogsPage({super.key});
  @override
  State<SecurityLogsPage> createState() => _SecurityLogsPageState();
}

class _SecurityLogsPageState extends State<SecurityLogsPage> {
  late Future<dynamic> future;
  @override
  void initState() { super.initState(); future = _load(); }
  Future<dynamic> _load() => context.read<SessionProvider>().api.get('/security/logs', query: {'limit': '200'});
  void reload() => setState(() => future = _load());

  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return parsed == null ? '—' : DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security logs'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
        if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), retry: reload);
        final logs = (snapshot.data as List? ?? []).cast<dynamic>();
        if (logs.isEmpty) return const Center(child: Text('No security events yet.'));
        return RefreshIndicator(onRefresh: () async => reload(), child: ListView.separated(
          padding: const EdgeInsets.all(14), itemCount: logs.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final item = Map<String, dynamic>.from(logs[index]);
            final user = item['userId'] is Map ? Map<String, dynamic>.from(item['userId']) : const <String, dynamic>{};
            final success = item['event'] == 'login_success';
            final reset = item['event'].toString().startsWith('password_reset');
            final color = success ? AcademyColors.green : (reset ? const Color(0xFF15558A) : Colors.redAccent);
            final title = item['event'] == 'login_success' ? 'Login successful' : item['event'] == 'login_failed' ? 'Login failed' : item['event'] == 'password_reset_requested' ? 'Password reset requested' : 'Password reset completed';
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(reset ? Icons.lock_reset : Icons.login, color: color)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${user['name'] ?? item['email'] ?? 'Unknown user'} • ${item['role'] ?? 'unknown'}\nIP: ${item['ip'] ?? '—'}\n${date(item['createdAt'])}'),
              isThreeLine: true,
            ));
          },
        ));
      },
    ),
  );
}
