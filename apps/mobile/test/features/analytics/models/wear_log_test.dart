import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/analytics/models/wear_log.dart";

void main() {
  group("WearLog", () {
    test("fromJson parses camelCase keys", () {
      final json = {
        "id": "wl-1",
        "profileId": "profile-1",
        "loggedDate": "2026-03-17",
        "outfitId": "outfit-1",
        "photoUrl": "http://example.com/photo.jpg",
        "itemIds": ["item-1", "item-2"],
        "createdAt": "2026-03-17T10:00:00Z",
      };

      final wearLog = WearLog.fromJson(json);

      expect(wearLog.id, "wl-1");
      expect(wearLog.profileId, "profile-1");
      expect(wearLog.loggedDate, "2026-03-17");
      expect(wearLog.outfitId, "outfit-1");
      expect(wearLog.photoUrl, "http://example.com/photo.jpg");
      expect(wearLog.itemIds, ["item-1", "item-2"]);
      expect(wearLog.createdAt, "2026-03-17T10:00:00Z");
    });

    test("fromJson parses snake_case keys", () {
      final json = {
        "id": "wl-2",
        "profile_id": "profile-2",
        "logged_date": "2026-03-16",
        "outfit_id": "outfit-2",
        "photo_url": "http://example.com/photo2.jpg",
        "item_ids": ["item-3"],
        "created_at": "2026-03-16T09:00:00Z",
      };

      final wearLog = WearLog.fromJson(json);

      expect(wearLog.id, "wl-2");
      expect(wearLog.profileId, "profile-2");
      expect(wearLog.loggedDate, "2026-03-16");
      expect(wearLog.outfitId, "outfit-2");
      expect(wearLog.photoUrl, "http://example.com/photo2.jpg");
      expect(wearLog.itemIds, ["item-3"]);
      expect(wearLog.createdAt, "2026-03-16T09:00:00Z");
    });

    test("fromJson handles null optional fields", () {
      final json = {
        "id": "wl-3",
        "profileId": "profile-3",
        "loggedDate": "2026-03-15",
        "itemIds": <String>[],
      };

      final wearLog = WearLog.fromJson(json);

      expect(wearLog.outfitId, isNull);
      expect(wearLog.photoUrl, isNull);
      expect(wearLog.createdAt, isNull);
      expect(wearLog.itemIds, isEmpty);
    });

    test("toJson produces correct output", () {
      const wearLog = WearLog(
        id: "wl-1",
        profileId: "profile-1",
        loggedDate: "2026-03-17",
        outfitId: "outfit-1",
        photoUrl: "http://example.com/photo.jpg",
        itemIds: ["item-1", "item-2"],
        createdAt: "2026-03-17T10:00:00Z",
      );

      final json = wearLog.toJson();

      expect(json["id"], "wl-1");
      expect(json["profileId"], "profile-1");
      expect(json["loggedDate"], "2026-03-17");
      expect(json["outfitId"], "outfit-1");
      expect(json["photoUrl"], "http://example.com/photo.jpg");
      expect(json["itemIds"], ["item-1", "item-2"]);
      expect(json["createdAt"], "2026-03-17T10:00:00Z");
    });

    test("toJson omits null optional fields", () {
      const wearLog = WearLog(
        id: "wl-1",
        profileId: "profile-1",
        loggedDate: "2026-03-17",
        itemIds: ["item-1"],
      );

      final json = wearLog.toJson();

      expect(json.containsKey("outfitId"), isFalse);
      expect(json.containsKey("photoUrl"), isFalse);
      expect(json.containsKey("createdAt"), isFalse);
    });
  });
}
