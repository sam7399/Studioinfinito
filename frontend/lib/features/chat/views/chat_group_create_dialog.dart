import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../org/providers/org_provider.dart';
import '../providers/chat_provider.dart';

Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
  final users = ref.read(allUsersProvider).maybeWhen(
        data: (d) => d,
        orElse: () => <OrgItem>[],
      );
  final currentUserId = ref.read(authProvider).user?.id ?? 0;
  final nameCtrl = TextEditingController();
  final selected = <int>{};
  String search = '';
  bool creating = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      final filtered = users
          .where((u) =>
              u.id != currentUserId &&
              u.name.toLowerCase().contains(search.toLowerCase()))
          .toList();
      return AlertDialog(
        title: const Text('Create group'),
        content: SizedBox(
          width: 420,
          height: 480,
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: const Icon(Icons.group_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setDlg(() => search = v),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              if (selected.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${selected.length} selected',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFE65C00))),
                  ),
                ),
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(error!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.red.shade700)),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final isOn = selected.contains(u.id);
                    return CheckboxListTile(
                      value: isOn,
                      onChanged: (v) => setDlg(() {
                        if (v == true) {
                          selected.add(u.id);
                        } else {
                          selected.remove(u.id);
                        }
                      }),
                      title: Text(u.name, style: const TextStyle(fontSize: 13)),
                      activeColor: const Color(0xFFE65C00),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: creating
                ? null
                : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setDlg(() => error = 'Group name is required');
                      return;
                    }
                    if (selected.isEmpty) {
                      setDlg(() => error = 'Pick at least one member');
                      return;
                    }
                    setDlg(() {
                      creating = true;
                      error = null;
                    });
                    try {
                      final room = await ref
                          .read(chatRoomsProvider.notifier)
                          .createGroup(name, selected.toList());
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        context.go('/chat/${room.id}');
                      }
                    } catch (e) {
                      setDlg(() {
                        creating = false;
                        error = 'Failed to create group';
                      });
                    }
                  },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65C00)),
            child: creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Create'),
          ),
        ],
      );
    }),
  );

  nameCtrl.dispose();
}
