import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/squads/models/squad.dart";

void main() {
  group("Squad.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "id": "squad-1",
        "name": "Test Squad",
        "description": "A test squad",
        "inviteCode": "ABCD1234",
        "createdBy": "profile-1",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "memberCount": 5,
        "lastActivity": "2026-03-19T12:00:00.000Z",
      };

      final squad = Squad.fromJson(json);

      expect(squad.id, "squad-1");
      expect(squad.name, "Test Squad");
      expect(squad.description, "A test squad");
      expect(squad.inviteCode, "ABCD1234");
      expect(squad.createdBy, "profile-1");
      expect(squad.createdAt, DateTime.utc(2026, 3, 19));
      expect(squad.memberCount, 5);
      expect(squad.lastActivity, DateTime.utc(2026, 3, 19, 12));
    });

    test("handles null description and lastActivity", () {
      final json = {
        "id": "squad-2",
        "name": "No Desc Squad",
        "description": null,
        "inviteCode": "XYZ12345",
        "createdBy": "profile-2",
        "createdAt": "2026-03-19T00:00:00.000Z",
        "memberCount": 1,
        "lastActivity": null,
      };

      final squad = Squad.fromJson(json);

      expect(squad.description, isNull);
      expect(squad.lastActivity, isNull);
    });

    test("defaults memberCount to 0 when missing", () {
      final json = {
        "id": "squad-3",
        "name": "Squad",
        "inviteCode": "CODE1234",
        "createdBy": "profile-1",
        "createdAt": "2026-03-19T00:00:00.000Z",
      };

      final squad = Squad.fromJson(json);

      expect(squad.memberCount, 0);
    });
  });

  group("SquadMember.fromJson", () {
    test("parses all fields correctly", () {
      final json = {
        "id": "member-1",
        "squadId": "squad-1",
        "userId": "profile-1",
        "role": "admin",
        "joinedAt": "2026-03-19T00:00:00.000Z",
        "displayName": "Alice",
        "photoUrl": "https://example.com/photo.jpg",
      };

      final member = SquadMember.fromJson(json);

      expect(member.id, "member-1");
      expect(member.squadId, "squad-1");
      expect(member.userId, "profile-1");
      expect(member.role, "admin");
      expect(member.joinedAt, DateTime.utc(2026, 3, 19));
      expect(member.displayName, "Alice");
      expect(member.photoUrl, "https://example.com/photo.jpg");
    });

    test("isAdmin returns true for admin role", () {
      final member = SquadMember.fromJson({
        "id": "m1",
        "squadId": "s1",
        "userId": "u1",
        "role": "admin",
        "joinedAt": "2026-03-19T00:00:00.000Z",
      });

      expect(member.isAdmin, isTrue);
    });

    test("isAdmin returns false for member role", () {
      final member = SquadMember.fromJson({
        "id": "m2",
        "squadId": "s1",
        "userId": "u2",
        "role": "member",
        "joinedAt": "2026-03-19T00:00:00.000Z",
      });

      expect(member.isAdmin, isFalse);
    });

    test("handles null displayName and photoUrl", () {
      final member = SquadMember.fromJson({
        "id": "m3",
        "squadId": "s1",
        "userId": "u3",
        "role": "member",
        "joinedAt": "2026-03-19T00:00:00.000Z",
        "displayName": null,
        "photoUrl": null,
      });

      expect(member.displayName, isNull);
      expect(member.photoUrl, isNull);
    });
  });
}
