import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root SafePath AI app widget — wires the shared [buildSafePathTheme] and
/// [routerProvider] into a single [MaterialApp.router] (DESIGN-01
/// foundation). A [ConsumerWidget] (not [StatelessWidget]) so the router can
/// react to [AuthController] state changes (auth redirect guard, plan 03).
class SafePathApp extends ConsumerWidget {
  const SafePathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SafePath AI',
      debugShowCheckedModeBanner: false,
      theme: buildSafePathTheme(),
      routerConfig: router,
    );
  }
}
