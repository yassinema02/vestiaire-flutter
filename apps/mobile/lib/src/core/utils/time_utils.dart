/// Relative time formatting utility.
///
/// Story 9.3: Social Feed & Filtering
///
/// Provides human-readable relative timestamps for social feed cards
/// and other time-sensitive displays.

/// Format a [DateTime] as a human-readable relative time string.
///
/// Returns:
/// - "Just now" for < 1 minute ago
/// - "Xm ago" for < 1 hour ago
/// - "Xh ago" for < 24 hours ago
/// - "Yesterday" for 24-48 hours ago
/// - "Mar 15" style date string for older
///
/// If [dateTime] is null, returns an empty string.
/// Accepts an optional [now] parameter for testability.
String formatRelativeTime(DateTime? dateTime, {DateTime? now}) {
  if (dateTime == null) return "";
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime);

  if (diff.isNegative) return "Just now";
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  if (diff.inHours < 48) return "Yesterday";

  // For older dates, format as "Mon DD"
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return "${months[dateTime.month - 1]} ${dateTime.day}";
}
