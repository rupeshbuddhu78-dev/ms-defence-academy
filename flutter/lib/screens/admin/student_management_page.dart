import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

class StudentDirectoryPage extends StatefulWidget {
  const StudentDirectoryPage({super.key});

  @override
  State<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends State<StudentDirectoryPage> {
  final search = TextEditingController();
  late Future<dynamic> future;
  late Future<dynamic> batchesFuture;
  String? selectedBatchId;
  bool _uploadingPhoto = false;
  double _photoUploadProgress = 0;

  @override
  void initState() {
    super.initState();
    batchesFuture = context.read<SessionProvider>().api.get('/batches');
    future = _load();
  }

  Future<dynamic> _load() {
    final query = <String, String>{};
    if (search.text.trim().isNotEmpty) query['q'] = search.text.trim();
    if (selectedBatchId != null) query['batchId'] = selectedBatchId!;
    return context.read<SessionProvider>().api.get(
          '/students',
          query: query.isEmpty ? null : query,
        );
  }

  void reload() => setState(() => future = _load());

  void _setPhotoProgress(int sent, int total) {
    if (!mounted) return;
    setState(() => _photoUploadProgress =
        total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0).toDouble());
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    final api = context.read<SessionProvider>().api;
    try {
      final allBatches = await api.get('/batches') as List<dynamic>;
      final batches = allBatches
          .where((batch) => batch is Map && batch['status'] == 'active')
          .toList();
      if (batches.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Create an active batch before adding students.'),
          ));
        }
        return;
      }
      final values = await showStudentAdmissionForm(context, batches: batches);
      if (values == null) return;
      final photo = values.remove('photo') as File?;
      final fields =
          values.map((key, value) => MapEntry(key, value.toString()));
      if (photo != null && mounted) {
        setState(() {
          _uploadingPhoto = true;
          _photoUploadProgress = 0;
        });
      }
      dynamic result;
      try {
        result = await api.postMultipart('/students', fields,
            file: photo, onProgress: photo == null ? null : _setPhotoProgress);
      } finally {
        if (photo != null && mounted) {
          setState(() {
            _uploadingPhoto = false;
            _photoUploadProgress = 0;
          });
        }
      }
      reload();
      final credentials = result is Map && result['credentials'] is Map
          ? Map<String, dynamic>.from(result['credentials'])
          : <String, dynamic>{};
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Student account created'),
          content: SelectableText(
            'Student ID: ${credentials['studentId'] ?? 'Generated'}\n'
            'Login ID (phone): ${credentials['loginId'] ?? fields['phone']}\n'
            'Temporary password: ${credentials['initialPassword'] ?? fields['phone']}\n\n'
            'The student must choose a new password on first sign-in. Share these credentials privately.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _openStudent(String id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailPage(studentId: id)),
    );
    if (changed == true) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Students'), actions: [
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _uploadingPhoto ? null : _addStudent,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add student'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => reload(),
              decoration: InputDecoration(
                hintText: 'Search name, ID or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FutureBuilder<dynamic>(
              future: batchesFuture,
              builder: (context, snapshot) {
                final batches = snapshot.data as List<dynamic>? ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: selectedBatchId ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Filter students by batch',
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
                  onChanged: (value) => setState(() {
                    selectedBatchId = value == 'all' ? null : value;
                    future = _load();
                  }),
                );
              },
            ),
          ),
          if (_uploadingPhoto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(children: [
                LinearProgressIndicator(value: _photoUploadProgress),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Uploading student photo ${(100 * _photoUploadProgress).round()}%'),
                ),
              ]),
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
                final students = snapshot.data as List<dynamic>? ?? [];
                if (students.isEmpty) {
                  return const EmptyState(
                    title: 'No students found',
                    subtitle: 'Add a student or change the search.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final profile = Map<String, dynamic>.from(students[index]);
                    final user = profile['userId'] is Map
                        ? Map<String, dynamic>.from(profile['userId'])
                        : <String, dynamic>{};
                    final batch = profile['batchId'] is Map
                        ? Map<String, dynamic>.from(profile['batchId'])
                        : <String, dynamic>{};
                    final fees = profile['feeSummary'] is Map
                        ? Map<String, dynamic>.from(profile['feeSummary'])
                        : <String, dynamic>{};
                    final photo = (profile['photo'] ?? '').toString();
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Stack(clipBehavior: Clip.none, children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: photo.startsWith('http')
                                ? NetworkImage(photo)
                                : null,
                            backgroundColor: AcademyColors.mint,
                            child: photo.isEmpty
                                ? const Icon(Icons.person,
                                    color: AcademyColors.green)
                                : null,
                          ),
                          Positioned(
                            right: -5,
                            bottom: -5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AcademyColors.forest,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text('${index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]),
                        title: Text(user['name']?.toString() ?? 'Student',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '${profile['studentId'] ?? ''} • ${batch['name'] ?? 'No batch'}\n'
                            '${user['phone'] ?? 'No phone'} • Fee due ₹${fees['remainingAmount'] ?? 0}',
                          ),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openStudent(profile['_id'].toString()),
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

class StudentDetailPage extends StatefulWidget {
  final String studentId;
  const StudentDetailPage({super.key, required this.studentId});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Future<dynamic> future;
  bool _uploadingPhoto = false;
  bool _resettingPassword = false;
  double _photoUploadProgress = 0;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() =>
      context.read<SessionProvider>().api.get('/students/${widget.studentId}');

  void reload() => setState(() => future = _load());

  void _setPhotoProgress(int sent, int total) {
    if (!mounted) return;
    setState(() => _photoUploadProgress =
        total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0).toDouble());
  }

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  Future<void> _edit(Map<String, dynamic> profile) async {
    try {
      final batches = await context.read<SessionProvider>().api.get('/batches')
          as List<dynamic>;
      final active = batches
          .where((batch) => batch is Map && batch['status'] == 'active')
          .toList();
      final currentBatchId = profile['batchId'] is Map
          ? profile['batchId']['_id']?.toString()
          : profile['batchId']?.toString();
      if (currentBatchId != null &&
          !active.any((batch) => batch['_id']?.toString() == currentBatchId)) {
        final assigned = batches
            .where((batch) => batch['_id']?.toString() == currentBatchId)
            .toList();
        if (assigned.isNotEmpty) active.insert(0, assigned.first);
      }
      final values = await showStudentAdmissionForm(context,
          batches: active, initial: profile);
      if (values == null) return;
      final photo = values.remove('photo') as File?;
      final resetPassword = values.remove('resetPasswordToPhone') == true;
      values['resetPasswordToPhone'] = resetPassword;
      await context
          .read<SessionProvider>()
          .api
          .patch('/students/${widget.studentId}', values);
      if (photo != null) {
        setState(() {
          _uploadingPhoto = true;
          _photoUploadProgress = 0;
        });
        try {
          await context.read<SessionProvider>().api.postMultipart(
                '/students/${widget.studentId}/photo',
                const {},
                file: photo,
                onProgress: _setPhotoProgress,
              );
        } finally {
          if (mounted) {
            setState(() {
              _uploadingPhoto = false;
              _photoUploadProgress = 0;
            });
          }
        }
      }
      if (!mounted) return;
      reload();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student profile updated')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _resetPassword() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;
    final temporaryPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set temporary password'),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Set a temporary password for this student. They must change it before using the app again.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Temporary password (10–72 characters)',
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword),
                    icon: Icon(obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) {
                  final candidate = value ?? '';
                  if (candidate.length < 10) {
                    return 'Use at least 10 characters';
                  }
                  if (candidate.length > 72) return 'Maximum 72 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm password'),
                validator: (value) =>
                    value != password.text ? 'Passwords do not match' : null,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, password.text);
              },
              child: const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirmation.dispose();
    if (temporaryPassword == null || !mounted) return;

    setState(() => _resettingPassword = true);
    try {
      await context.read<SessionProvider>().api.patch(
        '/students/${widget.studentId}/password',
        {'temporaryPassword': temporaryPassword},
      );
      if (!mounted) return;
      reload();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Temporary password set'),
          content: SelectableText(
            'Temporary password: $temporaryPassword\n\n'
            'Share it privately with the student. They must choose a new password before using the app again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _resettingPassword = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete student?'),
        content: const Text(
          'This permanently removes the student login and profile, fee/payment ledger, attendance history, test attempts/results, and inbox notifications. This cannot be undone.',
        ),
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
    if (confirmed != true) return;
    try {
      await context
          .read<SessionProvider>()
          .api
          .delete('/students/${widget.studentId}');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editFee(Map<String, dynamic> fee) async {
    final total = TextEditingController(text: '${fee['totalFees'] ?? 0}');
    final paid = TextEditingController(text: '${fee['paidAmount'] ?? 0}');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit fee record'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: total,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total fee (₹)'),
              validator: (value) {
                final amount = num.tryParse(value ?? '');
                return amount == null || amount < 0
                    ? 'Enter a valid total'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: paid,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount paid (₹)'),
              validator: (value) {
                final amount = num.tryParse(value ?? '');
                final ceiling = num.tryParse(total.text);
                if (amount == null || amount < 0) return 'Enter a valid amount';
                if (ceiling != null && amount > ceiling)
                  return 'Cannot exceed total fee';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Reason for correction (optional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(dialogContext, {
                'totalFees': total.text.trim(),
                'paidAmount': paid.text.trim(),
                'note': note.text.trim(),
              });
            },
            child: const Text('Save fee changes'),
          ),
        ],
      ),
    );
    total.dispose();
    paid.dispose();
    note.dispose();
    if (values == null) return;
    try {
      await context.read<SessionProvider>().api.patch('/fees/${fee['_id']}', {
        'totalFees': num.parse(values['totalFees']!),
        'paidAmount': num.parse(values['paidAmount']!),
        'note': values['note'],
      });
      if (!mounted) return;
      reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Fee updated; previous payments remain in the history.')),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _value(dynamic value) =>
      value == null || value.toString().trim().isEmpty
          ? 'Not provided'
          : value.toString();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Student details'),
          actions: [
            IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
            IconButton(
              tooltip: 'Edit student',
              onPressed: _uploadingPhoto
                  ? null
                  : () async {
                      final data = await future;
                      if (data is Map<String, dynamic>) await _edit(data);
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
                tooltip: 'Delete student',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ],
        ),
        body: FutureBuilder<dynamic>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const LoadingState();
            if (snapshot.hasError)
              return ErrorState(
                  message: snapshot.error.toString(), retry: reload);
            final profile = Map<String, dynamic>.from(snapshot.data ?? {});
            final user = profile['userId'] is Map
                ? Map<String, dynamic>.from(profile['userId'])
                : <String, dynamic>{};
            final batch = profile['batchId'] is Map
                ? Map<String, dynamic>.from(profile['batchId'])
                : <String, dynamic>{};
            final fees = profile['feeSummary'] is Map
                ? Map<String, dynamic>.from(profile['feeSummary'])
                : <String, dynamic>{};
            final photo = (profile['photo'] ?? '').toString();
            final dob = _date(profile['dateOfBirth']);
            final joined = _date(profile['joiningDate']);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AcademyColors.mint,
                        backgroundImage: photo.startsWith('http')
                            ? NetworkImage(photo)
                            : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.person,
                                size: 44, color: AcademyColors.green)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(user['name']?.toString() ?? 'Student',
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      Text('Student ID: ${profile['studentId'] ?? '—'}'),
                      Text(batch['name']?.toString() ?? 'No batch assigned',
                          style: const TextStyle(color: AcademyColors.green)),
                      if (_uploadingPhoto) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: _photoUploadProgress),
                        const SizedBox(height: 4),
                        Text(
                            'Uploading photo ${(100 * _photoUploadProgress).round()}%'),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _uploadingPhoto ? null : () => _edit(profile),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit student details'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploadingPhoto || _resettingPassword
                                ? null
                                : _resetPassword,
                            icon: const Icon(Icons.lock_reset),
                            label: Text(_resettingPassword
                                ? 'Resetting…'
                                : 'Reset login password'),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
                if (user['mustChangePassword'] == true)
                  Card(
                    color: AcademyColors.mint,
                    child: const ListTile(
                      leading:
                          Icon(Icons.lock_clock, color: AcademyColors.green),
                      title: Text('Password change required'),
                      subtitle: Text(
                          'The student must choose a new password before using the app.'),
                    ),
                  ),
                _section('Personal information', Icons.person_outline, [
                  _row(
                      'Date of birth',
                      dob == null
                          ? 'Not provided'
                          : DateFormat('dd MMM yyyy').format(dob)),
                  _row('Student phone / login ID', _value(user['phone'])),
                  _row('Parent phone', _value(profile['parentPhone'])),
                  if ((user['email'] ?? '').toString().isNotEmpty &&
                      !(user['email'] as String)
                          .endsWith('@students.msda.local'))
                    _row('Email', user['email'].toString()),
                  _row('Father name', _value(profile['fatherName'])),
                  _row('Mother name', _value(profile['motherName'])),
                ]),
                _section('Address', Icons.location_on_outlined, [
                  _row('Village', _value(profile['village'])),
                  _row('Post office', _value(profile['post'])),
                  _row('Police station', _value(profile['policeStation'])),
                  _row('District', _value(profile['district'])),
                  _row('State', _value(profile['state'])),
                  _row('PIN code', _value(profile['postalCode'])),
                  if ((profile['address'] ?? '').toString().isNotEmpty)
                    _row('Full address', profile['address'].toString()),
                ]),
                _section(
                    'Physical measurements', Icons.fitness_center_outlined, [
                  _row(
                      'Height',
                      profile['heightCm'] == null
                          ? 'Not provided'
                          : '${profile['heightCm']} cm'),
                  _row(
                      'Weight',
                      profile['weightKg'] == null
                          ? 'Not provided'
                          : '${profile['weightKg']} kg'),
                  _row(
                      'Chest',
                      profile['chestCm'] == null
                          ? 'Not provided'
                          : '${profile['chestCm']} cm'),
                ]),
                _section('Academy information', Icons.school_outlined, [
                  _row('Batch', _value(batch['name'])),
                  _row('Course', _value(profile['course'])),
                  _row(
                      'Joining date',
                      joined == null
                          ? 'Not provided'
                          : DateFormat('dd MMM yyyy').format(joined)),
                  _row('Account',
                      user['isActive'] == false ? 'Inactive' : 'Active'),
                ]),
                _section('Aadhaar number', Icons.verified_user_outlined, [
                  _row('Aadhaar', _value(profile['aadhaarNumber'])),
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'Visible only to this student and authorized academy administrators.',
                          style: TextStyle(
                              fontSize: 12, color: AcademyColors.muted))),
                ]),
                _section('Fees', Icons.account_balance_wallet_outlined, [
                  _row('Total fees', '₹${fees['totalFees'] ?? 0}'),
                  _row('Paid', '₹${fees['paidAmount'] ?? 0}'),
                  _row('Balance', '₹${fees['remainingAmount'] ?? 0}'),
                  if ((profile['feeRecords'] as List<dynamic>? ?? []).isEmpty)
                    _row('Ledger', 'No fee record yet'),
                  ...((profile['feeRecords'] as List<dynamic>? ?? [])
                      .asMap()
                      .entries
                      .map((entry) {
                    final item = Map<String, dynamic>.from(entry.value);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Fee record ${entry.key + 1}'),
                      subtitle: Text(
                        '₹${item['paidAmount'] ?? 0} paid of ₹${item['totalFees'] ?? 0} • Balance ₹${item['remainingAmount'] ?? ''} • ${item['status'] ?? 'due'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Edit fee record',
                        onPressed: () => _editFee(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    );
                  })),
                ]),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Permanently delete student and records'),
                ),
              ],
            );
          },
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> rows) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AcademyColors.green),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))
            ]),
            const Divider(height: 24),
            ...rows,
          ]),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 4,
              child: Text(label,
                  style: const TextStyle(color: AcademyColors.muted))),
          const SizedBox(width: 12),
          Expanded(
              flex: 6,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

Future<Map<String, dynamic>?> showStudentAdmissionForm(
  BuildContext context, {
  required List<dynamic> batches,
  Map<String, dynamic>? initial,
}) async {
  final isEditing = initial != null;
  final user = initial?['userId'] is Map
      ? Map<String, dynamic>.from(initial!['userId'])
      : <String, dynamic>{};
  final batchValue = initial?['batchId'] is Map
      ? initial!['batchId']['_id']?.toString()
      : initial?['batchId']?.toString();
  final controllers = <String, TextEditingController>{
    'name': TextEditingController(text: user['name']?.toString() ?? ''),
    'phone': TextEditingController(text: user['phone']?.toString() ?? ''),
    'email': TextEditingController(
        text: (user['email']?.toString() ?? '').endsWith('@students.msda.local')
            ? ''
            : user['email']?.toString() ?? ''),
    'studentId':
        TextEditingController(text: initial?['studentId']?.toString() ?? ''),
    'fatherName':
        TextEditingController(text: initial?['fatherName']?.toString() ?? ''),
    'motherName':
        TextEditingController(text: initial?['motherName']?.toString() ?? ''),
    'parentPhone':
        TextEditingController(text: initial?['parentPhone']?.toString() ?? ''),
    'village':
        TextEditingController(text: initial?['village']?.toString() ?? ''),
    'post': TextEditingController(text: initial?['post']?.toString() ?? ''),
    'policeStation': TextEditingController(
        text: initial?['policeStation']?.toString() ?? ''),
    'district':
        TextEditingController(text: initial?['district']?.toString() ?? ''),
    'state': TextEditingController(text: initial?['state']?.toString() ?? ''),
    'postalCode':
        TextEditingController(text: initial?['postalCode']?.toString() ?? ''),
    'heightCm':
        TextEditingController(text: initial?['heightCm']?.toString() ?? ''),
    'weightKg':
        TextEditingController(text: initial?['weightKg']?.toString() ?? ''),
    'chestCm':
        TextEditingController(text: initial?['chestCm']?.toString() ?? ''),
    'aadhaarNumber': TextEditingController(
        text: initial?['aadhaarNumber']?.toString() ?? ''),
    'course': TextEditingController(text: initial?['course']?.toString() ?? ''),
    'totalFees': TextEditingController(text: '0'),
    'paidAmount': TextEditingController(text: '0'),
  };
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  File? photo;
  DateTime? dob = DateTime.tryParse(initial?['dateOfBirth']?.toString() ?? '');
  DateTime joining =
      DateTime.tryParse(initial?['joiningDate']?.toString() ?? '') ??
          DateTime.now();
  String? selectedBatch =
      batches.any((item) => item['_id']?.toString() == batchValue)
          ? batchValue
          : (batches.isEmpty ? null : batches.first['_id']?.toString());
  bool resetPassword = false;

  Widget gap() => const SizedBox(height: 14);
  Widget heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AcademyColors.green))),
      );
  TextFormField field(String key, String label,
          {TextInputType? keyboard,
          int maxLines = 1,
          String? Function(String?)? validator,
          String? hint}) =>
      TextFormField(
        controller: controllers[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: key == 'aadhaarNumber' ||
                key == 'postalCode' ||
                key == 'phone' ||
                key == 'parentPhone'
            ? TextCapitalization.none
            : TextCapitalization.words,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
      );

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(isEditing ? 'Edit student details' : 'Add student'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: (MediaQuery.of(context).size.width - 48).clamp(280.0, 720.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .82),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Center(
                      child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AcademyColors.mint,
                    backgroundImage: photo == null ? null : FileImage(photo!),
                    child: photo == null
                        ? const Icon(Icons.person,
                            size: 38, color: AcademyColors.green)
                        : null,
                  )),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 82,
                          maxWidth: 1280,
                          maxHeight: 1280);
                      if (picked != null)
                        update(() => photo = File(picked.path));
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(photo == null
                        ? 'Choose student photo (optional)'
                        : 'Change photo'),
                  ),
                  heading('Student information'),
                  gap(),
                  field('name', 'Student full name *',
                      validator: (value) =>
                          value == null || value.trim().length < 2
                              ? 'Enter the student name'
                              : null),
                  gap(),
                  field('phone', 'Student phone / login ID *',
                      keyboard: TextInputType.phone,
                      hint: '10-digit mobile number', validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length == 10 ||
                            (digits.length == 12 && digits.startsWith('91'))
                        ? null
                        : 'Enter a 10-digit Indian phone number';
                  }),
                  gap(),
                  field('email', 'Email (optional)',
                      keyboard: TextInputType.emailAddress,
                      validator: (value) => value == null ||
                              value.trim().isEmpty ||
                              value.contains('@')
                          ? null
                          : 'Enter a valid email'),
                  gap(),
                  if (isEditing)
                    field('studentId', 'Student ID')
                  else
                    Card(
                      color: AcademyColors.mint,
                      child: const ListTile(
                        dense: true,
                        leading: Icon(Icons.auto_awesome,
                            color: AcademyColors.green),
                        title: Text('Student ID is automatic'),
                        subtitle: Text(
                            'New IDs continue in order: MSDA01, MSDA02, MSDA03…'),
                      ),
                    ),
                  gap(),
                  field('fatherName', 'Father’s name'),
                  gap(),
                  field('motherName', 'Mother’s name'),
                  gap(),
                  field('parentPhone', 'Parent / guardian phone',
                      keyboard: TextInputType.phone),
                  heading('Address'),
                  gap(),
                  field('village', 'Village'),
                  gap(),
                  field('post', 'Post office'),
                  gap(),
                  field('policeStation', 'Police station'),
                  gap(),
                  field('district', 'District'),
                  gap(),
                  Row(children: [
                    Expanded(child: field('state', 'State')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: field('postalCode', 'PIN code',
                            keyboard: TextInputType.number)),
                  ]),
                  heading('Personal and physical details'),
                  gap(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Date of birth'),
                    subtitle: Text(dob == null
                        ? 'Not entered'
                        : DateFormat('dd MMM yyyy').format(dob!)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: dob ?? DateTime(2005),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now());
                      if (picked != null) update(() => dob = picked);
                    },
                  ),
                  Row(children: [
                    Expanded(
                        child: field('heightCm', 'Height (cm)',
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: field('weightKg', 'Weight (kg)',
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true))),
                  ]),
                  gap(),
                  field('chestCm', 'Chest (cm)',
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true)),
                  gap(),
                  field('aadhaarNumber', 'Aadhaar number (12 digits)',
                      keyboard: TextInputType.number, validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.isEmpty || digits.length == 12
                        ? null
                        : 'Enter all 12 digits';
                  }),
                  heading('Academy and fee details'),
                  gap(),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBatch,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Batch *'),
                    items: batches
                        .map((batch) => DropdownMenuItem<String>(
                            value: batch['_id'].toString(),
                            child: Text(
                                '${batch['name']?.toString() ?? 'Batch'}${batch['status'] == 'inactive' ? ' (archived)' : ''}')))
                        .toList(),
                    onChanged: (value) => update(() => selectedBatch = value),
                    validator: (value) =>
                        value == null ? 'Select a batch' : null,
                  ),
                  gap(),
                  field('course', 'Course (optional)'),
                  gap(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Joining date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(joining)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: joining,
                          firstDate: DateTime(1980),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) update(() => joining = picked);
                    },
                  ),
                  if (!isEditing) ...[
                    gap(),
                    Row(children: [
                      Expanded(
                          child: field('totalFees', 'Total fee (₹)',
                              keyboard: const TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) =>
                                  num.tryParse(value ?? '') == null ||
                                          num.parse(value!) < 0
                                      ? 'Enter a valid amount'
                                      : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: field('paidAmount', 'Paid now (₹)',
                              keyboard: const TextInputType.numberWithOptions(
                                  decimal: true), validator: (value) {
                        final paid = num.tryParse(value ?? '');
                        final total =
                            num.tryParse(controllers['totalFees']!.text);
                        if (paid == null || paid < 0)
                          return 'Enter a valid amount';
                        if (total != null && paid > total)
                          return 'Cannot exceed total';
                        return null;
                      })),
                    ]),
                  ],
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    const Text(
                        'Use Fees Management to add a fee ledger or record payments; payment history is kept intact.',
                        style: TextStyle(
                            fontSize: 12, color: AcademyColors.muted)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: resetPassword,
                      onChanged: (value) =>
                          update(() => resetPassword = value ?? false),
                      title: const Text(
                          'Reset temporary password to the phone number'),
                      subtitle: const Text(
                          'The student will be asked to set a new password again.'),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false) ||
                  selectedBatch == null) return;
              final values = <String, dynamic>{
                'name': controllers['name']!.text.trim(),
                'phone': controllers['phone']!.text.trim(),
                'email': controllers['email']!.text.trim(),
                if (isEditing)
                  'studentId': controllers['studentId']!.text.trim(),
                'fatherName': controllers['fatherName']!.text.trim(),
                'motherName': controllers['motherName']!.text.trim(),
                'parentPhone': controllers['parentPhone']!.text.trim(),
                'village': controllers['village']!.text.trim(),
                'post': controllers['post']!.text.trim(),
                'policeStation': controllers['policeStation']!.text.trim(),
                'district': controllers['district']!.text.trim(),
                'state': controllers['state']!.text.trim(),
                'postalCode': controllers['postalCode']!.text.trim(),
                'heightCm': controllers['heightCm']!.text.trim(),
                'weightKg': controllers['weightKg']!.text.trim(),
                'chestCm': controllers['chestCm']!.text.trim(),
                'aadhaarNumber': controllers['aadhaarNumber']!.text.trim(),
                'course': controllers['course']!.text.trim(),
                'batchId': selectedBatch,
                'joiningDate': joining.toUtc().toIso8601String(),
                'dateOfBirth': dob?.toUtc().toIso8601String() ?? '',
                'photo': photo,
                if (resetPassword) 'resetPasswordToPhone': true,
                if (!isEditing)
                  'totalFees': controllers['totalFees']!.text.trim(),
                if (!isEditing)
                  'paidAmount': controllers['paidAmount']!.text.trim(),
              };
              Navigator.pop(dialogContext, values);
            },
            child: Text(isEditing ? 'Save changes' : 'Create student'),
          ),
        ],
      ),
    ),
  );

  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}
