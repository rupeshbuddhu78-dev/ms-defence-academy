import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: AcademyColors.green));
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const ErrorState({super.key, required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AcademyColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'))
          ])));
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  const EmptyState({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined,
                size: 42, color: AcademyColors.muted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AcademyColors.muted))
          ])));
}
