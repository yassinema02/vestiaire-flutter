import "dart:math" as math;

import "package:flutter/material.dart";

/// A section displaying the wardrobe health score with a circular ring,
/// factor breakdown, percentile badge, and actionable recommendation.
///
/// This is a FREE-TIER widget -- no premium gating.
class HealthScoreSection extends StatelessWidget {
  const HealthScoreSection({
    required this.score,
    required this.colorTier,
    required this.factors,
    required this.percentile,
    required this.recommendation,
    required this.totalItems,
    required this.itemsWorn90d,
    this.onSpringCleanTap,
    super.key,
  });

  final int score;
  final String colorTier;
  final Map<String, dynamic> factors;
  final int percentile;
  final String recommendation;
  final int totalItems;
  final int itemsWorn90d;
  final VoidCallback? onSpringCleanTap;

  static Color _tierColor(String tier) {
    switch (tier) {
      case "green":
        return const Color(0xFF22C55E);
      case "yellow":
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  static Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  static Color _recommendationBgColor(String tier) {
    switch (tier) {
      case "green":
        return const Color(0xFFF0FDF4);
      case "yellow":
        return const Color(0xFFFFFBEB);
      default:
        return const Color(0xFFFEF2F2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(colorTier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Icons.health_and_safety, size: 16, color: tierColor),
              const SizedBox(width: 6),
              const Text(
                "Wardrobe Health",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Empty state
          if (totalItems == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.health_and_safety_outlined,
                      size: 32, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Add items to your wardrobe to see your health score!",
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),

          // Score ring
          Center(
            child: Semantics(
              label: "Wardrobe health score, $score out of 100",
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _HealthScoreRingPainter(
                    score: score,
                    color: _scoreColor(score),
                  ),
                  child: Center(
                    child: Text(
                      "$score",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor(score),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "out of 100",
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Percentile badge
          Center(
            child: Semantics(
              label: "Top $percentile percent of users",
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Top $percentile% of Vestiaire users",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Factor breakdown
          _buildFactorRow(
            "Items Worn in 90 Days (50%)",
            factors["utilizationScore"],
          ),
          _buildFactorRow(
            "Cost-Per-Wear Efficiency (30%)",
            factors["cpwScore"],
          ),
          _buildFactorRow(
            "Wardrobe Size Efficiency (20%)",
            factors["sizeUtilizationScore"],
          ),
          const SizedBox(height: 16),

          // Recommendation card
          Semantics(
            label: "Recommendation: $recommendation",
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _recommendationBgColor(colorTier),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 24, color: tierColor),
                      const SizedBox(width: 8),
                      const Text(
                        "Recommendation",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Spring Clean button
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: "Spring Clean",
              child: OutlinedButton.icon(
                onPressed: onSpringCleanTap,
                icon: const Icon(Icons.cleaning_services),
                label: const Text("Spring Clean"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String label, dynamic scoreValue) {
    final double factorScore =
        (scoreValue is num) ? scoreValue.toDouble() : 0.0;
    final int roundedScore = factorScore.round();
    final factorName = label.split(" (").first;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: "Factor $factorName, score $roundedScore out of 100",
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            SizedBox(
              width: 100,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: factorScore / 100,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _scoreColor(roundedScore),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                "$roundedScore",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _scoreColor(roundedScore),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthScoreRingPainter extends CustomPainter {
  _HealthScoreRingPainter({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground ring
    if (score > 0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      final sweepAngle = (score / 100) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HealthScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
