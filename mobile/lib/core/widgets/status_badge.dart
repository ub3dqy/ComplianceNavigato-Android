import 'package:flutter/material.dart';

import 'compliance_components.dart';

final class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, this.warning = false, super.key});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => SemanticStatusBadge(
    label: label,
    status: warning ? SemanticStatus.needsHumanReview : SemanticStatus.success,
  );
}
