import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/emergency_contacts_controller.dart';
import '../data/emergency_contact_api.dart';

/// Light presence/length checks only — phone-number *validity* is the
/// server's job (`PhoneNumberNormalizer`, libphonenumber-csharp). No regex.
String? _validateContactName(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Enter a name';
  return null;
}

String? _validateContactPhone(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return 'Enter a phone number';
  if (trimmed.length < 4) return "That number's too short";
  return null;
}

/// Add/edit/remove emergency contacts (D-30). An ordinary settings surface,
/// never an emergency one — `AppColors.sosRed`/`sosRedDeep` stay reserved
/// for SOS/emergency states and are never used here.
class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// A default-region hint for the server's phone-number normaliser, derived
  /// from the device locale — the server remains the sole authority on
  /// whether the resulting number is valid.
  String? _defaultRegion() {
    final countryCode = Localizations.localeOf(context).countryCode;
    return (countryCode == null || countryCode.isEmpty) ? null : countryCode;
  }

  Future<void> _addContact() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final contactsBefore = ref
        .read(emergencyContactsControllerProvider)
        .value
        ?.contacts
        .length;
    await ref
        .read(emergencyContactsControllerProvider.notifier)
        .add(
          _nameController.text.trim(),
          _phoneController.text.trim(),
          region: _defaultRegion(),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final state = ref.read(emergencyContactsControllerProvider).value;
    if (state?.error == null && state?.contacts.length != contactsBefore) {
      _nameController.clear();
      _phoneController.clear();
    }
  }

  Future<void> _editContact(EmergencyContact contact) async {
    // A dedicated StatefulWidget (below) owns the dialog's TextEditingControllers
    // and disposes them itself once the framework unmounts the dialog route —
    // disposing them manually right after `showDialog` returns races the
    // dialog's own exit animation and can use-after-dispose the controller.
    final result = await showDialog<({String name, String phoneNumber})>(
      context: context,
      builder: (_) => _EditContactDialog(contact: contact),
    );
    if (result == null) return;

    await ref
        .read(emergencyContactsControllerProvider.notifier)
        .updateContact(
          contact.id,
          result.name,
          result.phoneNumber,
          region: _defaultRegion(),
        );
  }

  Future<void> _confirmRemove(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${contact.displayName}?'),
        content: const Text(
          "SOS will no longer be able to reach this person while you're "
          'offline. You can add them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(emergencyContactsControllerProvider.notifier)
        .remove(contact.id);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(emergencyContactsControllerProvider);
    final state = asyncState.value ?? const EmergencyContactsState();
    final contacts = state.contacts;

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: SafeArea(
        child: asyncState.isLoading && contacts.isEmpty && !asyncState.hasValue
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('Emergency Contacts', style: AppTypography.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add someone SOS can reach even while your family '
                    "circle can't.",
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (contacts.isEmpty) const _EmptyContactsCard(),
                  for (final contact in contacts) ...[
                    _ContactRow(
                      contact: contact,
                      onEdit: () => _editContact(contact),
                      onRemove: () => _confirmRemove(contact),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _AddContactCard(
                    formKey: _formKey,
                    nameController: _nameController,
                    phoneController: _phoneController,
                    isSubmitting: _isSubmitting,
                    error: state.error,
                    onSubmit: _addContact,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Owns the edit dialog's own `TextEditingController`s so their lifecycle is
/// tied to the dialog route's own mount/unmount — the framework disposes
/// this State (and its controllers) only after the dialog has fully
/// unmounted, avoiding a use-after-dispose race.
class _EditContactDialog extends StatefulWidget {
  const _EditContactDialog({required this.contact});

  final EmergencyContact contact;

  @override
  State<_EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends State<_EditContactDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.contact.displayName,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.contact.phoneNumberE164,
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit contact'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafePathTextField(
              label: 'Name',
              controller: _nameController,
              validator: _validateContactName,
            ),
            const SizedBox(height: AppSpacing.md),
            SafePathTextField(
              label: 'Phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: _validateContactPhone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _EmptyContactsCard extends StatelessWidget {
  const _EmptyContactsCard();

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No emergency contacts yet.', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'SOS has nowhere to send help until you add one. Add someone '
            "below so there's always a way to reach you.",
            style: AppTypography.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onEdit,
    required this.onRemove,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.displayName, style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  contact.phoneNumberE164,
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit ${contact.displayName}',
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryTeal),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Remove ${contact.displayName}',
            icon: const Icon(Icons.delete_outline, color: AppColors.ink),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddContactCard extends StatelessWidget {
  const _AddContactCard({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.isSubmitting,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a contact', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            SafePathTextField(
              label: 'Name',
              controller: nameController,
              validator: _validateContactName,
            ),
            const SizedBox(height: AppSpacing.md),
            SafePathTextField(
              label: 'Phone number',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              validator: _validateContactPhone,
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InlineErrorBanner(message: error!),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: isSubmitting ? 'Adding…' : 'Add contact',
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        border: Border.all(color: AppColors.cautionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.cautionText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
