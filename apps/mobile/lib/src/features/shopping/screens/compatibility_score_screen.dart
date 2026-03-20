import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../models/compatibility_score_result.dart";
import "../models/shopping_scan.dart";
import "../services/shopping_scan_service.dart";
import "match_insight_screen.dart";

/// Screen displaying the compatibility score for a shopping scan.
///
/// Shows the overall score gauge, tier, breakdown bars, and reasoning.
/// Handles loading, error, and empty wardrobe states.
///
/// Story 8.4: Purchase Compatibility Scoring (FR-SHP-06, FR-SHP-07)
class CompatibilityScoreScreen extends StatefulWidget {
  const CompatibilityScoreScreen({
    required this.scanId,
    required this.scan,
    required this.shoppingScanService,
    super.key,
  });

  final String scanId;
  final ShoppingScan scan;
  final ShoppingScanService shoppingScanService;

  @override
  State<CompatibilityScoreScreen> createState() =>
      _CompatibilityScoreScreenState();
}

class _CompatibilityScoreScreenState extends State<CompatibilityScoreScreen>
    with SingleTickerProviderStateMixin {
  CompatibilityScoreResult? _result;
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorCode;

  late AnimationController _animationController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _gaugeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _loadScore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadScore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorCode = null;
    });

    try {
      final result = await widget.shoppingScanService
          .scoreCompatibility(widget.scanId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
      _animationController.forward(from: 0.0);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
        _errorCode = e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Compatibility Score"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorCode == "WARDROBE_EMPTY") {
      return _buildEmptyWardrobeState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_result != null) {
      return _buildScoreDisplay();
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.scan.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.scan.imageUrl!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    width: 100,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 32, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.scan.displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Calculating compatibility...",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWardrobeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.checkroom,
                  size: 64,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your wardrobe is empty",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Add some items to your wardrobe first so we can score how well this purchase matches.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: "Go to Wardrobe button",
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to Wardrobe tab
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text("Go to Wardrobe"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Scoring failed",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? "An unexpected error occurred.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: "Retry button",
                  child: ElevatedButton(
                    onPressed: _loadScore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(200, 48),
                    ),
                    child: const Text("Retry"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDisplay() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product summary (compact)
          _buildCompactProductHeader(),
          const SizedBox(height: 24),

          // Score gauge
          _buildScoreGauge(result),
          const SizedBox(height: 16),

          // Reasoning
          if (result.reasoning != null && result.reasoning!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                result.reasoning!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Score breakdown
          _buildBreakdownSection(result.breakdown),
          const SizedBox(height: 24),

          // View Matches & Insights button
          Semantics(
            label: "View Matches and Insights button",
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MatchInsightScreen(
                        scanId: widget.scanId,
                        scan: widget.scan.copyWith(
                          compatibilityScore: _result?.total,
                        ),
                        shoppingScanService: widget.shoppingScanService,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "View Matches & Insights",
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompactProductHeader() {
    final scan = widget.scan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (scan.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                scan.imageUrl!,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 60,
                  width: 60,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(Icons.broken_image,
                      size: 24, color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          if (scan.hasImage) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scan.brand != null)
                  Text(
                    scan.brand!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGauge(CompatibilityScoreResult result) {
    return AnimatedBuilder(
      animation: _gaugeAnimation,
      builder: (context, child) {
        final animatedScore =
            (result.total * _gaugeAnimation.value).round();
        return Column(
          children: [
            Semantics(
              label:
                  "Compatibility score: ${result.total} out of 100",
              child: SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter: _ScoreGaugePainter(
                    score: animatedScore,
                    maxScore: 100,
                    color: result.tier.color,
                    progress: _gaugeAnimation.value,
                  ),
                  child: Center(
                    child: Text(
                      "$animatedScore",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: result.tier.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: "Tier: ${result.tier.label}",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    result.tier.icon,
                    color: result.tier.color,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.tier.label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: result.tier.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdownSection(ScoreBreakdown breakdown) {
    final factors = [
      ("Color Harmony", breakdown.colorHarmony),
      ("Style Consistency", breakdown.styleConsistency),
      ("Gap Filling", breakdown.gapFilling),
      ("Versatility", breakdown.versatility),
      ("Formality Match", breakdown.formalityMatch),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Score Breakdown",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          ...factors.map((f) => _buildBreakdownBar(f.$1, f.$2)),
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(String label, int score) {
    // Color gradient from red (0) to green (100)
    final barColor = Color.lerp(
      const Color(0xFFEF4444),
      const Color(0xFF22C55E),
      score / 100.0,
    )!;

    return Semantics(
      label: "$label: $score out of 100",
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  "$score",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100.0,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the circular score gauge.
class _ScoreGaugePainter extends CustomPainter {
  _ScoreGaugePainter({
    required this.score,
    required this.maxScore,
    required this.color,
    required this.progress,
  });

  final int score;
  final int maxScore;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / maxScore) * math.pi * 1.5 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}
