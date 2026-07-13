import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../features/auth/data/auth_models.dart';
import '../features/profile/application/profile_controller.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Role-aware "set up your circle" call-to-action for the no-family empty
/// states shown across the authenticated `MainShell` tabs (Map / Activity /
/// Privacy).
///
/// A Guardian sees "Create a circle" -> `/circle/create`; a Member sees
/// "Enter invite code" -> `/invite/accept`; any other/unknown role sees both
/// paths. This restores the navigation the (now-unrouted)
/// `landing_stub_screen.dart` `_RoleEmptyState` used to provide, placing it
/// wherever a family-less user actually lands after login — closing the
/// reachability gap introduced when `MainShell` replaced the landing stub as
/// `/home`'s destination.
class NoCircleCta extends ConsumerWidget {
  const NoCircleCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Profile role is the authoritative signal in the no-family state (there is
    // no membership row yet) and is guaranteed populated by the router's
    // role-onboarding gate before `/home`.
    final role = ref.watch(profileControllerProvider).value?.profile?.role;

    if (role == Role.member) {
      return PrimaryButton(
        key: const ValueKey('no-circle-join-cta'),
        label: 'Enter invite code',
        onPressed: () => context.push('/invite/accept'),
      );
    }

    if (role == Role.guardian) {
      return PrimaryButton(
        key: const ValueKey('no-circle-create-cta'),
        label: 'Create a circle',
        onPressed: () => context.push('/circle/create'),
      );
    }

    // Unknown/other role (Caregiver, OrgAdmin, or a not-yet-loaded profile):
    // offer both entry points so no role is ever stranded without a way in.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          key: const ValueKey('no-circle-create-cta'),
          label: 'Create a circle',
          onPressed: () => context.push('/circle/create'),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          key: const ValueKey('no-circle-join-cta'),
          label: 'I have an invite code',
          onPressed: () => context.push('/invite/accept'),
        ),
      ],
    );
  }
}
