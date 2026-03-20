/// Models for donation log entries and summaries.
///
/// Story 13.3: Spring Clean Declutter Flow & Donations (FR-DON-02, FR-DON-03)

/// A single donation log entry with optional item metadata.
class DonationLogEntry {
  const DonationLogEntry({
    required this.id,
    required this.itemId,
    this.charityName,
    required this.estimatedValue,
    required this.donationDate,
    required this.createdAt,
    this.itemName,
    this.itemPhotoUrl,
    this.itemCategory,
    this.itemBrand,
  });

  final String id;
  final String itemId;
  final String? charityName;
  final double estimatedValue;
  final DateTime donationDate;
  final DateTime createdAt;
  final String? itemName;
  final String? itemPhotoUrl;
  final String? itemCategory;
  final String? itemBrand;

  factory DonationLogEntry.fromJson(Map<String, dynamic> json) {
    return DonationLogEntry(
      id: json["id"] as String,
      itemId: json["itemId"] as String,
      charityName: json["charityName"] as String?,
      estimatedValue: (json["estimatedValue"] as num?)?.toDouble() ?? 0.0,
      donationDate: DateTime.parse(json["donationDate"] as String),
      createdAt: DateTime.parse(json["createdAt"] as String),
      itemName: json["itemName"] as String?,
      itemPhotoUrl: json["itemPhotoUrl"] as String?,
      itemCategory: json["itemCategory"] as String?,
      itemBrand: json["itemBrand"] as String?,
    );
  }
}

/// Summary of all donations for the authenticated user.
class DonationSummary {
  const DonationSummary({
    required this.totalDonated,
    required this.totalValue,
  });

  final int totalDonated;
  final double totalValue;

  factory DonationSummary.fromJson(Map<String, dynamic> json) {
    return DonationSummary(
      totalDonated: (json["totalDonated"] as num?)?.toInt() ?? 0,
      totalValue: (json["totalValue"] as num?)?.toDouble() ?? 0.0,
    );
  }
}
