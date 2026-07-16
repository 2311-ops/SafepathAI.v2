import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../data/privacy_api.dart';
import '../data/privacy_models.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  late Future<PrivacyPolicy> _policy;

  @override
  void initState() {
    super.initState();
    _policy = ref.read(privacyApiProvider).getPolicy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: FutureBuilder<PrivacyPolicy>(
          future: _policy,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Privacy policy is unavailable.'));
            }
            final policy = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(policy.title, style: AppTypography.heading),
                const SizedBox(height: AppSpacing.lg),
                _PolicySection(
                  title: 'No data resale',
                  body: policy.noDataResaleCommitment,
                ),
                _PolicySection(
                  title: 'Data collected',
                  body: policy.dataCollected,
                ),
                _PolicySection(title: 'Retention', body: policy.retention),
                _PolicySection(
                  title: 'Export and delete rights',
                  body: policy.exportAndDeleteRights,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SafePathCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: AppTypography.bodySecondary),
          ],
        ),
      ),
    );
  }
}
