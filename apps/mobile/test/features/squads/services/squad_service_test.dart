import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/services/squad_service.dart";

class _TestAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

ApiClient _buildMockApiClient({
  required http.Response Function(http.Request) handler,
}) {
  final mockHttp = http_testing.MockClient(
      (request) async => handler(request));
  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _TestAuthService(),
    httpClient: mockHttp,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("SquadService", () {
    test("createSquad calls correct API endpoint and returns Squad", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "POST");
        expect(request.url.path, "/v1/squads");
        final body = jsonDecode(request.body);
        expect(body["name"], "My Squad");
        return http.Response(
          jsonEncode({
            "squad": {
              "id": "squad-1",
              "name": "My Squad",
              "description": null,
              "inviteCode": "ABCD1234",
              "createdBy": "p1",
              "createdAt": "2026-03-19T00:00:00.000Z",
              "memberCount": 1,
            }
          }),
          201,
        );
      });

      final service = SquadService(apiClient: apiClient);
      final squad = await service.createSquad(name: "My Squad");

      expect(squad.id, "squad-1");
      expect(squad.name, "My Squad");
      expect(squad.inviteCode, "ABCD1234");
    });

    test("listMySquads returns list of Squads", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "GET");
        expect(request.url.path, "/v1/squads");
        return http.Response(
          jsonEncode({
            "squads": [
              {
                "id": "s1",
                "name": "Squad 1",
                "inviteCode": "CODE0001",
                "createdBy": "p1",
                "createdAt": "2026-03-19T00:00:00.000Z",
                "memberCount": 3,
              },
              {
                "id": "s2",
                "name": "Squad 2",
                "inviteCode": "CODE0002",
                "createdBy": "p2",
                "createdAt": "2026-03-19T00:00:00.000Z",
                "memberCount": 5,
              },
            ]
          }),
          200,
        );
      });

      final service = SquadService(apiClient: apiClient);
      final squads = await service.listMySquads();

      expect(squads.length, 2);
      expect(squads[0].name, "Squad 1");
      expect(squads[1].name, "Squad 2");
    });

    test("joinSquad calls correct endpoint with invite code", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "POST");
        expect(request.url.path, "/v1/squads/join");
        final body = jsonDecode(request.body);
        expect(body["inviteCode"], "ABCD1234");
        return http.Response(
          jsonEncode({
            "squad": {
              "id": "squad-1",
              "name": "Joined Squad",
              "inviteCode": "ABCD1234",
              "createdBy": "p1",
              "createdAt": "2026-03-19T00:00:00.000Z",
              "memberCount": 3,
            }
          }),
          200,
        );
      });

      final service = SquadService(apiClient: apiClient);
      final squad = await service.joinSquad(inviteCode: "ABCD1234");

      expect(squad.id, "squad-1");
      expect(squad.name, "Joined Squad");
    });

    test("leaveSquad calls correct DELETE endpoint", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "DELETE");
        expect(request.url.path, "/v1/squads/squad-1/members/me");
        return http.Response(jsonEncode({"success": true}), 204);
      });

      final service = SquadService(apiClient: apiClient);
      await service.leaveSquad("squad-1");
      // No exception means success
    });

    test("removeMember calls correct DELETE endpoint with member ID", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "DELETE");
        expect(request.url.path, "/v1/squads/squad-1/members/member-2");
        return http.Response(jsonEncode({"success": true}), 204);
      });

      final service = SquadService(apiClient: apiClient);
      await service.removeMember("squad-1", "member-2");
      // No exception means success
    });

    test("getSquad calls correct endpoint", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "GET");
        expect(request.url.path, "/v1/squads/squad-1");
        return http.Response(
          jsonEncode({
            "squad": {
              "id": "squad-1",
              "name": "My Squad",
              "inviteCode": "ABCD1234",
              "createdBy": "p1",
              "createdAt": "2026-03-19T00:00:00.000Z",
              "memberCount": 4,
            }
          }),
          200,
        );
      });

      final service = SquadService(apiClient: apiClient);
      final squad = await service.getSquad("squad-1");

      expect(squad.id, "squad-1");
      expect(squad.memberCount, 4);
    });

    test("listMembers returns list of SquadMembers", () async {
      final apiClient = _buildMockApiClient(handler: (request) {
        expect(request.method, "GET");
        expect(request.url.path, "/v1/squads/squad-1/members");
        return http.Response(
          jsonEncode({
            "members": [
              {
                "id": "m1",
                "squadId": "squad-1",
                "userId": "u1",
                "role": "admin",
                "joinedAt": "2026-03-19T00:00:00.000Z",
                "displayName": "Alice",
              },
              {
                "id": "m2",
                "squadId": "squad-1",
                "userId": "u2",
                "role": "member",
                "joinedAt": "2026-03-19T01:00:00.000Z",
                "displayName": "Bob",
              },
            ]
          }),
          200,
        );
      });

      final service = SquadService(apiClient: apiClient);
      final members = await service.listMembers("squad-1");

      expect(members.length, 2);
      expect(members[0].displayName, "Alice");
      expect(members[0].isAdmin, isTrue);
      expect(members[1].displayName, "Bob");
      expect(members[1].isAdmin, isFalse);
    });
  });
}
