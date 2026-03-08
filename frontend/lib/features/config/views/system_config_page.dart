import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_config_provider.dart';

class SystemConfigPage extends ConsumerWidget {
  const SystemConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Configuration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('These settings control how users and organizations are structured.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            _ConfigCard(
              title: 'User Organization Settings',
              icon: Icons.corporate_fare_outlined,
              children: [
                _ConfigTile(
                  title: 'Multiple Companies per User',
                  subtitle: 'When enabled, a user can be assigned to more than one company.',
                  value: config.multiCompany,
                  loading: config.isLoading,
                  onChanged: (v) => ref.read(systemConfigProvider.notifier).update('multi_company_users', v),
                ),
                const Divider(height: 24),
                _ConfigTile(
                  title: 'Multiple Locations per User',
                  subtitle: 'When enabled, a user can be assigned to more than one location.',
                  value: config.multiLocation,
                  loading: config.isLoading,
                  onChanged: (v) => ref.read(systemConfigProvider.notifier).update('multi_location_users', v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _ConfigCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: const Color(0xFF7851A9)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool loading;
  final Future<bool> Function(bool) onChanged;
  const _ConfigTile({required this.title, required this.subtitle, required this.value, required this.loading, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        loading
            ? const SizedBox(width: 40, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: value,
                onChanged: onChanged,
              ),
      ],
    );
  }
}
