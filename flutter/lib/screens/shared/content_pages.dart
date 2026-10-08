import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_state.dart';

String _mediaDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return date == null ? '' : DateFormat('dd MMM yyyy • h:mm a').format(date);
}

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});
  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  late Future<dynamic> mediaFuture;
  final name = TextEditingController();
  double progress = 0;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    mediaFuture = _load();
    final current = context.read<SessionProvider>().settings['name']?.toString();
    name.text = current?.isNotEmpty == true ? current! : 'MS Defence Academy';
  }

  Future<dynamic> _load() => context.read<SessionProvider>().api.get('/content/media');
  void reload() => setState(() => mediaFuture = _load());

  Future<void> saveName() async {
    try {
      final data = await context.read<SessionProvider>().api.patch('/content/settings', {'name': name.text.trim()});
      context.read<SessionProvider>().applySettings(Map<String, dynamic>.from(data));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App name updated everywhere')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> uploadBrand(String type) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() { uploading = true; progress = 0; });
    try {
      final data = await context.read<SessionProvider>().api.postMultipart('/content/settings/asset', {'type': type}, file: File(path), fileField: 'file', onProgress: (sent, total) => setState(() => progress = total == 0 ? 0 : sent / total));
      context.read<SessionProvider>().applySettings(Map<String, dynamic>.from(data));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type == 'logo' ? 'Logo' : 'Background'} updated everywhere')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() { uploading = false; progress = 0; });
    }
  }

  Future<void> uploadMedia(String kind) async {
    final picked = await FilePicker.platform.pickFiles(
      type: kind == 'video' ? FileType.video : FileType.any,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final title = TextEditingController(text: picked!.files.single.name.split('.').first);
    final description = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(kind == 'video' ? 'Upload video' : 'Upload file'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Heading *')),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 10),
          Text('${picked.files.single.name}\nMax size: 200 MB', style: const TextStyle(color: AcademyColors.muted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, {'title': title.text.trim(), 'description': description.text.trim()}), child: const Text('Upload')),
        ],
      ),
    );
    if (values == null || (values['title'] ?? '').length < 2) return;
    setState(() { uploading = true; progress = 0; });
    try {
      final result = await context.read<SessionProvider>().api.postMultipart(
        '/content/media',
        {...values, 'kind': kind},
        file: File(path),
        fileField: 'file',
        contentType: kind == 'video' ? MediaType('video', 'mp4') : null,
        timeout: const Duration(minutes: 15),
        onProgress: (sent, total) => setState(
            () => progress = total == 0 ? 0 : sent / total),
      );
      reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${kind == 'video' ? 'Video' : 'File'} uploaded. ${result['notificationsSent'] ?? 0} students notified.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() { uploading = false; progress = 0; });
    }
  }

  @override
  void dispose() { name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branding & content'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('App branding', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'App name shown on login and dashboard')),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: uploading ? null : saveName, icon: const Icon(Icons.save_outlined), label: const Text('Save app name')),
          OutlinedButton.icon(onPressed: uploading ? null : () => uploadBrand('logo'), icon: const Icon(Icons.image_outlined), label: const Text('Change app logo')),
          OutlinedButton.icon(onPressed: uploading ? null : () => uploadBrand('background'), icon: const Icon(Icons.wallpaper_outlined), label: const Text('Change greeting background')),
        ]))),
        const SizedBox(height: 12),
        if (uploading) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          const Text('Uploading…'), const SizedBox(height: 8), LinearProgressIndicator(value: progress), const SizedBox(height: 5), Text('${(progress * 100).round()}%'),
        ]))),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: uploading ? null : () => uploadMedia('file'), icon: const Icon(Icons.attach_file), label: const Text('Upload file'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: uploading ? null : () => uploadMedia('video'), icon: const Icon(Icons.video_library_outlined), label: const Text('Upload video'))),
        ]),
        const SizedBox(height: 10),
        const Text('Uploaded content', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        FutureBuilder<dynamic>(future: mediaFuture, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
          if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), retry: reload);
          final items = snapshot.data as List<dynamic>? ?? [];
          if (items.isEmpty) return const EmptyState(title: 'No uploads yet', subtitle: 'Files and videos will appear here.');
          return Column(children: items.map((item) => _MediaTile(item)).toList());
        }),
      ]),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final dynamic item;
  const _MediaTile(this.item);

  Future<void> _delete(BuildContext context, Map<String, dynamic> map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${map['kind'] == 'video' ? 'video' : 'file'}?'),
        content: Text('Delete “${map['title'] ?? ''}” permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<SessionProvider>().api.delete('/content/media/${map['_id']}');
      if (!context.mounted) return;
      context.findAncestorStateOfType<_AdminContentPageState>()?.reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload deleted')));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = Map<String, dynamic>.from(item as Map);
    final video = map['kind'] == 'video';
    final isAdminPage = context.findAncestorStateOfType<_AdminContentPageState>() != null;
    return Card(child: ListTile(
      leading: Icon(video ? Icons.video_library : Icons.insert_drive_file, color: AcademyColors.green),
      title: Text(map['title'] ?? ''),
      subtitle: Text('${map['description'] ?? ''}\n${_mediaDate(map['publishedAt'])}'),
      isThreeLine: true,
      trailing: isAdminPage
          ? IconButton(
              tooltip: 'Delete upload',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _delete(context, map),
            )
          : null,
      onTap: () => launchUrl(Uri.parse(map['url'].toString()), mode: LaunchMode.externalApplication),
    ));
  }
}

class StudentMediaPage extends StatelessWidget {
  final String kind;
  const StudentMediaPage({super.key, required this.kind});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(kind == 'video' ? 'Academy videos' : 'Academy files')),
    body: FutureBuilder<dynamic>(
      future: context.read<SessionProvider>().api.get('/content/media', query: {'kind': kind}),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingState();
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final items = snapshot.data as List<dynamic>? ?? [];
        if (items.isEmpty) return EmptyState(title: kind == 'video' ? 'No videos yet' : 'No files yet', subtitle: 'New academy uploads will appear here.');
        return ListView(padding: const EdgeInsets.all(14), children: items.map((item) => _MediaTile(item)).toList());
      },
    ),
  );
}
