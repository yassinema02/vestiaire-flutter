import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../core/calendar/calendar_event.dart";
import "../../../core/calendar/calendar_event_service.dart";
import "../../../core/calendar/calendar_preferences_service.dart";
import "../../../core/calendar/calendar_service.dart";
import "../../../core/location/location_service.dart";
import "../../../core/weather/daily_forecast.dart";
import "../../../core/weather/outfit_context.dart";
import "../../../core/weather/outfit_context_service.dart";
import "../../../core/weather/weather_cache_service.dart";
import "../../../core/weather/weather_data.dart";
import "../../../core/weather/weather_service.dart";
import "../../../core/networking/api_client.dart";
import "../../../core/subscription/subscription_service.dart";
import "../../../core/notifications/evening_reminder_preferences.dart";
import "../../../core/notifications/evening_reminder_service.dart";
import "../../../core/notifications/event_reminder_preferences.dart";
import "../../../core/notifications/event_reminder_service.dart";
import "../../../core/notifications/morning_notification_preferences.dart";
import "../../../core/notifications/morning_notification_service.dart";
import "../../outfits/models/trip.dart";
import "../../outfits/screens/packing_list_screen.dart";
import "../../outfits/services/packing_list_service.dart";
import "../../outfits/services/trip_detection_service.dart";
import "../../analytics/screens/analytics_dashboard_screen.dart";
import "../../analytics/screens/wear_calendar_screen.dart";
import "../../analytics/services/wear_log_service.dart";
import "../../analytics/widgets/log_outfit_bottom_sheet.dart";
import "../../outfits/models/outfit_suggestion.dart";
import "../../outfits/models/usage_info.dart";
import "../../outfits/models/usage_limit_result.dart";
import "../../outfits/screens/create_outfit_screen.dart";
import "../../outfits/services/outfit_generation_service.dart";
import "../../outfits/services/outfit_persistence_service.dart";
import "../widgets/calendar_permission_card.dart";
import "../widgets/usage_indicator.dart";
import "../widgets/usage_limit_card.dart";
import "../widgets/dressing_tip_widget.dart";
import "../widgets/event_detail_bottom_sheet.dart";
import "../widgets/event_outfit_bottom_sheet.dart";
import "../widgets/events_section.dart";
import "../widgets/travel_banner.dart";
import "../widgets/forecast_widget.dart";
import "../widgets/location_permission_card.dart";
import "../widgets/outfit_minimum_items_card.dart";
import "../widgets/swipeable_outfit_stack.dart";
import "../widgets/weather_denied_card.dart";
import "../widgets/weather_widget.dart";
import "../widgets/challenge_banner.dart";
import "../../resale/screens/resale_prompts_screen.dart";
import "../../resale/services/resale_prompt_service.dart";
import "calendar_selection_screen.dart";

/// Key used to persist the "Not Now" dismissal in SharedPreferences.
const String kLocationPermissionDismissedKey = "location_permission_dismissed";

/// The Home screen displaying weather information and location permission flow.
///
/// State machine:
/// 1. checking_permission (initial)
/// 2. show_permission_card (not yet requested, not dismissed)
/// 3. loading_weather (permission granted, fetching)
/// 4. weather_loaded (WeatherData available)
/// 5. weather_error (fetch failed)
/// 6. permission_denied (user denied or dismissed)
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.locationService,
    required this.weatherService,
    this.sharedPreferences,
    this.weatherCacheService,
    this.outfitContextService,
    this.calendarService,
    this.calendarPreferencesService,
    this.calendarEventService,
    this.outfitGenerationService,
    this.outfitPersistenceService,
    this.onNavigateToAddItem,
    this.apiClient,
    this.morningNotificationService,
    this.morningNotificationPreferences,
    this.wearLogService,
    this.eveningReminderService,
    this.eveningReminderPreferences,
    this.subscriptionService,
    this.eventReminderService,
    this.eventReminderPreferences,
    this.tripDetectionService,
    this.packingListService,
    this.initialOpenLogSheet = false,
    super.key,
  });

  final LocationService locationService;
  final WeatherService weatherService;

  /// Optional SharedPreferences for test injection.
  final SharedPreferences? sharedPreferences;

  /// Optional WeatherCacheService for test injection.
  final WeatherCacheService? weatherCacheService;

  /// Optional OutfitContextService for test injection.
  final OutfitContextService? outfitContextService;

  /// Optional CalendarService for test injection.
  final CalendarService? calendarService;

  /// Optional CalendarPreferencesService for test injection.
  final CalendarPreferencesService? calendarPreferencesService;

  /// Optional CalendarEventService for test injection.
  final CalendarEventService? calendarEventService;

  /// Optional OutfitGenerationService for test injection.
  final OutfitGenerationService? outfitGenerationService;

  /// Optional OutfitPersistenceService for test injection.
  final OutfitPersistenceService? outfitPersistenceService;

  /// Optional callback for navigating to add item screen.
  final VoidCallback? onNavigateToAddItem;

  /// Optional ApiClient for dependency injection (used by CreateOutfitScreen).
  final ApiClient? apiClient;

  /// Optional MorningNotificationService for updating weather snippet.
  final MorningNotificationService? morningNotificationService;

  /// Optional MorningNotificationPreferences for checking enabled state.
  final MorningNotificationPreferences? morningNotificationPreferences;

  /// Optional WearLogService for logging outfits.
  final WearLogService? wearLogService;

  /// Optional EveningReminderService for updating evening reminder with hasLoggedToday.
  final EveningReminderService? eveningReminderService;

  /// Optional EveningReminderPreferences for checking enabled state.
  final EveningReminderPreferences? eveningReminderPreferences;

  /// Optional SubscriptionService for presenting the RevenueCat paywall
  /// from the UsageLimitCard "Go Premium" CTA.
  final SubscriptionService? subscriptionService;

  /// Optional EventReminderService for scheduling formal event reminders.
  final EventReminderService? eventReminderService;

  /// Optional EventReminderPreferences for reading reminder settings.
  final EventReminderPreferences? eventReminderPreferences;

  /// Optional TripDetectionService for detecting upcoming trips.
  final TripDetectionService? tripDetectionService;

  /// Optional PackingListService for generating and caching packing lists.
  final PackingListService? packingListService;

  /// Whether to automatically open the LogOutfitBottomSheet on load.
  /// Set to true when the user taps the evening notification.
  final bool initialOpenLogSheet;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

/// Visible for testing.
class HomeScreenState extends State<HomeScreen> {
  _HomeState _state = _HomeState.checkingPermission;
  _CalendarState _calendarState = _CalendarState.unknown;
  WeatherData? _weatherData;
  List<DailyForecast>? _forecastData;
  String? _errorMessage;
  String? _lastUpdatedLabel;

  /// The current outfit context, available after weather loads.
  /// Stored for use by Story 4.1 (AI outfit generation).
  OutfitContext? outfitContext;
  String? _dressingTip;
  List<CalendarEvent> _calendarEvents = [];

  // Outfit generation state
  OutfitGenerationResult? _outfitResult;
  bool _isGeneratingOutfit = false;
  String? _outfitError;
  List<dynamic>? _wardrobeItems;

  // Usage limit state
  UsageInfo? _usageInfo;
  UsageLimitReachedResult? _limitReached;

  // Challenge state
  Map<String, dynamic>? _challengeData;

  // ignore: unused_field
  int _savedOutfitCount = 0;

  // Trip detection state
  Trip? _detectedTrip;

  // Resale prompt state
  int _resalePromptCount = 0;
  bool _tripBannerDismissed = false;

  SharedPreferences? _prefs;
  late WeatherCacheService _cacheService;
  late OutfitContextService _outfitContextService;
  late CalendarService _calendarService;
  late CalendarPreferencesService _calendarPreferencesService;
  CalendarEventService? _calendarEventService;
  OutfitGenerationService? _outfitGenerationService;
  OutfitPersistenceService? _outfitPersistenceService;

  @override
  void initState() {
    super.initState();
    _cacheService = widget.weatherCacheService ?? WeatherCacheService();
    _outfitContextService =
        widget.outfitContextService ?? OutfitContextService();
    _calendarService = widget.calendarService ?? CalendarService();
    _calendarPreferencesService =
        widget.calendarPreferencesService ?? CalendarPreferencesService();
    _calendarEventService = widget.calendarEventService;
    _outfitGenerationService = widget.outfitGenerationService;
    _outfitPersistenceService = widget.outfitPersistenceService;
    _initialize();
    _updateEveningReminder();
    if (widget.initialOpenLogSheet) {
      // Schedule the bottom sheet to open after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openLogOutfitSheet();
      });
    }
  }

  Future<void> _initialize() async {
    _prefs = widget.sharedPreferences ?? await SharedPreferences.getInstance();
    await _checkPermissionAndLoad();
    await _checkCalendarStatus();
    if (_calendarState == _CalendarState.connected) {
      await _fetchCalendarEvents();
    }
    _loadChallengeData();
    _loadResalePromptData();
  }

  Future<void> _loadChallengeData() async {
    if (widget.apiClient == null) return;
    try {
      final result = await widget.apiClient!.getUserStats();
      if (!mounted) return;
      final stats = result["stats"] as Map<String, dynamic>?;
      if (stats != null) {
        final challenge = stats["challenge"];
        if (challenge is Map<String, dynamic> &&
            challenge["status"] == "active") {
          setState(() {
            _challengeData = challenge;
          });
        }
      }
    } catch (_) {
      // Graceful degradation -- do not affect HomeScreen.
    }
  }

  /// Load resale prompt count and trigger monthly evaluation if needed.
  Future<void> _loadResalePromptData() async {
    if (widget.apiClient == null) return;
    try {
      final service = ResalePromptService(apiClient: widget.apiClient!);
      final prefs = _prefs ?? await SharedPreferences.getInstance();

      // Check if monthly evaluation is needed (debounce to once per 30 days)
      final lastEvaluation = prefs.getString("last_resale_evaluation");
      final shouldEvaluate = lastEvaluation == null ||
          DateTime.now()
                  .difference(DateTime.tryParse(lastEvaluation) ?? DateTime(2000))
                  .inDays >
              30;

      if (shouldEvaluate) {
        await service.triggerEvaluation();
        await prefs.setString(
            "last_resale_evaluation", DateTime.now().toIso8601String());
      }

      final count = await service.fetchPendingCount();
      if (!mounted) return;
      setState(() {
        _resalePromptCount = count;
      });
    } catch (_) {
      // Graceful degradation -- do not affect HomeScreen.
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final permission = await widget.locationService.checkPermission();

    if (!mounted) return;

    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        _fetchWeather();
        break;
      case LocationPermission.denied:
        final dismissed =
            _prefs?.getBool(kLocationPermissionDismissedKey) ?? false;
        setState(() {
          _state = dismissed
              ? _HomeState.permissionDenied
              : _HomeState.showPermissionCard;
        });
        break;
      case LocationPermission.deniedForever:
        setState(() {
          _state = _HomeState.permissionDenied;
        });
        break;
      case LocationPermission.unableToDetermine:
        final dismissed =
            _prefs?.getBool(kLocationPermissionDismissedKey) ?? false;
        setState(() {
          _state = dismissed
              ? _HomeState.permissionDenied
              : _HomeState.showPermissionCard;
        });
        break;
    }
  }

  Future<void> _checkCalendarStatus() async {
    final connected = await _calendarPreferencesService.isCalendarConnected();
    if (connected) {
      if (!mounted) return;
      setState(() {
        _calendarState = _CalendarState.connected;
      });
      return;
    }

    final dismissed = await _calendarPreferencesService.isCalendarDismissed();
    if (dismissed) {
      if (!mounted) return;
      setState(() {
        _calendarState = _CalendarState.dismissed;
      });
      return;
    }

    // Check actual permission status
    final permStatus = await _calendarService.checkPermission();
    if (!mounted) return;

    if (permStatus == CalendarPermissionStatus.granted) {
      // User granted permission outside the app
      await _calendarPreferencesService.setCalendarConnected(true);
      setState(() {
        _calendarState = _CalendarState.connected;
      });
    } else {
      setState(() {
        _calendarState = _CalendarState.promptVisible;
      });
    }
  }

  Future<void> _fetchWeather() async {
    // 1. Check cache first
    final cachedWeather = await _cacheService.getCachedWeather();
    if (cachedWeather != null) {
      if (!mounted) return;
      final ctx = _outfitContextService.buildContextFromWeather(
        cachedWeather.currentWeather,
      );
      setState(() {
        _state = _HomeState.weatherLoaded;
        _weatherData = cachedWeather.currentWeather;
        _forecastData = cachedWeather.forecast;
        outfitContext = ctx;
        _dressingTip = ctx.clothingConstraints.primaryTip;
        // Only show staleness label if cache is > 5 minutes old
        final ageMinutes =
            DateTime.now().difference(cachedWeather.cachedAt).inMinutes;
        _lastUpdatedLabel =
            ageMinutes > 5 ? cachedWeather.lastUpdatedLabel : null;
      });
      // Trigger outfit generation after weather loads from cache
      _triggerOutfitGeneration();
      _updateMorningNotificationWeather();
      return;
    }

    // 2. No valid cache -- show loading and fetch fresh data
    setState(() {
      _state = _HomeState.loadingWeather;
      _errorMessage = null;
      _lastUpdatedLabel = null;
    });

    final position = await widget.locationService.getCurrentPosition();
    if (!mounted) return;

    if (position == null) {
      setState(() {
        _state = _HomeState.weatherError;
        _errorMessage = "Unable to determine your location";
      });
      return;
    }

    try {
      final locationName = await widget.locationService.getLocationName(
        position.latitude,
        position.longitude,
      );
      final response = await widget.weatherService.fetchWeather(
        position.latitude,
        position.longitude,
        locationName,
      );
      if (!mounted) return;

      // Cache the fresh data
      await _cacheService.cacheWeatherData(response.current, response.forecast);

      final ctx = _outfitContextService.buildContextFromWeather(
        response.current,
      );
      setState(() {
        _state = _HomeState.weatherLoaded;
        _weatherData = response.current;
        _forecastData = response.forecast;
        outfitContext = ctx;
        _dressingTip = ctx.clothingConstraints.primaryTip;
        _lastUpdatedLabel = null;
      });
      // Trigger outfit generation after weather loads
      _triggerOutfitGeneration();
      _updateMorningNotificationWeather();
    } on WeatherFetchException catch (e) {
      if (!mounted) return;
      // Check for stale cache to show as fallback
      final staleCache = await _cacheService.getStaleCachedWeather();
      if (staleCache != null) {
        final ctx = _outfitContextService.buildContextFromWeather(
          staleCache.currentWeather,
        );
        setState(() {
          _state = _HomeState.weatherLoaded;
          _weatherData = staleCache.currentWeather;
          _forecastData = staleCache.forecast;
          outfitContext = ctx;
          _dressingTip = ctx.clothingConstraints.primaryTip;
          _lastUpdatedLabel = staleCache.lastUpdatedLabel;
        });
        _triggerOutfitGeneration();
        _updateMorningNotificationWeather();
      } else {
        setState(() {
          _state = _HomeState.weatherError;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Check for stale cache to show as fallback
      final staleCache = await _cacheService.getStaleCachedWeather();
      if (staleCache != null) {
        final ctx = _outfitContextService.buildContextFromWeather(
          staleCache.currentWeather,
        );
        setState(() {
          _state = _HomeState.weatherLoaded;
          _weatherData = staleCache.currentWeather;
          _forecastData = staleCache.forecast;
          outfitContext = ctx;
          _dressingTip = ctx.clothingConstraints.primaryTip;
          _lastUpdatedLabel = staleCache.lastUpdatedLabel;
        });
        _triggerOutfitGeneration();
        _updateMorningNotificationWeather();
      } else {
        setState(() {
          _state = _HomeState.weatherError;
          _errorMessage = "Weather unavailable";
        });
      }
    }
  }

  /// Trigger outfit generation after weather loads.
  /// Fetches wardrobe items and then generates outfits if conditions are met.
  void _triggerOutfitGeneration() {
    if (_outfitGenerationService == null) return;
    if (outfitContext == null) return;
    _fetchWardrobeItemsAndGenerate();
  }

  /// Updates the evening reminder with the current hasLoggedToday status.
  ///
  /// Fire-and-forget -- errors do not affect the HomeScreen.
  void _updateEveningReminder() {
    if (widget.eveningReminderService == null) return;

    () async {
      try {
        final prefs = widget.eveningReminderPreferences;
        if (prefs != null) {
          final enabled = await prefs.isWearLoggingEnabled();
          if (!enabled) return;
        }

        bool hasLoggedToday = false;
        if (widget.wearLogService != null) {
          try {
            hasLoggedToday = await widget.eveningReminderService!
                .hasLoggedToday(widget.wearLogService!);
          } catch (_) {
            // Graceful degradation
          }
        }

        final time = await (widget.eveningReminderPreferences
                ?.getEveningTime() ??
            Future.value(const TimeOfDay(hour: 20, minute: 0)));

        await widget.eveningReminderService!.scheduleEveningReminder(
          time: time,
          hasLoggedToday: hasLoggedToday,
        );
      } catch (_) {
        // Graceful degradation -- do not affect HomeScreen.
      }
    }();
  }

  /// Updates the morning notification with a fresh weather snippet.
  ///
  /// Fire-and-forget -- errors do not affect the HomeScreen.
  void _updateMorningNotificationWeather() {
    if (widget.morningNotificationService == null) return;
    if (_weatherData == null) return;

    () async {
      try {
        final prefs = widget.morningNotificationPreferences;
        if (prefs != null) {
          final enabled = await prefs.isOutfitRemindersEnabled();
          if (!enabled) return;
        }

        final snippet = MorningNotificationService.buildWeatherSnippet(
          _weatherData!.temperature,
          _weatherData!.weatherDescription,
        );

        final time = await (widget.morningNotificationPreferences
                ?.getMorningTime() ??
            Future.value(const TimeOfDay(hour: 8, minute: 0)));

        await widget.morningNotificationService!.scheduleMorningNotification(
          time: time,
          weatherSnippet: snippet,
        );
      } catch (_) {
        // Graceful degradation -- do not affect HomeScreen.
      }
    }();
  }

  Future<void> _fetchWardrobeItemsAndGenerate() async {
    // This is a simplified version -- in production, we'd call ApiClient.listItems()
    // but for now, if the service is injected (test scenarios), we proceed
    await _generateOutfits();
  }

  Future<void> _generateOutfits() async {
    if (_outfitGenerationService == null) return;
    if (outfitContext == null) return;

    // Check minimum items if _wardrobeItems is available
    if (_wardrobeItems != null &&
        !OutfitGenerationService.hasEnoughItems(_wardrobeItems!)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isGeneratingOutfit = true;
      _outfitError = null;
      _limitReached = null;
    });

    final response =
        await _outfitGenerationService!.generateOutfits(outfitContext!);

    if (!mounted) return;
    setState(() {
      _isGeneratingOutfit = false;
      if (response.limitReached != null) {
        _limitReached = response.limitReached;
        _outfitResult = null;
        _usageInfo = null;
      } else if (response.result != null && response.result!.suggestions.isNotEmpty) {
        _outfitResult = response.result;
        _usageInfo = response.result!.usage;
        _outfitError = null;
        _limitReached = null;
      } else {
        _outfitError =
            "Unable to generate outfit suggestions right now. Pull to refresh to try again.";
      }
    });
  }

  /// Set wardrobe items for the minimum-items check.
  /// Called externally or via ApiClient.listItems().
  // ignore: use_setters_to_change_properties
  void setWardrobeItems(List<dynamic> items) {
    setState(() {
      _wardrobeItems = items;
    });
  }

  Future<void> _handleEnableLocation() async {
    final permission = await widget.locationService.requestPermission();
    if (!mounted) return;

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _fetchWeather();
    } else {
      setState(() {
        _state = _HomeState.permissionDenied;
      });
    }
  }

  Future<void> _handleNotNow() async {
    await _prefs?.setBool(kLocationPermissionDismissedKey, true);
    if (!mounted) return;
    setState(() {
      _state = _HomeState.permissionDenied;
    });
  }

  Future<void> _handleGrantAccess() async {
    await widget.locationService.openLocationSettings();
  }

  Future<void> _fetchCalendarEvents() async {
    if (_calendarEventService == null) return;
    try {
      final events = await _calendarEventService!.fetchAndSyncEvents();
      if (!mounted) return;
      setState(() {
        _calendarEvents = events;
      });
      // Fire-and-forget: update event reminder with fresh calendar data
      _updateEventReminder(events);
      // Fire-and-forget: detect upcoming trips
      _detectTrips();
    } catch (_) {
      // Graceful degradation: do not crash on calendar fetch failure
    }
  }

  /// Detect upcoming trips from calendar events.
  ///
  /// Story 12.4: Fire-and-forget -- the banner appears when data arrives.
  Future<void> _detectTrips() async {
    if (widget.tripDetectionService == null) return;
    try {
      final trips = await widget.tripDetectionService!.detectTrips();
      if (!mounted) return;
      if (trips.isEmpty) return;

      // Find the first trip approaching within 3 days, or the soonest
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));
      Trip? bestTrip;
      for (final trip in trips) {
        if (trip.startDate.isBefore(threeDaysFromNow)) {
          bestTrip = trip;
          break;
        }
      }
      bestTrip ??= trips.first;

      // Check if dismissed
      final dismissed =
          _prefs?.getBool("trip_dismissed_${bestTrip.id}") ?? false;

      setState(() {
        _detectedTrip = bestTrip;
        _tripBannerDismissed = dismissed;
      });
    } catch (_) {
      // Graceful degradation
    }
  }

  void _handleDismissTripBanner() {
    if (_detectedTrip == null) return;
    _prefs?.setBool("trip_dismissed_${_detectedTrip!.id}", true);
    if (!mounted) return;
    setState(() {
      _tripBannerDismissed = true;
    });
  }

  void _navigateToPackingList() {
    if (_detectedTrip == null || widget.packingListService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackingListScreen(
          trip: _detectedTrip!,
          packingListService: widget.packingListService!,
        ),
      ),
    );
  }

  /// Re-evaluates tomorrow's formal events and reschedules the event reminder.
  ///
  /// Story 12.3: This runs after calendar events load to ensure the reminder
  /// has the most up-to-date information about tomorrow's formal events.
  Future<void> _updateEventReminder(List<CalendarEvent> events) async {
    if (widget.eventReminderService == null ||
        widget.eventReminderPreferences == null) return;
    try {
      final enabled =
          await widget.eventReminderPreferences!.isEventRemindersEnabled();
      if (!enabled) return;

      final threshold =
          await widget.eventReminderPreferences!.getFormalityThreshold();
      final time =
          await widget.eventReminderPreferences!.getEventReminderTime();

      // Filter tomorrow's events by formality threshold
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStart =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));

      final tomorrowEvents = events.where((e) =>
          e.startTime.isAfter(tomorrowStart) &&
          e.startTime.isBefore(tomorrowEnd)).toList();

      final formalEvents = EventReminderService.filterFormalEvents(
          tomorrowEvents, threshold);

      await widget.eventReminderService!.scheduleEventReminder(
        time: time,
        formalEvents: formalEvents,
      );
    } catch (e) {
      debugPrint("Error updating event reminder: $e");
    }
  }

  Future<bool> _handleOutfitSave(OutfitSuggestion suggestion) async {
    if (_outfitPersistenceService == null) return false;

    final result = await _outfitPersistenceService!.saveOutfit(suggestion);

    if (!mounted) return false;

    if (result != null) {
      _savedOutfitCount++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Outfit saved!")),
      );
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save outfit. Please try again."),
        ),
      );
      return false;
    }
  }

  Future<void> _handleRefresh() async {
    _savedOutfitCount = 0;
    _limitReached = null;
    _usageInfo = null;
    final permission = await widget.locationService.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _cacheService.clearCache();
      await _fetchWeather();
    }
    if (_calendarState == _CalendarState.connected) {
      await _fetchCalendarEvents();
    }
  }

  Future<void> _handleConnectCalendar() async {
    final permStatus = await _calendarService.requestPermission();
    if (!mounted) return;

    if (permStatus == CalendarPermissionStatus.granted) {
      final calendars = await _calendarService.getCalendars();
      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarSelectionScreen(
            calendars: calendars,
            calendarPreferencesService: _calendarPreferencesService,
          ),
        ),
      );

      if (!mounted) return;
      if (result == true) {
        setState(() {
          _calendarState = _CalendarState.connected;
        });
      }
    } else {
      setState(() {
        _calendarState = _CalendarState.denied;
      });
    }
  }

  Future<void> _handleCalendarNotNow() async {
    await _calendarPreferencesService.setCalendarDismissed(true);
    if (!mounted) return;
    setState(() {
      _calendarState = _CalendarState.dismissed;
    });
  }

  void _handleEventTap(CalendarEvent event) {
    showEventDetailBottomSheet(
      context,
      event: event,
      onSave: (updatedEvent) async {
        final result = await _calendarEventService?.updateEventOverride(
          event.id,
          eventType: updatedEvent.eventType,
          formalityScore: updatedEvent.formalityScore,
        );
        if (!mounted) return;
        if (result != null) {
          setState(() {
            _calendarEvents = _calendarEvents.map((e) {
              return e.id == event.id ? result : e;
            }).toList();
          });
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Failed to update event classification. Please try again."),
            ),
          );
        }
      },
    );
  }

  void _handleEventOutfitTap(CalendarEvent event) {
    if (_outfitGenerationService == null) return;
    showEventOutfitBottomSheet(
      context,
      event: event,
      outfitGenerationService: _outfitGenerationService!,
      outfitContext: outfitContext,
    );
  }

  Future<void> _handleCalendarGrantAccess() async {
    await GeolocatorPlatform.instance.openAppSettings();
  }

  void _openLogOutfitSheet() {
    if (widget.wearLogService == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => LogOutfitBottomSheet(
        wearLogService: widget.wearLogService!,
        apiClient: widget.apiClient,
        onLogged: () {
          if (mounted) {
            setState(() {
              // Refresh state to update any displayed wear counts
            });
          }
        },
      ),
    );
  }

  void _navigateToAddItem() {
    if (widget.onNavigateToAddItem != null) {
      widget.onNavigateToAddItem!();
    }
  }

  Future<void> _navigateToCreateOutfit() async {
    if (widget.apiClient == null || _outfitPersistenceService == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOutfitScreen(
          apiClient: widget.apiClient!,
          outfitPersistenceService: _outfitPersistenceService!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _state == _HomeState.weatherLoaded &&
        _outfitPersistenceService != null &&
        widget.apiClient != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Vestiaire"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      floatingActionButton: showFab
          ? Semantics(
              label: "Create a new outfit manually",
              child: FloatingActionButton(
                onPressed: _navigateToCreateOutfit,
                backgroundColor: const Color(0xFF4F46E5),
                tooltip: "Create Outfit",
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildWeatherSection(),
              if (_challengeData != null) ...[
                const SizedBox(height: 12),
                ChallengeBanner(
                  name: _challengeData!["name"] as String? ?? "Closet Safari",
                  currentProgress:
                      (_challengeData!["currentProgress"] as num?)?.toInt() ?? 0,
                  targetCount:
                      (_challengeData!["targetCount"] as num?)?.toInt() ?? 20,
                  timeRemainingSeconds:
                      (_challengeData!["timeRemainingSeconds"] as num?)?.toInt(),
                  onTap: null, // Could navigate to Profile tab
                ),
              ],
              if (_resalePromptCount > 0 && widget.apiClient != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  label: "You have $_resalePromptCount item${_resalePromptCount > 1 ? 's' : ''} to declutter, tap to view resale suggestions",
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResalePromptsScreen(
                            apiClient: widget.apiClient!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sell, size: 20, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You have $_resalePromptCount item${_resalePromptCount > 1 ? 's' : ''} to declutter",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const Text(
                            "View",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (_forecastData != null &&
                  _forecastData!.isNotEmpty &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 12),
                ForecastWidget(forecast: _forecastData!),
              ],
              if (_dressingTip != null &&
                  _dressingTip!.isNotEmpty &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 8),
                DressingTipWidget(tip: _dressingTip!),
              ],
              if (_detectedTrip != null &&
                  !_tripBannerDismissed &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 12),
                TravelBanner(
                  trip: _detectedTrip!,
                  onViewPackingList: _navigateToPackingList,
                  onDismiss: _handleDismissTripBanner,
                ),
              ],
              if (_calendarState == _CalendarState.promptVisible &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 16),
                CalendarPermissionCard(
                  onConnectCalendar: _handleConnectCalendar,
                  onNotNow: _handleCalendarNotNow,
                ),
              ],
              if (_calendarState == _CalendarState.denied &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 16),
                CalendarDeniedCard(
                    onGrantAccess: _handleCalendarGrantAccess),
              ],
              if (_calendarState == _CalendarState.connected &&
                  _state == _HomeState.weatherLoaded) ...[
                const SizedBox(height: 12),
                EventsSection(
                  events: _calendarEvents,
                  onEventTap: _handleEventOutfitTap,
                  onEditClassification: _handleEventTap,
                ),
              ],
              const SizedBox(height: 24),
              _buildOutfitSection(),
              if (widget.wearLogService != null) ...[
                const SizedBox(height: 16),
                _buildLogOutfitButton(),
                const SizedBox(height: 12),
                _buildWearCalendarButton(),
                const SizedBox(height: 12),
                _buildAnalyticsButton(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogOutfitButton() {
    return Semantics(
      label: "Log Today's Outfit",
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _openLogOutfitSheet,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Log Today's Outfit"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            side: const BorderSide(color: Color(0xFF4F46E5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWearCalendarButton() {
    return Semantics(
      label: "View wear calendar",
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _navigateToWearCalendar,
          icon: const Icon(Icons.calendar_month),
          label: const Text("Wear Calendar"),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToWearCalendar() {
    if (widget.wearLogService == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WearCalendarScreen(
          wearLogService: widget.wearLogService!,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Widget _buildAnalyticsButton() {
    if (widget.apiClient == null) return const SizedBox.shrink();
    return Semantics(
      label: "View analytics dashboard",
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _navigateToAnalytics,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text("Analytics"),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAnalytics() {
    if (widget.apiClient == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsDashboardScreen(
          apiClient: widget.apiClient!,
          onNavigateToAddItem: widget.onNavigateToAddItem,
        ),
      ),
    );
  }

  Widget _buildOutfitSection() {
    // Weather not loaded -- show nothing (weather is required for generation)
    if (_state != _HomeState.weatherLoaded) {
      return const SizedBox.shrink();
    }

    // No outfit generation service injected -- show placeholder
    if (_outfitGenerationService == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          "Daily outfit suggestions coming soon",
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Check minimum items
    if (_wardrobeItems != null &&
        !OutfitGenerationService.hasEnoughItems(_wardrobeItems!)) {
      return OutfitMinimumItemsCard(onAddItems: _navigateToAddItem);
    }

    // Usage limit reached state
    if (_limitReached != null) {
      return UsageLimitCard(
        limitInfo: _limitReached!,
        subscriptionService: widget.subscriptionService,
      );
    }

    // Loading state
    if (_isGeneratingOutfit) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      );
    }

    // Success state -- show swipeable outfit stack
    if (_outfitResult != null && _outfitResult!.suggestions.isNotEmpty) {
      final showUsageIndicator =
          _usageInfo != null && !_usageInfo!.isPremium;
      if (showUsageIndicator) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwipeableOutfitStack(
              suggestions: _outfitResult!.suggestions,
              onSave: _handleOutfitSave,
              onAllReviewed: null,
            ),
            const SizedBox(height: 8),
            UsageIndicator(usageInfo: _usageInfo!),
          ],
        );
      }
      return SwipeableOutfitStack(
        suggestions: _outfitResult!.suggestions,
        onSave: _handleOutfitSave,
        onAllReviewed: null,
      );
    }

    // Error state
    if (_outfitError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 32,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              _outfitError!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _generateOutfits,
              child: const Text(
                "Retry",
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default: show placeholder if no generation service actions happened
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        "Daily outfit suggestions coming soon",
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildWeatherSection() {
    switch (_state) {
      case _HomeState.checkingPermission:
        return const WeatherWidget(isLoading: true);
      case _HomeState.showPermissionCard:
        return LocationPermissionCard(
          onEnableLocation: _handleEnableLocation,
          onNotNow: _handleNotNow,
        );
      case _HomeState.loadingWeather:
        return const WeatherWidget(isLoading: true);
      case _HomeState.weatherLoaded:
        return WeatherWidget(
          weatherData: _weatherData,
          lastUpdatedLabel: _lastUpdatedLabel,
        );
      case _HomeState.weatherError:
        return WeatherWidget(
          errorMessage: _errorMessage,
          onRetry: _fetchWeather,
        );
      case _HomeState.permissionDenied:
        return WeatherDeniedCard(onGrantAccess: _handleGrantAccess);
    }
  }
}

enum _HomeState {
  checkingPermission,
  showPermissionCard,
  loadingWeather,
  weatherLoaded,
  weatherError,
  permissionDenied,
}

enum _CalendarState {
  unknown,
  promptVisible,
  denied,
  connected,
  dismissed,
}
