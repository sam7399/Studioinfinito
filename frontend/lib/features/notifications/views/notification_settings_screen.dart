import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

/// Screen for managing user notification preferences
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late NotificationPreferenceModel _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    final settings = ref.read(notificationSettingsProvider);
    if (settings != null) {
      setState(() {
        _preferences = settings;
        _isLoading = false;
      });
    } else {
      // Load from API
      await ref.read(notificationSettingsProvider.notifier).fetchPreferences();
      final settings = ref.read(notificationSettingsProvider);
      if (settings != null) {
        setState(() {
          _preferences = settings;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .updatePreferences(_preferences);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Notification Types Section
            _buildSection(
              title: 'Notification Types',
              subtitle: 'Choose which notifications you want to receive',
              children: [
                _buildSwitchTile(
                  title: 'Task Assigned',
                  subtitle: 'When a task is assigned to you',
                  value: _preferences.taskAssigned,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskAssigned: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Task Completed',
                  subtitle: 'When you complete a task',
                  value: _preferences.taskCompleted,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskCompleted: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Task Status Changed',
                  subtitle: 'When task status changes',
                  value: _preferences.taskStatusChanged,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskStatusChanged: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Comment Added',
                  subtitle: 'When someone comments on your tasks',
                  value: _preferences.taskCommented,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskCommented: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Deadline Approaching',
                  subtitle: 'When a task deadline is coming up',
                  value: _preferences.taskDeadlineApproaching,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskDeadlineApproaching: value,
                      );
                    });
                  },
                ),
              ],
            ),
            // Approval Notifications Section
            _buildSection(
              title: 'Approval Notifications',
              subtitle: 'Manage approval-related notifications',
              children: [
                _buildSwitchTile(
                  title: 'Pending Review',
                  subtitle: 'When a task is pending your review',
                  value: _preferences.taskReviewPending,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskReviewPending: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Approval Approved',
                  subtitle: 'When your submitted task is approved',
                  value: _preferences.taskReviewApproved,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskReviewApproved: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Approval Rejected',
                  subtitle: 'When your submitted task is rejected',
                  value: _preferences.taskReviewRejected,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        taskReviewRejected: value,
                      );
                    });
                  },
                ),
              ],
            ),
            // Delivery Method Section
            _buildSection(
              title: 'Delivery Method',
              subtitle: 'How you receive notifications',
              children: [
                _buildSwitchTile(
                  title: 'In-App Notifications',
                  subtitle: 'Receive notifications in the app',
                  value: true, // Always enabled
                  onChanged: null, // Not editable
                ),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _preferences.emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        emailNotifications: value,
                      );
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications (if enabled)',
                  value: _preferences.pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        pushNotifications: value,
                      );
                    });
                  },
                ),
              ],
            ),
            // Save Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePreferences,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Settings'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      enabled: onChanged != null,
    );
  }
}
