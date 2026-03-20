import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../outfits/models/trip.dart";

/// A banner widget displayed on the Home screen when an upcoming trip is detected.
///
/// Shows the trip destination, date range, and a "View Packing List" CTA.
/// The banner is dismissible per-trip.
class TravelBanner extends StatelessWidget {
  const TravelBanner({
    required this.trip,
    this.onViewPackingList,
    this.onDismiss,
    super.key,
  });

  final Trip trip;
  final VoidCallback? onViewPackingList;
  final VoidCallback? onDismiss;

  String get _title {
    if (trip.destination.isEmpty) {
      return "Upcoming Trip";
    }
    return "Trip to ${trip.destination}";
  }

  String get _subtitle {
    final formatter = DateFormat("MMM d");
    final start = formatter.format(trip.startDate);
    final end = formatter.format(trip.endDate);
    return "$start - $end (${trip.durationDays} days)";
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Travel mode banner for trip to ${trip.destination.isNotEmpty ? trip.destination : 'unknown destination'}",
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.luggage,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        label: "View packing list button",
                        child: GestureDetector(
                          onTap: onViewPackingList,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "View Packing List",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                label: "Dismiss travel banner",
                child: GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
