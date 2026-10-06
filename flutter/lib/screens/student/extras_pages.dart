import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';
import '../admin/fees_management_page.dart';

String _formatLocalDateTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? ''
      : DateFormat('dd MMM yyyy • h:mm a').format(date.toLocal());
}

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/notices');
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/notices'));

  Future<void> addNotice() async {
    final api = context.read<SessionProvider>().api;
    List<dynamic> batches;
    try {
      batches = await api.get('/batches') as List<dynamic>;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    final active = batches
        .where((batch) => batch is Map && batch['status'] == 'active')
        .toList();
    final title = TextEditingController();
    final description = TextEditingController();
    final form = GlobalKey<FormState>();
    String batchId = '';
    String priority = 'normal';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('New academy notice'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Notice message *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a message'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: batchId,
                  decoration: const InputDecoration(labelText: 'Send to'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('All active students')),
                    ...active.map((item) => DropdownMenuItem<String>(
                          value: item['_id'].toString(),
                          child: Text(item['name']?.toString() ?? 'Batch'),
                        )),
                  ],
                  onChanged: (value) => update(() => batchId = value ?? ''),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                        value: 'important', child: Text('Important')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) =>
                      update(() => priority = value ?? 'normal'),
                ),
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
                Navigator.pop(dialogContext, {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'priority': priority,
                  if (batchId.isNotEmpty) 'batchId': batchId,
                });
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;
    try {
      final result = await api.post('/notices', values);
      reload();
      if (mounted) {
        final warning = result is Map ? result['notificationWarning'] : null;
        final sent = result is Map ? result['notificationsSent'] ?? 0 : 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(warning?.toString() ??
              'Notice published. $sent students notified.'),
        ));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<SessionProvider>().isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Notices'), actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
      ]),
      floatingActionButton: admin
          ? FloatingActionButton(
              onPressed: addNotice, child: const Icon(Icons.add))
          : null,
      body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final notices = snapshot.data as List<dynamic>? ?? [];
            if (notices.isEmpty)
              return const EmptyState(
                  title: 'No notices yet',
                  subtitle: 'New academy announcements will appear here.');
            return ListView(
                padding: const EdgeInsets.all(14),
                children: notices
                    .map((notice) => Card(
                            child: ListTile(
                          isThreeLine: true,
                          leading: Icon(
                              notice['priority'] == 'urgent'
                                  ? Icons.priority_high
                                  : Icons.campaign_outlined,
                              color: notice['priority'] == 'urgent'
                                  ? Colors.red
                                  : AcademyColors.green),
                          title: Text(notice['title'] ?? ''),
                          subtitle: Text(
                              '${notice['description'] ?? ''}\n${notice['batchId'] is Map ? notice['batchId']['name'] : 'All batches'} • ${_formatLocalDateTime(notice['publishedAt'])}'),
                        )))
                    .toList());
          }),
    );
  }
}

class LegacyFeesPage extends StatefulWidget {
  const LegacyFeesPage({super.key});
  @override
  State<LegacyFeesPage> createState() => _LegacyFeesPageState();
}

class _LegacyFeesPageState extends State<LegacyFeesPage> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/fees');
  }

  void reload() =>
      setState(() => future = context.read<SessionProvider>().api.get('/fees'));

  Future<void> addFee() async {
    final api = context.read<SessionProvider>().api;
    List<dynamic> students;
    try {
      students = await api.get('/students') as List<dynamic>;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (students.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a student first.')));
      return;
    }
    final totalFees = TextEditingController();
    final paidAmount = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    String? selectedStudent = students.first['_id']?.toString();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Create fee record'),
          content: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStudent,
                decoration: const InputDecoration(labelText: 'Student'),
                items: students.map((profile) {
                  final student =
                      profile['userId'] is Map ? profile['userId'] : {};
                  return DropdownMenuItem<String>(
                    value: profile['_id'].toString(),
                    child: Text(
                        '${student['name'] ?? 'Student'} • ${profile['studentId'] ?? ''}'),
                  );
                }).toList(),
                onChanged: (value) => update(() => selectedStudent = value),
              ),
              Row(children: [
                Expanded(
                    child: TextFormField(
                  controller: totalFees,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total fee (₹)'),
                  validator: (value) {
                    final parsed = num.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Enter an amount above zero'
                        : null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                  controller: paidAmount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Paid now (₹)'),
                  validator: (value) {
                    final paid = num.tryParse(value ?? '');
                    final total = num.tryParse(totalFees.text);
                    if (paid == null || paid < 0) return 'Invalid amount';
                    if (total != null && paid > total) return 'Over total';
                    return null;
                  },
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false) ||
                    selectedStudent == null) return;
                Navigator.pop(dialogContext, {
                  'studentId': selectedStudent!,
                  'totalFees': totalFees.text,
                  'paidAmount': paidAmount.text,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;
    try {
      await api.post('/fees', {
        'studentId': values['studentId'],
        'totalFees': num.tryParse(values['totalFees']!) ?? 0,
        'paidAmount': num.tryParse(values['paidAmount']!) ?? 0,
      });
      reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> recordPayment(String id) async {
    final amount = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Record fee payment'),
              content: TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Amount received')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, amount.text),
                    child: const Text('Record')),
              ],
            ));
    if (value == null) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .post('/fees/$id/payments', {'amount': num.tryParse(value) ?? 0});
      reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<SessionProvider>().isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Fees Management'), actions: [
        IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
      ]),
      floatingActionButton: admin
          ? FloatingActionButton(
              onPressed: addFee, child: const Icon(Icons.add))
          : null,
      body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final fees = snapshot.data as List<dynamic>? ?? [];
            if (fees.isEmpty)
              return const EmptyState(
                  title: 'No fee records',
                  subtitle: 'Fee totals and payment status will appear here.');
            return ListView(
                padding: const EdgeInsets.all(14),
                children: fees.map((fee) {
                  final paid = fee['paidAmount'] ?? 0;
                  final total = fee['totalFees'] ?? 0;
                  final student = fee['studentId'];
                  final studentName = student is Map
                      ? (student['userId']?['name'] ?? 'Student')
                      : 'My fees';
                  return Card(
                      child: ListTile(
                    isThreeLine: true,
                    leading: const CircleAvatar(
                        backgroundColor: AcademyColors.mint,
                        child: Icon(Icons.account_balance_wallet_outlined,
                            color: AcademyColors.green)),
                    title: Text(studentName.toString()),
                    subtitle: Text(
                        'Total: $total • Paid: $paid • Remaining: ${fee['remainingAmount'] ?? ''}\nStatus: ${fee['status'] ?? 'due'}'),
                    trailing: admin
                        ? IconButton(
                            onPressed: () => recordPayment(fee['_id']),
                            icon: const Icon(Icons.add_card))
                        : null,
                  ));
                }).toList());
          }),
    );
  }
}

class FeesPage extends StatelessWidget {
  const FeesPage({super.key});

  @override
  Widget build(BuildContext context) => const FeesManagementPage();
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<dynamic> future;
  Timer? refreshTimer;
  @override
  void initState() {
    super.initState();
    future = context.read<SessionProvider>().api.get('/notifications');
    refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) reload();
    });
  }

  void reload() => setState(
      () => future = context.read<SessionProvider>().api.get('/notifications'));

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh))
        ]),
        body: FutureBuilder<dynamic>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const LoadingState();
              if (snapshot.hasError)
                return ErrorState(
                    message: snapshot.error.toString(), retry: reload);
              final notifications = snapshot.data as List<dynamic>? ?? [];
              if (notifications.isEmpty)
                return const EmptyState(
                    title: 'All caught up',
                    subtitle: 'Academy notices and updates will appear here.');
              return RefreshIndicator(
                onRefresh: () async {
                  final next =
                      context.read<SessionProvider>().api.get('/notifications');
                  setState(() => future = next);
                  await next;
                },
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: notifications
                      .map((notification) => Card(
                              child: ListTile(
                            leading: Icon(
                                notification['readAt'] == null
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none,
                                color: notification['readAt'] == null
                                    ? AcademyColors.green
                                    : AcademyColors.muted),
                            title: Text(notification['title'] ?? ''),
                            subtitle: Text(
                                '${notification['message'] ?? ''}${_formatLocalDateTime(notification['createdAt']).isEmpty ? '' : '\n${_formatLocalDateTime(notification['createdAt'])}'}'),
                            trailing: notification['readAt'] == null
                                ? const Icon(Icons.circle,
                                    size: 9, color: AcademyColors.green)
                                : null,
                            onTap: () async {
                              if (notification['readAt'] == null) {
                                await context.read<SessionProvider>().api.patch(
                                    '/notifications/${notification['_id']}/read',
                                    {});
                                reload();
                              }
                            },
                          )))
                      .toList(),
                ),
              );
            }),
      );
}
