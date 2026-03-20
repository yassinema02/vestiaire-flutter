/// Maps weather conditions to practical clothing constraints.
///
/// This is a pure static utility class with no dependencies. It takes weather
/// data (code + feels-like temperature) and produces clothing constraints
/// that inform outfit generation (Story 4.1) and the user-facing dressing tip.
class ClothingConstraints {
  const ClothingConstraints({
    this.requiredCategories = const [],
    this.preferredMaterials = const [],
    this.avoidMaterials = const [],
    this.preferredSeasons = const [],
    this.preferredColors = const [],
    this.temperatureCategory = "mild",
    this.advisories = const [],
    this.requiresWaterproof = false,
    this.requiresLayering = false,
  });

  final List<String> requiredCategories;
  final List<String> preferredMaterials;
  final List<String> avoidMaterials;
  final List<String> preferredSeasons;
  final List<String> preferredColors;
  final String temperatureCategory;
  final List<String> advisories;
  final bool requiresWaterproof;
  final bool requiresLayering;

  /// Returns the single most relevant dressing tip for the UI.
  ///
  /// Priority order: thunderstorm > rain/snow waterproof > cold > cool > hot > mild.
  String get primaryTip {
    if (advisories.any((a) => a.contains("Severe weather"))) {
      return "Severe weather expected \u2013 dress practically";
    }
    if (requiresWaterproof && temperatureCategory == "cold") {
      return "Bundle up with waterproof layers";
    }
    if (requiresWaterproof) {
      return "Grab a waterproof jacket \u2013 rain expected";
    }
    if (temperatureCategory == "cold") {
      return "Layer up with warm fabrics today";
    }
    if (temperatureCategory == "cool") {
      return "A light jacket or layers will keep you comfortable";
    }
    if (temperatureCategory == "hot") {
      return "Light and breezy \u2013 perfect for cotton and linen";
    }
    return "Comfortable day \u2013 dress as you like";
  }

  /// Serializes all fields for inclusion in the outfit context object.
  Map<String, dynamic> toJson() => {
        "requiredCategories": requiredCategories,
        "preferredMaterials": preferredMaterials,
        "avoidMaterials": avoidMaterials,
        "preferredSeasons": preferredSeasons,
        "preferredColors": preferredColors,
        "temperatureCategory": temperatureCategory,
        "advisories": advisories,
        "requiresWaterproof": requiresWaterproof,
        "requiresLayering": requiresLayering,
      };

  /// Deserializes from JSON.
  factory ClothingConstraints.fromJson(Map<String, dynamic> json) =>
      ClothingConstraints(
        requiredCategories:
            List<String>.from(json["requiredCategories"] as List? ?? []),
        preferredMaterials:
            List<String>.from(json["preferredMaterials"] as List? ?? []),
        avoidMaterials:
            List<String>.from(json["avoidMaterials"] as List? ?? []),
        preferredSeasons:
            List<String>.from(json["preferredSeasons"] as List? ?? []),
        preferredColors:
            List<String>.from(json["preferredColors"] as List? ?? []),
        temperatureCategory:
            json["temperatureCategory"] as String? ?? "mild",
        advisories: List<String>.from(json["advisories"] as List? ?? []),
        requiresWaterproof: json["requiresWaterproof"] as bool? ?? false,
        requiresLayering: json["requiresLayering"] as bool? ?? false,
      );
}

/// Static utility that maps weather conditions to clothing constraints.
///
/// Uses a layered approach: first compute temperature-based constraints,
/// then overlay precipitation-based constraints on top.
class WeatherClothingMapper {
  WeatherClothingMapper._();

  /// Rain weather codes: drizzle (51-55), rain (61-65), freezing rain (66-67),
  /// rain showers (80-82).
  static const _rainCodes = {51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82};

  /// Snow weather codes: snow (71-77), snow showers (85-86).
  static const _snowCodes = {71, 73, 75, 77, 85, 86};

  /// Thunderstorm weather codes: 95, 96, 99.
  static const _thunderstormCodes = {95, 96, 99};

  /// Fog weather codes: 45, 48.
  static const _fogCodes = {45, 48};

  /// Freezing precipitation codes: freezing drizzle (56-57), freezing rain (66-67).
  static const _freezingCodes = {56, 57, 66, 67};

  /// Maps weather conditions to clothing constraints.
  ///
  /// [weatherCode] is the WMO weather code (0-99).
  /// [feelsLikeTemperature] is the "feels like" temperature in Celsius.
  static ClothingConstraints mapWeatherToClothing(
    int weatherCode,
    double feelsLikeTemperature,
  ) {
    // Step 1: Temperature-based constraints
    final tempConstraints = _mapTemperature(feelsLikeTemperature);

    // Step 2: Precipitation overlays
    return _applyPrecipitationOverlay(weatherCode, tempConstraints);
  }

  static ClothingConstraints _mapTemperature(double feelsLike) {
    if (feelsLike > 28) {
      // Hot weather
      return const ClothingConstraints(
        preferredMaterials: ["cotton", "linen", "mesh", "chiffon"],
        avoidMaterials: [
          "wool", "fleece", "leather", "cashmere", "velvet", "corduroy",
        ],
        preferredSeasons: ["summer", "all"],
        temperatureCategory: "hot",
        requiresLayering: false,
      );
    } else if (feelsLike >= 15) {
      // Mild weather
      return const ClothingConstraints(
        preferredMaterials: [],
        avoidMaterials: [],
        preferredSeasons: ["spring", "summer", "fall", "all"],
        temperatureCategory: "mild",
      );
    } else if (feelsLike >= 5) {
      // Cool weather
      return const ClothingConstraints(
        preferredMaterials: ["wool", "knit", "fleece", "denim", "corduroy"],
        avoidMaterials: [],
        preferredSeasons: ["fall", "spring", "all"],
        temperatureCategory: "cool",
        requiresLayering: true,
      );
    } else {
      // Cold weather
      return const ClothingConstraints(
        requiredCategories: ["outerwear"],
        preferredMaterials: ["wool", "cashmere", "fleece", "knit"],
        avoidMaterials: ["mesh", "chiffon", "linen"],
        preferredSeasons: ["winter", "all"],
        temperatureCategory: "cold",
        requiresLayering: true,
      );
    }
  }

  static ClothingConstraints _applyPrecipitationOverlay(
    int weatherCode,
    ClothingConstraints base,
  ) {
    var requiredCategories = List<String>.from(base.requiredCategories);
    var preferredMaterials = List<String>.from(base.preferredMaterials);
    var avoidMaterials = List<String>.from(base.avoidMaterials);
    var preferredSeasons = List<String>.from(base.preferredSeasons);
    var preferredColors = List<String>.from(base.preferredColors);
    var advisories = List<String>.from(base.advisories);
    var requiresWaterproof = base.requiresWaterproof;
    var requiresLayering = base.requiresLayering;
    final temperatureCategory = base.temperatureCategory;

    void addToAvoid(String material) {
      if (!avoidMaterials.contains(material)) {
        avoidMaterials.add(material);
      }
    }

    void addToRequired(String category) {
      if (!requiredCategories.contains(category)) {
        requiredCategories.add(category);
      }
    }

    // Freezing precipitation: apply rain constraints + cold material prefs
    if (_freezingCodes.contains(weatherCode)) {
      requiresWaterproof = true;
      addToAvoid("suede");
      addToAvoid("silk");
      advisories.add("Bring an umbrella");
      // Also add cold-weather material preferences if not already present
      for (final m in ["wool", "cashmere", "fleece", "knit"]) {
        if (!preferredMaterials.contains(m)) {
          preferredMaterials.add(m);
        }
      }
    }

    // Rain overlay
    if (_rainCodes.contains(weatherCode)) {
      requiresWaterproof = true;
      addToAvoid("suede");
      addToAvoid("silk");
      if (!advisories.contains("Bring an umbrella")) {
        advisories.add("Bring an umbrella");
      }
    }

    // Snow overlay
    if (_snowCodes.contains(weatherCode)) {
      requiresWaterproof = true;
      addToAvoid("suede");
      addToAvoid("silk");
      addToAvoid("chiffon");
      addToRequired("outerwear");
      addToRequired("shoes");
      advisories.add("Wear warm waterproof layers");
    }

    // Thunderstorm overlay (includes all rain constraints)
    if (_thunderstormCodes.contains(weatherCode)) {
      requiresWaterproof = true;
      addToAvoid("suede");
      addToAvoid("silk");
      if (!advisories.contains("Bring an umbrella")) {
        advisories.add("Bring an umbrella");
      }
      advisories.add("Prefer dark colors");
      advisories.add("Severe weather \u2013 dress practically");
    }

    // Fog overlay
    if (_fogCodes.contains(weatherCode)) {
      advisories.add(
        "Low visibility \u2013 wear bright or reflective colors if walking/cycling",
      );
    }

    return ClothingConstraints(
      requiredCategories: requiredCategories,
      preferredMaterials: preferredMaterials,
      avoidMaterials: avoidMaterials,
      preferredSeasons: preferredSeasons,
      preferredColors: preferredColors,
      temperatureCategory: temperatureCategory,
      advisories: advisories,
      requiresWaterproof: requiresWaterproof,
      requiresLayering: requiresLayering,
    );
  }
}
