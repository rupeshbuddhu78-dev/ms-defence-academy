import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class FeesManagementPage extends StatefulWidget {
  const FeesManagementPage({super.key});

  @override
  State<FeesManagementPage> createState() => _FeesManagementPageState();
}

class _FeesManagementPageState extends State<FeesManagementPage> {
  late Future<dynamic> future;
  late Future<dynamic> summaryFuture;
  late Future<dynamic> batchesFuture;
  String? selectedBatchId;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    future = _loadFees();
    summaryFuture = _loadSummary();
  }

  Future<dynamic> _loadFees() => context.read<SessionProvider>().api.get(
        '/fees',
        query: selectedBatchId == null ? null : {'batchId': selectedBatchId!},
      );
  Future<dynamic> _loadSummary() => context.read<SessionProvider>().api.get(
        '/fees/summary',
        query: selectedBatchId == null ? null : {'batchId': selectedBatchId!},
      );

  void reload() => setState(() {
        future = _loadFees();
        summaryFuture = _loadSummary();
      });

  Future<void> addFee() async {
    final api = context.read<SessionProvider>().api;
    List<dynamic> batches;
    try {
      batches = await api.get('/batches') as List<dynamic>;
    } catch (error) {
      _message(error.toString());
      return;
    }
    final activeBatches = batches
        .where((batch) => batch is Map && batch['status'] == 'active')
        .toList();
    if (activeBatches.isEmpty) {
      _message('Create an active batch before adding a fee record.');
      return;
    }
    final initialBatch = activeBatches
            .any((batch) => batch['_id']?.toString() == selectedBatchId)
        ? selectedBatchId!
        : activeBatches.first['_id'].toString();
    String batchId = initialBatch;
    String? selectedStudent;
    final search = TextEditingController();
    final totalFees = TextEditingController();
    final paidAmount = TextEditingController(text: '0');
    final transactionId = TextEditingController();
    String paymentMethod = 'cash';
    final form = GlobalKey<FormState>();
    Future<dynamic> studentsFuture = api.get(
      '/students',
      query: {'batchId': batchId},
    );
    final size = MediaQuery.sizeOf(context);

    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add fee record'),
          content: Form(
            key: form,
            child: SizedBox(
              width: (size.width - 48).clamp(280.0, 720.0),
              height: size.height * .70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: batchId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Batch *'),
                    items: activeBatches
                        .map((item) => DropdownMenuItem<String>(
                              value: item['_id'].toString(),
                              child: Text(item['name']?.toString() ?? 'Batch'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      update(() {
                        batchId = value;
                        selectedStudent = null;
                        search.clear();
                        studentsFuture = api.get(
                          '/students',
                          query: {'batchId': batchId},
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Find student by name or ID',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => update(() {
                      final query = <String, String>{'batchId': batchId};
                      if (value.trim().isNotEmpty) query['q'] = value.trim();
                      studentsFuture = api.get('/students', query: query);
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text('Select a student',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: FutureBuilder<dynamic>(
                      future: studentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text(snapshot.error.toString()));
                        }
                        final students = snapshot.data as List<dynamic>? ?? [];
                        if (students.isEmpty) {
                          return const Center(
                              child: Text('No students in this batch match.'));
                        }
                        return RadioGroup<String>(
                          groupValue: selectedStudent,
                          onChanged: (value) =>
                              update(() => selectedStudent = value),
                          child: ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final profile =
                                  Map<String, dynamic>.from(students[index]);
                              final user = profile['userId'] is Map
                                  ? Map<String, dynamic>.from(profile['userId'])
                                  : <String, dynamic>{};
                              final id = profile['_id']?.toString() ?? '';
                              return RadioListTile<String>(
                                dense: true,
                                value: id,
                                title:
                                    Text(user['name']?.toString() ?? 'Student'),
                                subtitle: Text(
                                    '${profile['studentId'] ?? '—'} • ${user['phone'] ?? ''}'),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: totalFees,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Total fee (₹) *'),
                        validator: (value) {
                          final amount = num.tryParse(value ?? '');
                          return amount == null || amount <= 0
                              ? 'Enter amount > 0'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: paidAmount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Paid now (₹)'),
                        validator: (value) {
                          final paid = num.tryParse(value ?? '');
                          final total = num.tryParse(totalFees.text);
                          if (paid == null || paid < 0) return 'Invalid amount';
                          if (total != null && paid > total)
                            return 'Over total';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (value) => update(() {
                      paymentMethod = value ?? 'cash';
                      if (paymentMethod == 'cash') transactionId.clear();
                    }),
                  ),
                  if (paymentMethod == 'online')
                    TextFormField(
                      controller: transactionId,
                      decoration: const InputDecoration(labelText: 'Online transaction ID *'),
                      validator: (value) => paymentMethod == 'online' && (value == null || value.trim().isEmpty)
                          ? 'Enter transaction ID'
                          : null,
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
              onPressed: () {
                if (!(form.currentState?.validate() ?? false) ||
                    selectedStudent == null) {
                  if (selectedStudent == null) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Select a student.')));
                  }
                  return;
                }
                Navigator.pop(dialogContext, {
                  'batchId': batchId,
                  'studentId': selectedStudent!,
                  'totalFees': totalFees.text,
                  'paidAmount': paidAmount.text,
                  'paymentMethod': paymentMethod,
                  'transactionId': transactionId.text.trim(),
                });
              },
              child: const Text('Save fee'),
            ),
          ],
        ),
      ),
    );
    search.dispose();
    totalFees.dispose();
    paidAmount.dispose();
    transactionId.dispose();
    if (values == null) return;
    try {
      await api.post('/fees', {
        'batchId': values['batchId'],
        'studentId': values['studentId'],
        'totalFees': num.tryParse(values['totalFees']!) ?? 0,
        'paidAmount': num.tryParse(values['paidAmount']!) ?? 0,
        'paymentMethod': values['paymentMethod'],
        'transactionId': values['transactionId'],
      });
      reload();
      _message('Fee record added.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> editFee(Map<String, dynamic> fee) async {
    final total = TextEditingController(text: '${fee['totalFees'] ?? 0}');
    final paid = TextEditingController(text: '${fee['paidAmount'] ?? 0}');
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit fee record'),
        content: Form(
          key: form,
          child: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 560.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: total,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total fee (₹)'),
                validator: (value) =>
                    num.tryParse(value ?? '') == null || num.parse(value!) < 0
                        ? 'Enter a valid non-negative amount'
                        : null,
              ),
              TextFormField(
                controller: paid,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Paid amount (₹)'),
                validator: (value) {
                  final paidValue = num.tryParse(value ?? '');
                  final totalValue = num.tryParse(total.text);
                  if (paidValue == null || paidValue < 0)
                    return 'Invalid amount';
                  if (totalValue != null && paidValue > totalValue) {
                    return 'Paid cannot exceed total';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text('Changes are recorded in the fee adjustment history.'),
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
                'totalFees': total.text,
                'paidAmount': paid.text,
              });
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    total.dispose();
    paid.dispose();
    if (values == null) return;
    try {
      await context.read<SessionProvider>().api.patch('/fees/${fee['_id']}', {
        'totalFees': num.tryParse(values['totalFees']!) ?? 0,
        'paidAmount': num.tryParse(values['paidAmount']!) ?? 0,
      });
      reload();
      _message('Fee record updated.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> deleteFee(Map<String, dynamic> fee) async {
    final student = fee['studentId'] is Map ? fee['studentId'] : const {};
    final user = student['userId'] is Map ? student['userId'] : const {};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete fee record?'),
        content: Text(
            'Permanently delete the fee ledger for ${user['name'] ?? 'this student'}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<SessionProvider>().api.delete('/fees/${fee['_id']}');
      reload();
      _message('Fee record deleted.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> recordPayment(String id) async {
    final amount = TextEditingController();
    final transactionId = TextEditingController();
    final note = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();
    final form = GlobalKey<FormState>();
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Record fee payment'),
          content: Form(
            key: form,
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 560.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount received (₹) *'),
                  validator: (value) => num.tryParse(value ?? '') == null || num.parse(value!) <= 0
                      ? 'Enter a positive amount'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment method *'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                  ],
                  onChanged: (value) => update(() {
                    paymentMethod = value ?? 'cash';
                    if (paymentMethod == 'cash') transactionId.clear();
                  }),
                ),
                if (paymentMethod == 'online')
                  TextFormField(
                    controller: transactionId,
                    decoration: const InputDecoration(labelText: 'Online transaction ID *'),
                    validator: (value) => paymentMethod == 'online' && (value == null || value.trim().isEmpty)
                        ? 'Enter transaction ID'
                        : null,
                  ),
                TextFormField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Payment date and time'),
                  subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: paymentDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(paymentDate),
                    );
                    if (time != null) update(() => paymentDate = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute));
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, {
                  'amount': num.tryParse(amount.text) ?? 0,
                  'paymentMethod': paymentMethod,
                  'transactionId': transactionId.text.trim(),
                  'note': note.text.trim(),
                  'paymentDate': paymentDate.toUtc().toIso8601String(),
                });
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    transactionId.dispose();
    note.dispose();
    if (value == null) return;
    try {
      await context.read<SessionProvider>().api.post('/fees/$id/payments', value);
      reload();
      _message('Payment recorded.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> showPaymentHistory(Map<String, dynamic> fee) async {
    final student = fee['studentId'] is Map ? Map<String, dynamic>.from(fee['studentId']) : <String, dynamic>{};
    final user = student['userId'] is Map ? Map<String, dynamic>.from(student['userId']) : <String, dynamic>{};
    final payments = fee['payments'] is List ? fee['payments'] as List<dynamic> : const <dynamic>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${user['name'] ?? 'Student'} — payment history'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 560.0),
          child: payments.isEmpty
              ? const Text('No payments recorded yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final payment = payments[index] is Map ? Map<String, dynamic>.from(payments[index]) : <String, dynamic>{};
                    final date = DateTime.tryParse(payment['paymentDate']?.toString() ?? '')?.toLocal();
                    final method = (payment['paymentMethod'] ?? 'cash').toString().toUpperCase();
                    final transaction = payment['transactionId']?.toString() ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('₹${payment['amount'] ?? 0} • $method'),
                      subtitle: Text('${date == null ? 'Date not set' : DateFormat('dd MMM yyyy, hh:mm a').format(date)}${transaction.isEmpty ? '' : '\nTransaction ID: $transaction'}${(payment['note'] ?? '').toString().isEmpty ? '' : '\n${payment['note']}'}'),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          ? FloatingActionButton.extended(
              onPressed: addFee,
              icon: const Icon(Icons.add),
              label: const Text('Add fee'),
            )
          : null,
      body: Column(children: [
        if (admin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FutureBuilder<dynamic>(
              future: batchesFuture,
              builder: (context, snapshot) {
                final batches = snapshot.data as List<dynamic>? ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: selectedBatchId ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Filter fees by batch',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All batches')),
                    ...batches.map((batch) => DropdownMenuItem<String>(
                          value: batch['_id'].toString(),
                          child: Text(batch['name']?.toString() ?? 'Batch'),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedBatchId = value == 'all' ? null : value;
                      future = _loadFees();
                      summaryFuture = _loadSummary();
                    });
                  },
                );
              },
            ),
          ),
        if (admin)
          FutureBuilder<dynamic>(
            future: summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data is Map
                  ? Map<String, dynamic>.from(snapshot.data)
                  : <String, dynamic>{};
              String money(dynamic value) => '₹${value ?? 0}';
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  Expanded(child: _summaryCard('Total income', money(summary['totalIncome']), AcademyColors.green, Icons.trending_up)),
                  const SizedBox(width: 8),
                  Expanded(child: _summaryCard('Total due', money(summary['totalDue']), Colors.red.shade700, Icons.pending_actions)),
                ]),
              );
            },
          ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingState();
              }
              if (snapshot.hasError) {
                return ErrorState(
                    message: snapshot.error.toString(), retry: reload);
              }
              final fees = snapshot.data as List<dynamic>? ?? [];
              if (fees.isEmpty) {
                return const EmptyState(
                  title: 'No fee records',
                  subtitle: 'Fee totals and payment status will appear here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 92),
                itemCount: fees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final fee = Map<String, dynamic>.from(fees[index]);
                  final student = fee['studentId'] is Map
                      ? Map<String, dynamic>.from(fee['studentId'])
                      : <String, dynamic>{};
                  final user = student['userId'] is Map
                      ? Map<String, dynamic>.from(student['userId'])
                      : <String, dynamic>{};
                  final feeBatch = fee['batchId'] is Map
                      ? fee['batchId']['name']?.toString()
                      : (student['batchId'] is Map
                          ? student['batchId']['name']?.toString()
                          : null);
                  final total = num.tryParse('${fee['totalFees'] ?? 0}') ?? 0;
                  final paid = num.tryParse('${fee['paidAmount'] ?? 0}') ?? 0;
                  final remaining =
                      num.tryParse('${fee['remainingAmount'] ?? ''}') ??
                          (total - paid).clamp(0, total);
                  final photo = (student['photo'] ?? '').toString();
                  final hasFeeRecord = fee['_id']?.toString().isNotEmpty == true;
                  return Card(
                    child: ListTile(
                      isThreeLine: true,
                      leading: CircleAvatar(
                        backgroundColor: AcademyColors.mint,
                        backgroundImage:
                            photo.startsWith('http') ? NetworkImage(photo) : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.account_balance_wallet_outlined,
                                color: AcademyColors.green)
                            : null,
                      ),
                      title: Text(admin
                          ? (user['name']?.toString() ?? 'Student')
                          : 'My fee record'),
                      onTap: () => showPaymentHistory(fee),
                      subtitle: Text(
                        '${student['studentId'] ?? ''}${feeBatch == null ? '' : ' • $feeBatch'}\n'
                        '${hasFeeRecord ? '' : 'No fee record • '}'
                        'Total ₹$total • Paid ₹$paid • Due ₹$remaining\n'
                        'Status: ${(fee['status'] ?? 'due').toString().toUpperCase()}',
                      ),
                      trailing: admin && hasFeeRecord
                          ? PopupMenuButton<String>(
                              tooltip: 'Fee actions',
                              onSelected: (action) {
                                if (action == 'pay') {
                                  recordPayment(fee['_id'].toString());
                                } else if (action == 'edit') {
                                  editFee(fee);
                                } else if (action == 'delete') {
                                  deleteFee(fee);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'pay',
                                    child: Text('Record payment')),
                                PopupMenuItem(
                                    value: 'edit', child: Text('Edit fee')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete fee')),
                              ],
                            )
                          : null,
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

  Widget _summaryCard(String title, String value, Color color, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AcademyColors.muted)),
              Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color)),
            ])),
          ]),
        ),
      );
}
