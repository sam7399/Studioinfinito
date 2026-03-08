import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

// ─── Pending (not-yet-uploaded) attachment ───────────────────────────────────

class PendingAttachment {
  final PlatformFile file;
  PendingAttachment(this.file);
}

// ─── Widget for picking files BEFORE task is created ─────────────────────────

class PendingAttachmentSection extends StatefulWidget {
  final List<PendingAttachment> attachments;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const PendingAttachmentSection({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<PendingAttachmentSection> createState() => _PendingAttachmentSectionState();
}

class _PendingAttachmentSectionState extends State<PendingAttachmentSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.attach_file, size: 16, color: Color(0xFF4B5563)),
          const SizedBox(width: 6),
          const Text('Attachments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add File', style: TextStyle(fontSize: 12)),
            onPressed: widget.onAdd,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ]),
        if (widget.attachments.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...widget.attachments.asMap().entries.map((e) => _PendingTile(
                file: e.value.file,
                onRemove: () => widget.onRemove(e.key),
              )),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('No files attached', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;
  const _PendingTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(_fileIcon(file.name), size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(file.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        Text(_formatSize(file.size), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
        ),
      ]),
    );
  }
}

// ─── Widget for displaying/uploading attachments on an EXISTING task ──────────

class TaskAttachmentSection extends ConsumerStatefulWidget {
  final int taskId;
  final bool canUpload;

  const TaskAttachmentSection({super.key, required this.taskId, this.canUpload = true});

  @override
  ConsumerState<TaskAttachmentSection> createState() => _TaskAttachmentSectionState();
}

class _TaskAttachmentSectionState extends ConsumerState<TaskAttachmentSection> {
  List<Map<String, dynamic>> _attachments = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ref.read(taskProvider.notifier).getAttachments(widget.taskId);
    if (mounted) setState(() { _attachments = list; _loading = false; });
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final mime = _guessMime(file.name);
      await ref.read(taskProvider.notifier).uploadAttachment(
        widget.taskId, file.bytes!, file.name, mime,
      );
    }
    await _load();
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _delete(int attachmentId) async {
    final ok = await ref.read(taskProvider.notifier).deleteAttachment(widget.taskId, attachmentId);
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.attach_file, size: 16, color: Color(0xFF4B5563)),
          const SizedBox(width: 6),
          Text('Attachments (${_attachments.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const Spacer(),
          if (widget.canUpload)
            TextButton.icon(
              icon: _uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file, size: 16),
              label: const Text('Upload', style: TextStyle(fontSize: 12)),
              onPressed: _uploading ? null : _pick,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        if (_loading)
          const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_attachments.isEmpty)
          Text('No attachments', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
        else
          ..._attachments.map((a) => _AttachmentTile(
                attachment: a,
                onDelete: widget.canUpload ? () => _delete(a['id'] as int) : null,
              )),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final Map<String, dynamic> attachment;
  final VoidCallback? onDelete;
  const _AttachmentTile({required this.attachment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = attachment['original_name'] as String? ?? 'file';
    final size = attachment['file_size'] as int?;
    final uploader = (attachment['uploader'] as Map?)?['name'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(_fileIcon(name), size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              if (uploader.isNotEmpty)
                Text('by $uploader', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        if (size != null)
          Text(_formatSize(size), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        if (onDelete != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
          ),
        ],
      ]),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

IconData _fileIcon(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image_outlined;
  if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
  if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
  if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_outlined;
  if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip_outlined;
  if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.videocam_outlined;
  return Icons.insert_drive_file_outlined;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

String _guessMime(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  const map = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
    'gif': 'image/gif', 'webp': 'image/webp',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain', 'csv': 'text/csv',
    'zip': 'application/zip',
    'mp4': 'video/mp4', 'mov': 'video/quicktime',
  };
  return map[ext] ?? 'application/octet-stream';
}

/// Helper to upload a list of pending attachments to a newly created task.
Future<void> uploadPendingAttachments(
  WidgetRef ref,
  int taskId,
  List<PendingAttachment> attachments,
) async {
  for (final a in attachments) {
    if (a.file.bytes == null) continue;
    final mime = _guessMime(a.file.name);
    await ref.read(taskProvider.notifier).uploadAttachment(
      taskId, a.file.bytes!, a.file.name, mime,
    );
  }
}
