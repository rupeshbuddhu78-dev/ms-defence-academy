import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{ for (final key in ['name','email','phone','password','fatherName','motherName','parentPhone','address','village','post','policeStation','district','state','postalCode','dateOfBirth','heightCm','weightKg','chestCm']) key: TextEditingController() };
  List<dynamic> batches = []; String? batchId; File? photo; String? otp; bool loading = false;
  @override void initState() { super.initState(); _loadBatches(); }
  Future<void> _loadBatches() async { try { final data = await context.read<SessionProvider>().api.get('/auth/register/batches'); if (mounted) setState(() => batches = data as List<dynamic>); } catch (_) {} }
  @override void dispose() { for (final c in fields.values) c.dispose(); super.dispose(); }
  Map<String, dynamic> _payload() => { for (final e in fields.entries) e.key: e.value.text.trim(), 'batchId': batchId ?? '' };
  Future<void> _sendOtp() async {
    if (!(form.currentState?.validate() ?? false) || batchId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill required details and select a batch'))); return; }
    setState(() => loading = true);
    try { await context.read<SessionProvider>().api.post('/auth/register/request-otp', _payload()); if (mounted) setState(() => otp = ''); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> _verify() async {
    if ((otp ?? '').trim().length != 6) return;
    setState(() => loading = true);
    try {
      final result = await context.read<SessionProvider>().api.postMultipart('/auth/register/verify-otp', {'email': fields['email']!.text.trim(), 'otp': otp!.trim()}, file: photo, fileField: 'photo', timeout: const Duration(minutes: 5));
      if (mounted) { await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Application submitted'), content: Text(result['message']?.toString() ?? 'Email verified. Wait for admin approval.'), actions: [FilledButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text('Done'))])); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if (mounted) setState(() => loading = false); }
  }
  Widget _field(String key, String label, {bool required = false, TextInputType? type, bool secret = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(controller: fields[key], obscureText: secret, keyboardType: type, validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null, decoration: InputDecoration(labelText: label)));
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Create student account')), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Email verification is required. Account will be created only after admin approval.', style: TextStyle(color: AcademyColors.muted)), const SizedBox(height: 16),
    _field('name','Full name *',required:true), _field('email','Email *',required:true,type:TextInputType.emailAddress), _field('phone','Phone *',required:true,type:TextInputType.phone), _field('password','Password (minimum 10 characters) *',required:true,secret:true),
    DropdownButtonFormField<String>(initialValue: batchId, decoration: const InputDecoration(labelText: 'Select batch *'), items: batches.map((b) => DropdownMenuItem<String>(value: b['_id'].toString(), child: Text('${b['name']} • ${b['course'] ?? ''}'))).toList(), onChanged: (v) => setState(() => batchId = v)),
    const SizedBox(height: 12), _field('fatherName','Father name'), _field('motherName','Mother name'), _field('parentPhone','Parent phone',type:TextInputType.phone), _field('dateOfBirth','Date of birth (YYYY-MM-DD)'), _field('address','Full address'), _field('village','Village'), _field('post','Post'), _field('policeStation','Police station'), _field('district','District'), _field('state','State'), _field('postalCode','Postal code'),
    Row(children: [Expanded(child: _field('heightCm','Height cm',type:TextInputType.number)), const SizedBox(width: 8), Expanded(child: _field('weightKg','Weight kg',type:TextInputType.number)), const SizedBox(width: 8), Expanded(child: _field('chestCm','Chest cm',type:TextInputType.number))]),
    OutlinedButton.icon(onPressed: loading ? null : () async { final image = await ImagePicker().pickImage(source: ImageSource.gallery); if (image != null) setState(() => photo = File(image.path)); }, icon: const Icon(Icons.photo_camera_outlined), label: Text(photo == null ? 'Add profile photo (optional)' : 'Photo selected')),
    const SizedBox(height: 10),
    if (otp == null) FilledButton(onPressed: loading ? null : _sendOtp, child: Text(loading ? 'Sending OTP…' : 'Send OTP to email')) else ...[
      TextField(onChanged: (v) => otp = v, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Enter 6-digit OTP')), FilledButton(onPressed: loading ? null : _verify, child: Text(loading ? 'Verifying…' : 'Verify OTP & submit application')), TextButton(onPressed: loading ? null : _sendOtp, child: const Text('Resend OTP')),
    ],
  ])));
}
