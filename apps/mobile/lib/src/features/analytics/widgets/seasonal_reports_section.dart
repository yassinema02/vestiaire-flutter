import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";

/// A section displaying seasonal wardrobe reports with accordion-style
/// season cards, readiness scores, historical comparison, transition
/// alerts, and a "View Heatmap" CTA.
///
/// Premium-gated: free users see a [PremiumGateCard] instead.
class SeasonalReportsSection extends StatefulWidget {
  const SeasonalReportsSection({
    required this.isPremium,
    required this.seasons,
    required this.currentSeason,
    required this.transitionAlert,
    required this.onViewHeatmap,
    this.subscriptionService,
    super.key,
  });

  final bool isPremium;
  final List<Map<String, dynamic>> seasons;
  final String currentSeason;
  final Map<String, dynamic>? transitionAlert;
  final VoidCallback onViewHeatmap;
  final SubscriptionService? subscriptionService;

  @override
  State<SeasonalReportsSection> createState() =>
      _SeasonalReportsSectionState();
}

class _SeasonalReportsSectionState extends State<SeasonalReportsSection> {
  late Set<String> _expandedSeasons;

  @override
  void initState() {
    super.initState();
    _expandedSeasons = {widget.currentSeason};
  }

  static const _seasonIcons = <String, IconData>{
    "spring": Icons.local_florist,
    "summer": Icons.wb_sunny,
    "fall": Icons.eco,
    "winter": Icons.ac_unit,
  };

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _readinessColor(int score) {
    if (score <= 3) return const Color(0xFFEF4444); // red
    if (score <= 6) return const Color(0xFFF59E0B); // yellow
    return const Color(0xFF22C55E); // green
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPremium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: PremiumGateCard(
          title: "Seasonal Reports & Heatmap",
          subtitle: "Track your seasonal wearing patterns and daily activity",
          icon: Icons.calendar_month_outlined,
          subscriptionService: widget.subscriptionService,
        ),
      );
    }

    // Check if all seasons have 0 items (empty state)
    final allEmpty = widget.seasons.every(
      (s) => ((s["itemCount"] as num?)?.toInt() ?? 0) == 0,
    );

    if (allEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start logging your outfits to see seasonal patterns!",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Semantics(
            label: "Seasonal reports section",
            child: const Row(
              children: [
                Icon(Icons.calendar_month, size: 20, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text(
                  "Seasonal Reports",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transition alert card
          if (widget.transitionAlert != null) _buildTransitionAlert(),

          // Season accordion
          ...widget.seasons.map((season) => _buildSeasonTile(season)),

          const SizedBox(height: 12),

          // View Heatmap button
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: "View wear heatmap",
              child: OutlinedButton.icon(
                onPressed: widget.onViewHeatmap,
                icon: const Icon(Icons.grid_view),
                label: const Text("View Heatmap"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionAlert() {
    final alert = widget.transitionAlert!;
    final upcomingSeason = alert["upcomingSeason"] as String? ?? "";
    final daysUntil = (alert["daysUntil"] as num?)?.toInt() ?? 0;
    final readinessScore = (alert["readinessScore"] as num?)?.toInt() ?? 1;

    return Semantics(
      label:
          "Transition alert, ${_capitalize(upcomingSeason)} in $daysUntil days",
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedSeasons.add(upcomingSeason);
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${_capitalize(upcomingSeason)} is coming in $daysUntil days! Your readiness: $readinessScore/10",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonTile(Map<String, dynamic> season) {
    final seasonName = season["season"] as String? ?? "";
    final itemCount = (season["itemCount"] as num?)?.toInt() ?? 0;
    final readinessScore = (season["readinessScore"] as num?)?.toInt() ?? 1;
    final mostWorn =
        ((season["mostWorn"] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final neglected =
        ((season["neglected"] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final historicalComparison =
        season["historicalComparison"] as Map<String, dynamic>? ?? {};
    final comparisonText =
        historicalComparison["comparisonText"] as String? ?? "";
    final percentChange = historicalComparison["percentChange"] as num?;
    final isExpanded = _expandedSeasons.contains(seasonName);

    Color comparisonColor;
    if (percentChange == null) {
      comparisonColor = const Color(0xFF9CA3AF); // grey
    } else if (percentChange >= 0) {
      comparisonColor = const Color(0xFF22C55E); // green
    } else {
      comparisonColor = const Color(0xFFEF4444); // red
    }

    return Semantics(
      label:
          "Seasonal reports, $seasonName readiness score $readinessScore out of 10",
      child: ExpansionTile(
        key: ValueKey("season_$seasonName"),
        initiallyExpanded: isExpanded,
        leading: Icon(
          _seasonIcons[seasonName] ?? Icons.help_outline,
          color: const Color(0xFF4F46E5),
        ),
        title: Text(
          _capitalize(seasonName),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(
          "$itemCount items",
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Readiness score progress bar
                _buildReadinessBar(readinessScore),
                const SizedBox(height: 8),

                // Item count
                Text(
                  "$itemCount items for ${_capitalize(seasonName)}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),

                // Historical comparison
                Text(
                  comparisonText,
                  style: TextStyle(
                    fontSize: 13,
                    color: comparisonColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Most worn items
                if (mostWorn.isNotEmpty) ...[
                  Semantics(
                    label: "$seasonName most worn items",
                    child: const Text(
                      "Most Worn",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mostWorn.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = mostWorn[index];
                        return _buildItemThumbnail(item);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Neglected items
                if (neglected.isNotEmpty) ...[
                  Semantics(
                    label: "$seasonName neglected items",
                    child: const Text(
                      "Neglected",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: neglected.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = neglected[index];
                        return _buildNeglectedThumbnail(item);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessBar(int score) {
    return Row(
      children: [
        Text(
          "$score/10",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _readinessColor(score),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 10.0,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  AlwaysStoppedAnimation<Color>(_readinessColor(score)),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemThumbnail(Map<String, dynamic> item) {
    final name = item["name"] as String? ?? "";
    final photoUrl = item["photoUrl"] as String?;

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.checkroom, size: 20),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(Icons.checkroom, size: 20),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.checkroom, size: 20),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeglectedThumbnail(Map<String, dynamic> item) {
    final name = item["name"] as String? ?? "";
    final photoUrl = item["photoUrl"] as String?;

    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: photoUrl != null
                      ? Opacity(
                          opacity: 0.5,
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.checkroom, size: 20),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.checkroom, size: 20),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.checkroom, size: 20),
                        ),
                ),
              ),
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
