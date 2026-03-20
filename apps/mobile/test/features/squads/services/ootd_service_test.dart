import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart"
    as firebase_test;
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/squads/services/ootd_service.dart";

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "test-token";
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("OotdService", () {
    test("createPost calls correct API endpoint and returns OotdPost",
        () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "post": {
              "id": "post-1",
              "authorId": "profile-1",
              "photoUrl": "https://example.com/photo.jpg",
              "caption": "My look",
              "createdAt": "2026-03-19T00:00:00.000Z",
              "taggedItems": [],
              "squadIds": ["squad-1"],
              "reactionCount": 0,
              "commentCount": 0,
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final post = await service.createPost(
        photoUrl: "https://example.com/photo.jpg",
        caption: "My look",
        squadIds: ["squad-1"],
      );

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts");
      expect(post.id, "post-1");
      expect(post.caption, "My look");
    });

    test("listFeedPosts returns paginated posts map", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "posts": [
              {
                "id": "post-1",
                "authorId": "profile-1",
                "photoUrl": "https://example.com/photo.jpg",
                "createdAt": "2026-03-19T00:00:00.000Z",
                "taggedItems": [],
                "squadIds": ["squad-1"],
              }
            ],
            "nextCursor": "2026-03-18T00:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.listFeedPosts(limit: 10);

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/feed");
      expect((result["posts"] as List).length, 1);
      expect(result["nextCursor"], "2026-03-18T00:00:00.000Z");
    });

    test("listSquadPosts returns paginated posts for squad", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "posts": [],
            "nextCursor": null,
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.listSquadPosts("squad-1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/squad-1/posts");
      expect((result["posts"] as List).length, 0);
    });

    test("getPost returns OotdPost", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "post": {
              "id": "post-1",
              "authorId": "profile-1",
              "photoUrl": "https://example.com/photo.jpg",
              "createdAt": "2026-03-19T00:00:00.000Z",
              "taggedItems": [],
              "squadIds": ["squad-1"],
            }
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final post = await service.getPost("post-1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/post-1");
      expect(post.id, "post-1");
    });

    test("deletePost calls correct DELETE endpoint", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({}), 204);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      await service.deletePost("post-1");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/posts/post-1");
    });

    // --- Reaction and Comment tests ---

    test("toggleReaction calls correct API endpoint", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"reacted": true, "reactionCount": 1}),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.toggleReaction("post-1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/post-1/reactions");
      expect(result["reacted"], true);
    });

    test("createComment calls correct API endpoint with text body", () async {
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "comment": {
              "id": "c1",
              "postId": "post-1",
              "authorId": "profile-1",
              "text": "Nice!",
              "createdAt": "2026-03-19T00:00:00.000Z",
            }
          }),
          201,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final comment = await service.createComment("post-1", text: "Nice!");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/post-1/comments");
      expect(comment.text, "Nice!");
      expect(capturedBody, contains('"text":"Nice!"'));
    });

    test("listComments calls correct API endpoint with pagination params",
        () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "comments": [
              {
                "id": "c1",
                "postId": "post-1",
                "authorId": "profile-1",
                "text": "Hello",
                "createdAt": "2026-03-19T00:00:00.000Z",
              }
            ],
            "nextCursor": null,
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.listComments("post-1", limit: 25);

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/post-1/comments");
      expect(capturedUri?.queryParameters["limit"], "25");
      expect((result["comments"] as List).length, 1);
    });

    test("deleteComment calls correct DELETE endpoint", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({}), 204);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      await service.deleteComment("post-1", "comment-1");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/posts/post-1/comments/comment-1");
    });

    // --- hasPostedToday tests (Story 9.6) ---

    test("hasPostedToday returns true when posts exist for today", () async {
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "posts": [
              {
                "id": "post-1",
                "authorId": "profile-1",
                "photoUrl": "https://example.com/photo.jpg",
                "createdAt": "${todayStr}T10:00:00.000Z",
                "taggedItems": [],
                "squadIds": ["squad-1"],
              }
            ],
            "nextCursor": null,
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.hasPostedToday();

      expect(result, isTrue);
    });

    test("hasPostedToday returns false when no posts today", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "posts": [
              {
                "id": "post-1",
                "authorId": "profile-1",
                "photoUrl": "https://example.com/photo.jpg",
                "createdAt": "2025-01-01T10:00:00.000Z",
                "taggedItems": [],
                "squadIds": ["squad-1"],
              }
            ],
            "nextCursor": null,
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.hasPostedToday();

      expect(result, isFalse);
    });

    test("hasPostedToday returns false on error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response("Internal Error", 500);
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.hasPostedToday();

      expect(result, isFalse);
    });

    // --- Steal This Look tests (Story 9.5) ---

    test("stealThisLook calls correct API endpoint", () async {
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "sourceMatches": [
              {
                "sourceItem": {"id": "item-a", "name": "Blue Top"},
                "matches": [
                  {
                    "itemId": "w1",
                    "name": "Navy Blouse",
                    "matchScore": 85,
                    "matchReason": "Similar",
                  }
                ],
              }
            ],
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _FakeAuthService(),
        httpClient: mockClient,
      );
      final service = OotdService(apiClient: apiClient);

      final result = await service.stealThisLook("post-1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/post-1/steal-look");
      expect(result.sourceMatches.length, 1);
      expect(result.sourceMatches[0].matches[0].matchScore, 85);
    });
  });
}
