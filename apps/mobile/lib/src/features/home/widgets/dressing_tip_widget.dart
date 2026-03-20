import "package:flutter/material.dart";

/// Displays a compact dressing tip row below the forecast widget.
///
/// Shows a lightbulb icon and a practical recommendation derived from
/// the top-priority clothing constraint. Renders nothing when [tip] is empty.
class DressingTipWidget extends StatelessWidget {
  const DressingTipWidget({
    required this.tip,
    super.key,
  });

  final String tip;

  @override
  Widget build(BuildContext context) {
    if (tip.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: "Dressing tip: $tip",
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.tips_and_updates,
              size: 18,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tip,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
