import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root SafePath AI app widget — wires the shared [buildSafePathTheme] and
/// [appRouter] into a single [MaterialApp.router] (DESIGN-01 foundation).
class SafePathApp extends StatelessWidget {
  const SafePathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafePath AI',
      debugShowCheckedModeBanner: false,
      theme: buildSafePathTheme(),
      routerConfig: appRouter,
    );
  }
}
