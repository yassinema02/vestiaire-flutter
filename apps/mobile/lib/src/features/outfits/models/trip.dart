/// Model representing a detected trip from calendar events.
class Trip {
  const Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.eventIds,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  final String id;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final List<String> eventIds;
  final double? destinationLatitude;
  final double? destinationLongitude;

  factory Trip.fromJson(Map<String, dynamic> json) {
    final coords = json["destinationCoordinates"] as Map<String, dynamic>?;
    final eventIds = (json["eventIds"] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Trip(
      id: json["id"] as String? ?? "",
      destination: json["destination"] as String? ?? "",
      startDate: DateTime.parse(json["startDate"] as String),
      endDate: DateTime.parse(json["endDate"] as String),
      durationDays: (json["durationDays"] as num?)?.toInt() ?? 1,
      eventIds: eventIds,
      destinationLatitude: (coords?["latitude"] as num?)?.toDouble(),
      destinationLongitude: (coords?["longitude"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      "id": id,
      "destination": destination,
      "startDate": startDate.toIso8601String().split("T")[0],
      "endDate": endDate.toIso8601String().split("T")[0],
      "durationDays": durationDays,
      "eventIds": eventIds,
    };
    if (destinationLatitude != null && destinationLongitude != null) {
      json["destinationCoordinates"] = {
        "latitude": destinationLatitude,
        "longitude": destinationLongitude,
      };
    }
    return json;
  }
}
