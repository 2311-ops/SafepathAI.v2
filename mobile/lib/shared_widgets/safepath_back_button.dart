import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back affordance for routes that may be opened either from an in-app push or
/// as a top-level/deep-linked destination.
class SafePathBackButton extends StatelessWidget {
  const SafePathBackButton({
    super.key,
    this.fallbackLocation = '/home',
    this.tooltip = 'Go back',
  });

  final String fallbackLocation;
  final String tooltip;

  Future<void> _goBack(BuildContext context) async {
    final didPop = await Navigator.of(context).maybePop();
    if (didPop || !context.mounted) return;

    try {
      context.go(fallbackLocation);
    } on Exception {
      // Widget tests may host a screen under MaterialApp without GoRouter.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _goBack(context),
    );
  }
}
