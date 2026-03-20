/// Model representing a calendar event synced from the device and classified
/// by the API.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.sourceCalendarId,
    required this.sourceEventId,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    required this.allDay,
    required this.eventType,
    required this.formalityScore,
    required this.classificationSource,
    this.userOverride = false,
  });

  final String id;
  final String sourceCalendarId;
  final String sourceEventId;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;

  /// One of: work, social, active, formal, casual.
  final String eventType;

  /// 1 (very casual) to 10 (very formal).
  final int formalityScore;

  /// One of: keyword, ai, user.
  final String classificationSource;

  /// Whether the user has manually overridden the classification.
  final bool userOverride;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json["id"] as String,
      sourceCalendarId: json["source_calendar_id"] as String,
      sourceEventId: json["source_event_id"] as String,
      title: json["title"] as String,
      description: json["description"] as String?,
      location: json["location"] as String?,
      startTime: DateTime.parse(json["start_time"] as String),
      endTime: DateTime.parse(json["end_time"] as String),
      allDay: json["all_day"] as bool? ?? false,
      eventType: json["event_type"] as String,
      formalityScore: json["formality_score"] as int,
      classificationSource: json["classification_source"] as String,
      userOverride: json["user_override"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "source_calendar_id": sourceCalendarId,
        "source_event_id": sourceEventId,
        "title": title,
        "description": description,
        "location": location,
        "start_time": startTime.toIso8601String(),
        "end_time": endTime.toIso8601String(),
        "all_day": allDay,
        "event_type": eventType,
        "formality_score": formalityScore,
        "classification_source": classificationSource,
        "user_override": userOverride,
      };

  /// Creates a copy of this event with the given fields replaced.
  CalendarEvent copyWith({
    String? eventType,
    int? formalityScore,
    String? classificationSource,
    bool? userOverride,
  }) {
    return CalendarEvent(
      id: id,
      sourceCalendarId: sourceCalendarId,
      sourceEventId: sourceEventId,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
      eventType: eventType ?? this.eventType,
      formalityScore: formalityScore ?? this.formalityScore,
      classificationSource: classificationSource ?? this.classificationSource,
      userOverride: userOverride ?? this.userOverride,
    );
  }
}

/// Lightweight calendar event context for inclusion in [OutfitContext].
///
/// Contains only the fields needed for AI outfit generation prompts.
class CalendarEventContext {
  const CalendarEventContext({
    required this.title,
    required this.eventType,
    required this.formalityScore,
    required this.startTime,
    required this.endTime,
    required this.allDay,
  });

  final String title;
  final String eventType;
  final int formalityScore;
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;

  factory CalendarEventContext.fromCalendarEvent(CalendarEvent event) {
    return CalendarEventContext(
      title: event.title,
      eventType: event.eventType,
      formalityScore: event.formalityScore,
      startTime: event.startTime,
      endTime: event.endTime,
      allDay: event.allDay,
    );
  }

  factory CalendarEventContext.fromJson(Map<String, dynamic> json) {
    return CalendarEventContext(
      title: json["title"] as String,
      eventType: json["eventType"] as String,
      formalityScore: json["formalityScore"] as int,
      startTime: DateTime.parse(json["startTime"] as String),
      endTime: DateTime.parse(json["endTime"] as String),
      allDay: json["allDay"] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        "title": title,
        "eventType": eventType,
        "formalityScore": formalityScore,
        "startTime": startTime.toIso8601String(),
        "endTime": endTime.toIso8601String(),
        "allDay": allDay,
      };
}
