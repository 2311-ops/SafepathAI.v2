import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/deep_link/deep_link_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';

/// Root SafePath AI app widget — wires the shared [buildSafePathTheme] and
/// [routerProvider] into a single [MaterialApp.router] (DESIGN-01
/// foundation). A [ConsumerStatefulWidget] (not [StatelessWidget]) so the router can
/// react to [AuthController] state changes (auth redirect guard, plan 03).
class SafePathApp extends ConsumerStatefulWidget {
  const SafePathApp({super.key, this.showStartupSplash = true});

  final bool showStartupSplash;

  @override
  ConsumerState<SafePathApp> createState() => _SafePathAppState();
}

class _SafePathAppState extends ConsumerState<SafePathApp> {
  DeepLinkService? _deepLinkService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = ref.read(deepLinkServiceProvider);
      _deepLinkService = service;
      unawaited(service.start(ref.read(routerProvider)));
    });
  }

  @override
  void dispose() {
    _deepLinkService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SafePath AI',
      debugShowCheckedModeBanner: false,
      theme: buildSafePathTheme(),
      routerConfig: router,
      builder: (context, child) {
        final routedChild = child ?? const SizedBox.shrink();
        if (!widget.showStartupSplash) return routedChild;
        return StartupSplashOverlay(child: routedChild);
      },
    );
  }
}
