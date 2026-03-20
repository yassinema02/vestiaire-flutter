import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/weather/weather_clothing_mapper.dart";

void main() {
  group("WeatherClothingMapper", () {
    group("temperature-based mapping", () {
      test("hot weather (>28C, clear sky)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 32.0);

        expect(result.temperatureCategory, "hot");
        expect(result.preferredMaterials, contains("cotton"));
        expect(result.preferredMaterials, contains("linen"));
        expect(result.avoidMaterials, contains("wool"));
        expect(result.avoidMaterials, contains("fleece"));
        expect(result.avoidMaterials, contains("leather"));
        expect(result.preferredSeasons, contains("summer"));
        expect(result.preferredSeasons, contains("all"));
        expect(result.requiresLayering, false);
        expect(result.requiresWaterproof, false);
      });

      test("cold weather (<5C, clear sky)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, -2.0);

        expect(result.temperatureCategory, "cold");
        expect(result.requiredCategories, contains("outerwear"));
        expect(result.preferredMaterials, contains("wool"));
        expect(result.preferredMaterials, contains("cashmere"));
        expect(result.preferredMaterials, contains("fleece"));
        expect(result.avoidMaterials, contains("mesh"));
        expect(result.avoidMaterials, contains("chiffon"));
        expect(result.avoidMaterials, contains("linen"));
        expect(result.preferredSeasons, contains("winter"));
        expect(result.preferredSeasons, contains("all"));
        expect(result.requiresLayering, true);
      });

      test("cool weather (10C, clear sky)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 10.0);

        expect(result.temperatureCategory, "cool");
        expect(result.requiresLayering, true);
        expect(result.preferredSeasons, contains("fall"));
        expect(result.preferredSeasons, contains("spring"));
        expect(result.preferredSeasons, contains("all"));
        expect(result.preferredMaterials, contains("wool"));
        expect(result.preferredMaterials, contains("knit"));
        expect(result.preferredMaterials, contains("fleece"));
        expect(result.preferredMaterials, contains("denim"));
        expect(result.preferredMaterials, contains("corduroy"));
      });

      test("mild weather (22C, clear sky)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 22.0);

        expect(result.temperatureCategory, "mild");
        expect(result.avoidMaterials, isEmpty);
        expect(result.preferredSeasons, contains("spring"));
        expect(result.preferredSeasons, contains("summer"));
        expect(result.preferredSeasons, contains("fall"));
        expect(result.preferredSeasons, contains("all"));
      });
    });

    group("boundary temperatures", () {
      test("exactly 28C is mild not hot", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 28.0);
        expect(result.temperatureCategory, "mild");
      });

      test("exactly 5C is cool not cold", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 5.0);
        expect(result.temperatureCategory, "cool");
      });

      test("exactly 15C is mild not cool", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 15.0);
        expect(result.temperatureCategory, "mild");
      });
    });

    group("precipitation overlays", () {
      test("rain overlay (15C, code 61)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(61, 15.0);

        expect(result.requiresWaterproof, true);
        expect(result.avoidMaterials, contains("suede"));
        expect(result.avoidMaterials, contains("silk"));
        expect(
          result.advisories,
          contains("Bring an umbrella"),
        );
        // Temperature-based constraints still apply
        expect(result.temperatureCategory, "mild");
      });

      test("snow overlay (-2C, code 71)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(71, -2.0);

        expect(result.requiresWaterproof, true);
        expect(result.requiredCategories, contains("outerwear"));
        expect(result.requiredCategories, contains("shoes"));
        expect(result.avoidMaterials, contains("suede"));
        expect(result.avoidMaterials, contains("silk"));
        expect(result.avoidMaterials, contains("chiffon"));
        expect(
          result.advisories,
          contains("Wear warm waterproof layers"),
        );
        // Cold base constraints
        expect(result.temperatureCategory, "cold");
      });

      test("thunderstorm overlay (20C, code 95)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(95, 20.0);

        expect(result.requiresWaterproof, true);
        expect(result.avoidMaterials, contains("suede"));
        expect(result.avoidMaterials, contains("silk"));
        expect(
          result.advisories,
          contains("Severe weather \u2013 dress practically"),
        );
        expect(result.advisories, contains("Prefer dark colors"));
        expect(result.advisories, contains("Bring an umbrella"));
      });

      test("fog overlay (12C, code 45)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(45, 12.0);

        expect(
          result.advisories,
          contains(
            "Low visibility \u2013 wear bright or reflective colors if walking/cycling",
          ),
        );
        // No material changes for fog
        expect(result.temperatureCategory, "cool");
        expect(result.requiresWaterproof, false);
      });

      test("freezing drizzle overlay (-1C, code 56)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(56, -1.0);

        // Rain constraints
        expect(result.requiresWaterproof, true);
        expect(result.avoidMaterials, contains("suede"));
        expect(result.avoidMaterials, contains("silk"));
        expect(result.advisories, contains("Bring an umbrella"));

        // Cold base constraints
        expect(result.temperatureCategory, "cold");
        expect(result.requiresLayering, true);

        // Cold-weather material preferences added by freezing overlay
        expect(result.preferredMaterials, contains("wool"));
        expect(result.preferredMaterials, contains("cashmere"));
        expect(result.preferredMaterials, contains("fleece"));
        expect(result.preferredMaterials, contains("knit"));
      });

      test("rain showers overlay (code 80)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(80, 18.0);

        expect(result.requiresWaterproof, true);
        expect(result.avoidMaterials, contains("suede"));
        expect(result.avoidMaterials, contains("silk"));
        expect(result.advisories, contains("Bring an umbrella"));
      });

      test("snow showers overlay (code 85)", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(85, 2.0);

        expect(result.requiresWaterproof, true);
        expect(result.requiredCategories, contains("shoes"));
        expect(
          result.advisories,
          contains("Wear warm waterproof layers"),
        );
      });
    });

    group("primaryTip", () {
      test("thunderstorm returns severe weather tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(95, 20.0);
        expect(
          result.primaryTip,
          "Severe weather expected \u2013 dress practically",
        );
      });

      test("rain returns waterproof tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(61, 18.0);
        expect(
          result.primaryTip,
          "Grab a waterproof jacket \u2013 rain expected",
        );
      });

      test("cold rain returns bundle up with waterproof tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(61, 2.0);
        expect(result.primaryTip, "Bundle up with waterproof layers");
      });

      test("cold clear returns layering tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, -5.0);
        expect(result.primaryTip, "Layer up with warm fabrics today");
      });

      test("cool clear returns light jacket tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 10.0);
        expect(
          result.primaryTip,
          "A light jacket or layers will keep you comfortable",
        );
      });

      test("hot clear returns cotton/linen tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 35.0);
        expect(
          result.primaryTip,
          "Light and breezy \u2013 perfect for cotton and linen",
        );
      });

      test("mild clear returns comfortable tip", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(0, 22.0);
        expect(
          result.primaryTip,
          "Comfortable day \u2013 dress as you like",
        );
      });
    });

    group("toJson serialization", () {
      test("contains all expected fields", () {
        final result = WeatherClothingMapper.mapWeatherToClothing(61, 10.0);
        final json = result.toJson();

        expect(json, containsPair("requiredCategories", isList));
        expect(json, containsPair("preferredMaterials", isList));
        expect(json, containsPair("avoidMaterials", isList));
        expect(json, containsPair("preferredSeasons", isList));
        expect(json, containsPair("preferredColors", isList));
        expect(json, containsPair("temperatureCategory", isA<String>()));
        expect(json, containsPair("advisories", isList));
        expect(json, containsPair("requiresWaterproof", isA<bool>()));
        expect(json, containsPair("requiresLayering", isA<bool>()));
      });

      test("round-trips through fromJson", () {
        final original = WeatherClothingMapper.mapWeatherToClothing(71, -3.0);
        final json = original.toJson();
        final restored = ClothingConstraints.fromJson(json);

        expect(restored.requiredCategories, original.requiredCategories);
        expect(restored.preferredMaterials, original.preferredMaterials);
        expect(restored.avoidMaterials, original.avoidMaterials);
        expect(restored.preferredSeasons, original.preferredSeasons);
        expect(restored.temperatureCategory, original.temperatureCategory);
        expect(restored.advisories, original.advisories);
        expect(restored.requiresWaterproof, original.requiresWaterproof);
        expect(restored.requiresLayering, original.requiresLayering);
      });
    });
  });
}
