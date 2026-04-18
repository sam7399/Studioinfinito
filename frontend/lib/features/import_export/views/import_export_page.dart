import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  final Map<String, bool> _loading = {};
  final Map<String, String?> _results = {};

  void _setLoading(String key, bool v) =>
      setState(() => _loading[key] = v);
  void _setResult(String key, String? msg) =>
      setState(() => _results[key] = msg);

  // ── Import ────────────────────────────────────────────────────
  Future<void> _import(String endpoint, String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _setResult(label, 'Error: Could not read file');
      return;
    }

    _setLoading(label, true);
    _setResult(label, null);

    try {
      final dio = ref.read(dioProvider);
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = ext == 'csv'
          ? DioMediaType('text', 'csv')
          : DioMediaType('application',
              'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!,
            filename: file.name, contentType: contentType),
      });
      final response = await dio.post(endpoint, data: formData);
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final successList = data['success'];
      final errorsList = data['errors'];
      final created =
          successList is List ? successList.length : (data['created'] ?? 0);
      final failed =
          errorsList is List ? errorsList.length : (data['failed'] ?? 0);
      _setResult(label, '✓ Import complete: $created created, $failed failed');
    } on DioException catch (e) {
      _setResult(
          label, '✗ ${e.response?.data?['message'] ?? e.message ?? 'Import failed'}');
    } finally {
      _setLoading(label, false);
    }
  }

  // ── Export ────────────────────────────────────────────────────
  Future<void> _export(String endpoint, String filename, String label) async {
    _setLoading(label, true);
    _setResult(label, null);
    try {
      // Use Dio so the Authorization header is sent correctly.
      // Direct browser navigation bypasses headers, so we fetch bytes
      // through Dio and create a Blob download link instead.
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<int>>(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? [];
      final mimeType = filename.endsWith('.csv')
          ? 'text/csv;charset=utf-8'
          : 'application/octet-stream';
      final blob = web.Blob(
        [Uint8List.fromList(bytes).toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      final url = web.URL.createObjectURL(blob);
      (web.document.createElement('a') as web.HTMLAnchorElement)
        ..href = url
        ..setAttribute('download', filename)
        ..click();
      web.URL.revokeObjectURL(url);

      _setResult(label, '✓ Export complete — check your downloads');
    } catch (e) {
      _setResult(label, '✗ Export failed: $e');
    } finally {
      _setLoading(label, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import / Export',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Bulk import users and tasks from CSV/Excel files',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),

            // ── Users section ──────────────────────────────────────
            _SectionHeader(icon: Icons.group_outlined, title: 'Users'),
            const SizedBox(height: 8),
            // Sample file download banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'New to bulk import? Download the sample Excel file to see the exact format and required columns.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 14),
                    label: const Text('Sample Excel'),
                    onPressed: _loading['sample_users'] == true
                        ? null
                        : () => _export(
                            ApiConstants.importUsersSample,
                            'sample_users_import.xlsx',
                            'sample_users'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Import Users',
                    description:
                        'Upload a CSV or Excel file to bulk-create users.\nUse the sample file above to ensure correct format.',
                    buttonLabel: 'Choose File & Import',
                    color: const Color(0xFF3B82F6),
                    loading: _loading['import_users'] == true,
                    result: _results['import_users'],
                    onTap: () =>
                        _import(ApiConstants.importUsers, 'import_users'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.download_outlined,
                    title: 'Export Users',
                    description: 'Download all users as a CSV file.',
                    buttonLabel: 'Export Users CSV',
                    color: const Color(0xFF10B981),
                    loading: _loading['export_users'] == true,
                    result: _results['export_users'],
                    onTap: () => _export(
                        ApiConstants.exportUsers, 'users.csv', 'export_users'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Tasks section ──────────────────────────────────────
            _SectionHeader(icon: Icons.task_alt_outlined, title: 'Tasks'),
            const SizedBox(height: 8),
            // Sample task file download banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Download the sample Excel file — it includes dropdowns for assignee, company, department, location, priority and status pulled live from the database.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C1D95)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 14),
                    label: const Text('Sample Excel'),
                    onPressed: _loading['sample_tasks'] == true
                        ? null
                        : () => _export(
                            ApiConstants.importTasksSample,
                            'sample_tasks_import.xlsx',
                            'sample_tasks'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Import Tasks',
                    description:
                        'Upload a CSV or Excel file to bulk-create tasks.\nRequired columns: title, assignedemail, company, department, location.',
                    buttonLabel: 'Choose File & Import',
                    color: const Color(0xFF8B5CF6),
                    loading: _loading['import_tasks'] == true,
                    result: _results['import_tasks'],
                    onTap: () =>
                        _import(ApiConstants.importTasks, 'import_tasks'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.download_outlined,
                    title: 'Export Tasks',
                    description: 'Download all tasks as a CSV file.',
                    buttonLabel: 'Export Tasks CSV',
                    color: const Color(0xFFF59E0B),
                    loading: _loading['export_tasks'] == true,
                    result: _results['export_tasks'],
                    onTap: () => _export(
                        ApiConstants.exportTasks, 'tasks.csv', 'export_tasks'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final Color color;
  final bool loading;
  final String? result;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.color,
    required this.loading,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = result?.startsWith('✓') == true;
    final isError = result?.startsWith('✗') == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(description,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(icon, size: 16),
              label: Text(loading ? 'Processing...' : buttonLabel),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: loading ? null : onTap,
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.shade50
                    : isError
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result!,
                style: TextStyle(
                    fontSize: 12,
                    color: isSuccess
                        ? Colors.green.shade700
                        : isError
                            ? Colors.red.shade700
                            : Colors.grey.shade700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
