import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/core/notifications/posting_reminder_service.dart";

void main() {
  group("PostingReminderService", () {
    test("postingReminderNotificationId is 102", () {
      expect(PostingReminderService.postingReminderNotificationId, 102);
    });

    test("can be constructed with default plugin", () {
      final service = PostingReminderService();
      expect(service, isNotNull);
    });

    test("buildPostingBody returns correct text", () {
      final result = PostingReminderService.buildPostingBody();
      expect(result, "Post your outfit of the day to your squads.");
    });

    test("buildPostingBody returns consistent text on multiple calls", () {
      final result1 = PostingReminderService.buildPostingBody();
      final result2 = PostingReminderService.buildPostingBody();
      expect(result1, result2);
    });

    test("notification ID 102 is distinct from morning (100) and evening (101)", () {
      expect(PostingReminderService.postingReminderNotificationId, isNot(100));
      expect(PostingReminderService.postingReminderNotificationId, isNot(101));
      expect(PostingReminderService.postingReminderNotificationId, 102);
    });
  });
}
