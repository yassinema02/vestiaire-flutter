import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";

/// A section displaying sustainability score, factor breakdown, CO2 savings,
/// and percentile comparison.
///
/// Premium-gated: free users see a [PremiumGateCard] instead of the actual
/// sustainability data.
class SustainabilitySection extends StatelessWidget {
  const SustainabilitySection({
    required this.isPremium,
    required this.score,
    required this.factors,
    required this.co2SavedKg,
    required this.co2CarKmEquivalent,
    required this.percentile,
    required this.badgeAwarded,
    this.subscriptionService,
    super.key,
  });

  final bool isPremium;
  final int score;
  final Map<String, dynamic> factors;
  final double co2SavedKg;
  final double co2CarKmEquivalent;
  final int percentile;
  final bool badgeAwarded;
  final SubscriptionService? subscriptionService;

  static Color _scoreColor(int score) {
    if (score <= 33) return const Color(0xFFEF4444);
    if (score <= 66) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: PremiumGateCard(
          title: "Sustainability Score",
          subtitle: "See your environmental impact and CO2 savings",
          icon: Icons.eco_outlined,
          subscriptionService: subscriptionService,
        ),
      );
    }

    final isEmptyState = score == 0 && co2SavedKg == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge notification
          if (badgeAwarded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      label: "You earned the Eco Warrior badge!",
                      child: const Text(
                        "You earned the Eco Warrior badge!",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Section header
          Row(
            children: [
              const Icon(Icons.eco, size: 16, color: Color(0xFF22C55E)),
              const SizedBox(width: 6),
              const Text(
                "Sustainability",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score ring
          Center(
            child: Semantics(
              label: "Sustainability score, $score out of 100",
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

          // Empty state prompt
          if (isEmptyState)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.eco_outlined, size: 32, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Start logging your outfits to see your sustainability impact!",
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),

          // Factor breakdown
          _buildFactorRow("Wear Frequency (30%)", factors["avgWearScore"]),
          _buildFactorRow("Wardrobe Utilization (25%)", factors["utilizationScore"]),
          _buildFactorRow("Cost Efficiency (20%)", factors["cpwScore"]),
          _buildFactorRow("Resale Activity (15%)", factors["resaleScore"]),
          _buildFactorRow("Purchase Restraint (10%)", factors["newPurchaseScore"]),
          const SizedBox(height: 16),

          // CO2 savings card
          Semantics(
            label: "Estimated CO2 saved, ${co2SavedKg.toStringAsFixed(1)} kilograms",
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.eco, size: 24, color: Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      const Text(
                        "Estimated CO2 Saved",
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
                    "${co2SavedKg.toStringAsFixed(1)} kg CO2",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Equivalent to ${co2CarKmEquivalent.toStringAsFixed(1)} km not driven",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String label, dynamic scoreValue) {
    final double factorScore = (scoreValue is num) ? scoreValue.toDouble() : 0.0;
    final int roundedScore = factorScore.round();
    // Extract just the factor name for semantics
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

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.score, required this.color});

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
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
