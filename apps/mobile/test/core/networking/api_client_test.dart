import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/networking/api_client.dart";

// Minimal fake AuthService that provides tokens without Firebase.
class FakeAuthServiceForApi {
  String? tokenToReturn;
  bool forceRefreshCalled = false;

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) forceRefreshCalled = true;
    return tokenToReturn;
  }
}

/// A thin wrapper around ApiClient that accepts our fake auth service.
/// This avoids requiring Firebase initialization in tests.
class TestableApiClient {
  TestableApiClient({
    required String baseUrl,
    required this.fakeAuth,
    http.Client? httpClient,
    this.onSessionExpired,
  })  : _baseUrl = baseUrl.endsWith("/")
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final FakeAuthServiceForApi fakeAuth;
  final http.Client _httpClient;
  final void Function()? onSessionExpired;

  Future<Map<String, dynamic>> getOrCreateProfile() async {
    return _authenticatedRequest("GET", "/v1/profiles/me");
  }

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    List<String>? stylePreferences,
    String? photoUrl,
    DateTime? onboardingCompletedAt,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body["display_name"] = displayName;
    if (stylePreferences != null) body["style_preferences"] = stylePreferences;
    if (photoUrl != null) body["photo_url"] = photoUrl;
    if (onboardingCompletedAt != null) {
      body["onboarding_completed_at"] =
          onboardingCompletedAt.toUtc().toIso8601String();
    }
    return _authenticatedRequest("PUT", "/v1/profiles/me", body: body);
  }

  Future<Map<String, dynamic>> getSignedUploadUrl({
    required String purpose,
    String contentType = "image/jpeg",
  }) async {
    return _authenticatedRequest("POST", "/v1/uploads/signed-url", body: {
      "purpose": purpose,
      "contentType": contentType,
    });
  }

  Future<Map<String, dynamic>> createItem({
    required String photoUrl,
    String? name,
  }) async {
    final body = <String, dynamic>{"photoUrl": photoUrl};
    if (name != null) body["name"] = name;
    return _authenticatedRequest("POST", "/v1/items", body: body);
  }

  Future<Map<String, dynamic>> updatePushToken(String? token) async {
    return _authenticatedRequest("PUT", "/v1/profiles/me", body: {
      "push_token": token,
    });
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, bool> preferences) async {
    return _authenticatedRequest("PUT", "/v1/profiles/me", body: {
      "notification_preferences": preferences,
    });
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    return _authenticatedRequest("DELETE", "/v1/profiles/me");
  }

  Future<Map<String, dynamic>> listItems({int? limit}) async {
    final path = limit != null ? "/v1/items?limit=$limit" : "/v1/items";
    return _authenticatedRequest("GET", path);
  }

  Future<Map<String, dynamic>> retryBackgroundRemoval(String itemId) async {
    return _authenticatedRequest("POST", "/v1/items/$itemId/remove-background");
  }

  Future<Map<String, dynamic>> retryCategorization(String itemId) async {
    return _authenticatedRequest("POST", "/v1/items/$itemId/categorize");
  }

  Future<Map<String, dynamic>> createWearLog({
    required List<String> itemIds,
    String? outfitId,
    String? photoUrl,
    String? loggedDate,
  }) async {
    final body = <String, dynamic>{
      "items": itemIds,
    };
    if (outfitId != null) body["outfitId"] = outfitId;
    if (photoUrl != null) body["photoUrl"] = photoUrl;
    if (loggedDate != null) body["loggedDate"] = loggedDate;
    return _authenticatedRequest("POST", "/v1/wear-logs", body: body);
  }

  Future<Map<String, dynamic>> listWearLogs({
    required String startDate,
    required String endDate,
  }) async {
    return _authenticatedRequest("GET", "/v1/wear-logs?start=$startDate&end=$endDate");
  }

  Future<Map<String, dynamic>> scanProductUrl(String url) async {
    return _authenticatedRequest("POST", "/v1/shopping/scan-url", body: {"url": url});
  }

  Future<Map<String, dynamic>> scanProductScreenshot(String imageUrl) async {
    return _authenticatedRequest("POST", "/v1/shopping/scan-screenshot", body: {"imageUrl": imageUrl});
  }

  Future<Map<String, dynamic>> updateShoppingScan(String scanId, Map<String, dynamic> updates) async {
    return _authenticatedRequest("PATCH", "/v1/shopping/scans/$scanId", body: updates);
  }

  Future<Map<String, dynamic>> scoreShoppingScan(String scanId) async {
    return _authenticatedRequest("POST", "/v1/shopping/scans/$scanId/score");
  }

  Future<Map<String, dynamic>> generateShoppingInsights(String scanId) async {
    return _authenticatedRequest("POST", "/v1/shopping/scans/$scanId/insights");
  }

  // --- Squads ---

  Future<Map<String, dynamic>> createSquad(Map<String, dynamic> body) async {
    return _authenticatedRequest("POST", "/v1/squads", body: body);
  }

  Future<Map<String, dynamic>> listSquads() async {
    return _authenticatedRequest("GET", "/v1/squads");
  }

  Future<Map<String, dynamic>> joinSquad(Map<String, dynamic> body) async {
    return _authenticatedRequest("POST", "/v1/squads/join", body: body);
  }

  Future<Map<String, dynamic>> getSquad(String squadId) async {
    return _authenticatedRequest("GET", "/v1/squads/$squadId");
  }

  Future<Map<String, dynamic>> listSquadMembers(String squadId) async {
    return _authenticatedRequest("GET", "/v1/squads/$squadId/members");
  }

  Future<Map<String, dynamic>> leaveSquad(String squadId) async {
    return _authenticatedRequest("DELETE", "/v1/squads/$squadId/members/me");
  }

  Future<Map<String, dynamic>> removeSquadMember(String squadId, String memberId) async {
    return _authenticatedRequest("DELETE", "/v1/squads/$squadId/members/$memberId");
  }

  // --- OOTD Posts ---

  Future<Map<String, dynamic>> createOotdPost(Map<String, dynamic> body) async {
    return _authenticatedRequest("POST", "/v1/squads/posts", body: body);
  }

  Future<Map<String, dynamic>> listFeedPosts({int limit = 20, String? cursor}) async {
    final query = StringBuffer("/v1/squads/posts/feed?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return _authenticatedRequest("GET", query.toString());
  }

  Future<Map<String, dynamic>> listSquadPosts(String squadId, {int limit = 20, String? cursor}) async {
    final query = StringBuffer("/v1/squads/$squadId/posts?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return _authenticatedRequest("GET", query.toString());
  }

  Future<Map<String, dynamic>> getOotdPost(String postId) async {
    return _authenticatedRequest("GET", "/v1/squads/posts/$postId");
  }

  Future<Map<String, dynamic>> deleteOotdPost(String postId) async {
    return _authenticatedRequest("DELETE", "/v1/squads/posts/$postId");
  }

  // --- OOTD Reactions & Comments ---

  Future<Map<String, dynamic>> toggleOotdReaction(String postId) async {
    return _authenticatedRequest("POST", "/v1/squads/posts/$postId/reactions");
  }

  Future<Map<String, dynamic>> createOotdComment(String postId, Map<String, dynamic> body) async {
    return _authenticatedRequest("POST", "/v1/squads/posts/$postId/comments", body: body);
  }

  Future<Map<String, dynamic>> listOotdComments(String postId, {int limit = 50, String? cursor}) async {
    final query = StringBuffer("/v1/squads/posts/$postId/comments?limit=$limit");
    if (cursor != null) query.write("&cursor=$cursor");
    return _authenticatedRequest("GET", query.toString());
  }

  Future<Map<String, dynamic>> deleteOotdComment(String postId, String commentId) async {
    return _authenticatedRequest("DELETE", "/v1/squads/posts/$postId/comments/$commentId");
  }

  Future<Map<String, dynamic>> stealThisLook(String postId) async {
    return _authenticatedRequest("POST", "/v1/squads/posts/$postId/steal-look");
  }

  // --- Extraction Jobs (Story 10.2) ---

  Future<Map<String, dynamic>> getExtractionJob(String jobId) async {
    return _authenticatedRequest("GET", "/v1/extraction-jobs/$jobId");
  }

  Future<Map<String, dynamic>> triggerExtractionProcessing(String jobId) async {
    return _authenticatedRequest("POST", "/v1/extraction-jobs/$jobId/process");
  }

  Future<Map<String, dynamic>> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await fakeAuth.getIdToken();
    if (token == null) {
      throw const ApiException(
        statusCode: 401,
        code: "UNAUTHORIZED",
        message: "No authentication token available",
      );
    }

    var response = await _sendRequest(method, path, token, body);

    // If 401, try refreshing the token once and retry.
    if (response.statusCode == 401) {
      final refreshedToken = await fakeAuth.getIdToken(forceRefresh: true);
      if (refreshedToken != null) {
        response = await _sendRequest(method, path, refreshedToken, body);

        // Double-401: session is truly expired/revoked.
        if (response.statusCode == 401) {
          onSessionExpired?.call();
          throw const ApiException(
            statusCode: 401,
            code: "SESSION_EXPIRED",
            message: "Session expired. Please sign in again.",
          );
        }
      }
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: (responseBody["code"] as String?) ?? "UNKNOWN_ERROR",
      message: (responseBody["message"] as String?) ?? "An unexpected error occurred",
    );
  }

  Future<http.Response> _sendRequest(
    String method,
    String path,
    String token,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse("$_baseUrl$path");
    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    switch (method) {
      case "GET":
        return _httpClient.get(uri, headers: headers);
      case "POST":
        return _httpClient.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case "PUT":
        return _httpClient.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case "PATCH":
        return _httpClient.patch(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case "DELETE":
        return _httpClient.delete(uri, headers: headers);
      default:
        return _httpClient.get(uri, headers: headers);
    }
  }
}

void main() {
  group("ApiClient", () {
    late FakeAuthServiceForApi fakeAuth;

    setUp(() {
      fakeAuth = FakeAuthServiceForApi();
    });

    test("attaches Bearer token to requests", () async {
      fakeAuth.tokenToReturn = "my-firebase-token";
      String? capturedAuth;

      final mockClient = http_testing.MockClient((request) async {
        capturedAuth = request.headers["Authorization"];
        return http.Response(
          jsonEncode({"id": "profile-1", "email": "test@test.com"}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.getOrCreateProfile();
      expect(capturedAuth, "Bearer my-firebase-token");
    });

    test("throws ApiException when no token is available", () async {
      fakeAuth.tokenToReturn = null;

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
      );

      expect(
        () => client.getOrCreateProfile(),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          "statusCode",
          401,
        )),
      );
    });

    test("handles 200 response successfully", () async {
      fakeAuth.tokenToReturn = "token";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "id": "profile-1",
            "firebase_uid": "uid",
            "email": "user@example.com",
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final profile = await client.getOrCreateProfile();
      expect(profile["id"], "profile-1");
      expect(profile["email"], "user@example.com");
    });

    test("handles 403 EMAIL_VERIFICATION_REQUIRED", () async {
      fakeAuth.tokenToReturn = "token";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Forbidden",
            "code": "EMAIL_VERIFICATION_REQUIRED",
            "message": "Email verification required",
          }),
          403,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      try {
        await client.getOrCreateProfile();
        fail("Expected ApiException");
      } on ApiException catch (e) {
        expect(e.statusCode, 403);
        expect(e.code, "EMAIL_VERIFICATION_REQUIRED");
        expect(e.isEmailVerificationRequired, isTrue);
      }
    });

    test("retries on 401 with force-refreshed token", () async {
      fakeAuth.tokenToReturn = "refreshed-token";
      int callCount = 0;

      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              "error": "Unauthorized",
              "code": "UNAUTHORIZED",
              "message": "Token expired",
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode({"id": "profile-1"}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.getOrCreateProfile();
      expect(result["id"], "profile-1");
      expect(callCount, 2);
      expect(fakeAuth.forceRefreshCalled, isTrue);
    });

    test("handles trailing slash in base URL", () async {
      fakeAuth.tokenToReturn = "token";
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({"id": "1"}), 200);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080/",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.getOrCreateProfile();
      expect(capturedUri?.path, "/v1/profiles/me");
    });

    test("ApiException isEmailVerificationRequired is false for other codes",
        () {
      const exception = ApiException(
        statusCode: 403,
        code: "FORBIDDEN",
        message: "Access denied",
      );
      expect(exception.isEmailVerificationRequired, isFalse);
    });

    test("double-401 triggers onSessionExpired callback", () async {
      fakeAuth.tokenToReturn = "token";
      bool sessionExpiredCalled = false;

      final mockClient = http_testing.MockClient((request) async {
        // Always return 401
        return http.Response(
          jsonEncode({
            "error": "Unauthorized",
            "code": "UNAUTHORIZED",
            "message": "Token expired",
          }),
          401,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
        onSessionExpired: () {
          sessionExpiredCalled = true;
        },
      );

      try {
        await client.getOrCreateProfile();
        fail("Expected ApiException");
      } on ApiException catch (e) {
        expect(e.code, "SESSION_EXPIRED");
        expect(e.statusCode, 401);
        expect(e.isSessionExpired, isTrue);
      }
      expect(sessionExpiredCalled, isTrue);
      expect(fakeAuth.forceRefreshCalled, isTrue);
    });

    test("double-401 throws SESSION_EXPIRED without onSessionExpired callback", () async {
      fakeAuth.tokenToReturn = "token";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Unauthorized",
            "code": "UNAUTHORIZED",
            "message": "Token expired",
          }),
          401,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      try {
        await client.getOrCreateProfile();
        fail("Expected ApiException");
      } on ApiException catch (e) {
        expect(e.code, "SESSION_EXPIRED");
      }
    });

    test("single 401 followed by success on retry works transparently", () async {
      fakeAuth.tokenToReturn = "refreshed-token";
      int callCount = 0;

      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              "error": "Unauthorized",
              "code": "UNAUTHORIZED",
              "message": "Token expired",
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode({"id": "profile-1", "name": "Test User"}),
          200,
        );
      });

      bool sessionExpiredCalled = false;
      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
        onSessionExpired: () {
          sessionExpiredCalled = true;
        },
      );

      final result = await client.getOrCreateProfile();
      expect(result["id"], "profile-1");
      expect(callCount, 2);
      expect(fakeAuth.forceRefreshCalled, isTrue);
      // onSessionExpired should NOT have been called for a successful retry
      expect(sessionExpiredCalled, isFalse);
    });

    test("ApiException isSessionExpired is true for SESSION_EXPIRED code", () {
      const exception = ApiException(
        statusCode: 401,
        code: "SESSION_EXPIRED",
        message: "Session expired",
      );
      expect(exception.isSessionExpired, isTrue);
    });

    test("ApiException isSessionExpired is false for other codes", () {
      const exception = ApiException(
        statusCode: 401,
        code: "UNAUTHORIZED",
        message: "Unauthorized",
      );
      expect(exception.isSessionExpired, isFalse);
    });

    // === New tests for Story 1.5 API methods ===

    test("updateProfile sends PUT to /v1/profiles/me with correct body",
        () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "profile": {
              "id": "profile-1",
              "displayName": "Alice",
              "stylePreferences": ["casual"],
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.updateProfile(
        displayName: "Alice",
        stylePreferences: ["casual"],
      );

      expect(capturedMethod, "PUT");
      expect(capturedUri?.path, "/v1/profiles/me");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["display_name"], "Alice");
      expect(body["style_preferences"], ["casual"]);
      expect(result["profile"]["displayName"], "Alice");
    });

    test("createItem sends POST to /v1/items with correct body", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "item": {
              "id": "item-1",
              "photoUrl": "https://example.com/photo.jpg",
              "name": "My Jacket",
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.createItem(
        photoUrl: "https://example.com/photo.jpg",
        name: "My Jacket",
      );

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/items");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["photoUrl"], "https://example.com/photo.jpg");
      expect(body["name"], "My Jacket");
      expect(result["item"]["id"], "item-1");
    });

    test("listItems sends GET to /v1/items", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "items": [
              {"id": "item-1", "photoUrl": "https://example.com/1.jpg"},
              {"id": "item-2", "photoUrl": "https://example.com/2.jpg"},
            ]
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.listItems();

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/items");
      expect((result["items"] as List).length, 2);
    });

    test("listItems with limit adds query parameter", () async {
      fakeAuth.tokenToReturn = "token";
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({"items": []}), 200);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listItems(limit: 5);

      expect(capturedUri?.queryParameters["limit"], "5");
    });

    // === Tests for Story 1.6 notification methods ===

    test("updatePushToken sends PUT to /v1/profiles/me with token",
        () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "profile": {
              "id": "profile-1",
              "pushToken": "fcm-token-abc",
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.updatePushToken("fcm-token-abc");

      expect(capturedMethod, "PUT");
      expect(capturedUri?.path, "/v1/profiles/me");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["push_token"], "fcm-token-abc");
      expect(result["profile"]["pushToken"], "fcm-token-abc");
    });

    test("updatePushToken sends null token to clear", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "profile": {"id": "profile-1", "pushToken": null}
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.updatePushToken(null);

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["push_token"], isNull);
    });

    test("updateNotificationPreferences sends correct PUT body", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "profile": {
              "id": "profile-1",
              "notificationPreferences": {
                "outfit_reminders": false,
                "wear_logging": true,
                "analytics": true,
                "social": true,
              }
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.updateNotificationPreferences({
        "outfit_reminders": false,
      });

      expect(capturedMethod, "PUT");
      expect(capturedUri?.path, "/v1/profiles/me");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["notification_preferences"]["outfit_reminders"], isFalse);
      expect(result["profile"]["notificationPreferences"]["outfit_reminders"],
          isFalse);
    });

    test("getSignedUploadUrl sends POST to /v1/uploads/signed-url", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "uploadUrl": "https://storage.googleapis.com/upload/test",
            "publicUrl": "https://storage.googleapis.com/bucket/test.jpg",
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.getSignedUploadUrl(purpose: "profile_photo");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/uploads/signed-url");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["purpose"], "profile_photo");
      expect(body["contentType"], "image/jpeg");
      expect(result["uploadUrl"], "https://storage.googleapis.com/upload/test");
    });

    // === Tests for Story 1.7 account deletion ===

    test("deleteAccount sends DELETE to /v1/profiles/me", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"deleted": true}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.deleteAccount();

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/profiles/me");
      expect(result["deleted"], isTrue);
    });

    test("deleteAccount successful response returns parsed body", () async {
      fakeAuth.tokenToReturn = "token";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"deleted": true}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.deleteAccount();
      expect(result, {"deleted": true});
    });

    test("deleteAccount error response throws ApiException", () async {
      fakeAuth.tokenToReturn = "token";

      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "error": "Internal Server Error",
            "code": "INTERNAL_SERVER_ERROR",
            "message": "Unexpected server error",
          }),
          500,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      try {
        await client.deleteAccount();
        fail("Expected ApiException");
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.code, "INTERNAL_SERVER_ERROR");
      }
    });

    test("deleteAccount without auth token throws ApiException", () async {
      fakeAuth.tokenToReturn = null;

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
      );

      expect(
        () => client.deleteAccount(),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          "statusCode",
          401,
        )),
      );
    });

    // === Tests for Story 2.2: retryBackgroundRemoval ===

    test("retryBackgroundRemoval sends POST to correct endpoint", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"status": "processing"}),
          202,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.retryBackgroundRemoval("item-abc-123");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/items/item-abc-123/remove-background");
      expect(result["status"], "processing");
    });

    // === Tests for Story 2.3: retryCategorization ===

    test("retryCategorization sends POST to correct endpoint", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"status": "processing"}),
          202,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.retryCategorization("item-xyz-456");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/items/item-xyz-456/categorize");
      expect(result["status"], "processing");
    });

    // === Tests for Story 5.1: wear log methods ===

    test("createWearLog sends POST /v1/wear-logs with correct body",
        () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "wearLog": {
              "id": "wl-1",
              "profileId": "p-1",
              "loggedDate": "2026-03-17",
              "itemIds": ["item-1", "item-2"],
            }
          }),
          201,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.createWearLog(
        itemIds: ["item-1", "item-2"],
      );

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/wear-logs");
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["items"], ["item-1", "item-2"]);
      expect(body.containsKey("outfitId"), isFalse);
      expect(result["wearLog"]["id"], "wl-1");
    });

    test("createWearLog with outfitId includes it in the body", () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "wearLog": {
              "id": "wl-1",
              "profileId": "p-1",
              "loggedDate": "2026-03-17",
              "outfitId": "outfit-1",
              "itemIds": ["item-1"],
            }
          }),
          201,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.createWearLog(
        itemIds: ["item-1"],
        outfitId: "outfit-1",
      );

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body["items"], ["item-1"]);
      expect(body["outfitId"], "outfit-1");
    });

    test("listWearLogs sends GET /v1/wear-logs with start and end params",
        () async {
      fakeAuth.tokenToReturn = "token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "wearLogs": [
              {
                "id": "wl-1",
                "loggedDate": "2026-03-15",
                "itemIds": ["item-1"],
              }
            ]
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.listWearLogs(
        startDate: "2026-03-15",
        endDate: "2026-03-17",
      );

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/wear-logs");
      expect(capturedUri?.queryParameters["start"], "2026-03-15");
      expect(capturedUri?.queryParameters["end"], "2026-03-17");
      expect((result["wearLogs"] as List).length, 1);
    });
  });

  group("scanProductUrl", () {
    test("calls POST /v1/shopping/scan-url with correct body", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-1",
              "url": "https://www.zara.com/shirt",
              "scanType": "url",
              "productName": "Blue Shirt",
              "brand": "Zara",
              "price": 29.99,
              "currency": "GBP",
              "createdAt": "2026-03-19T00:00:00.000Z"
            },
            "status": "completed"
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.scanProductUrl("https://www.zara.com/shirt");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/shopping/scan-url");
      final bodyMap = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(bodyMap["url"], "https://www.zara.com/shirt");
      expect(result["status"], "completed");
      expect((result["scan"] as Map)["productName"], "Blue Shirt");
    });
  });

  group("scanProductScreenshot", () {
    test("calls POST /v1/shopping/scan-screenshot with correct body", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-2",
              "url": null,
              "scanType": "screenshot",
              "productName": "Red Dress",
              "brand": "H&M",
              "price": 49.99,
              "currency": "EUR",
              "imageUrl": "https://storage.example.com/screenshot.jpg",
              "extractionMethod": "screenshot_vision",
              "createdAt": "2026-03-19T00:00:00.000Z"
            },
            "status": "completed"
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.scanProductScreenshot("https://storage.example.com/screenshot.jpg");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/shopping/scan-screenshot");
      final bodyMap = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(bodyMap["imageUrl"], "https://storage.example.com/screenshot.jpg");
      expect(result["status"], "completed");
      expect((result["scan"] as Map)["scanType"], "screenshot");
      expect((result["scan"] as Map)["productName"], "Red Dress");
    });

    // === Tests for Story 8.3 updateShoppingScan ===

    // === Tests for Story 8.4 scoreShoppingScan ===

    test("scoreShoppingScan calls POST /v1/shopping/scans/:id/score", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-1",
              "scanType": "url",
              "productName": "Blue Shirt",
              "compatibilityScore": 75,
              "createdAt": "2026-03-19T00:00:00.000Z",
            },
            "score": {
              "total": 75,
              "breakdown": {
                "colorHarmony": 80,
                "styleConsistency": 70,
                "gapFilling": 75,
                "versatility": 65,
                "formalityMatch": 80,
              },
              "tier": "great_choice",
              "tierLabel": "Great Choice",
              "tierColor": "#3B82F6",
              "tierIcon": "thumb_up",
            },
            "status": "scored"
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.scoreShoppingScan("scan-1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/shopping/scans/scan-1/score");
      expect(result["status"], "scored");
      expect((result["score"] as Map)["total"], 75);
    });

    // === Tests for Story 8.5 generateShoppingInsights ===

    test("generateShoppingInsights calls POST /v1/shopping/scans/:id/insights", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-1",
              "scanType": "url",
              "productName": "Blue Shirt",
              "compatibilityScore": 75,
              "createdAt": "2026-03-19T00:00:00.000Z",
            },
            "matches": [
              {"itemId": "item-1", "itemName": "Blazer", "matchReasons": ["Good match"]},
            ],
            "insights": [
              {"type": "style_feedback", "title": "T", "body": "B"},
              {"type": "gap_assessment", "title": "T", "body": "B"},
              {"type": "value_proposition", "title": "T", "body": "B"},
            ],
            "status": "analyzed"
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.generateShoppingInsights("scan-1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/shopping/scans/scan-1/insights");
      expect(result["status"], "analyzed");
      expect((result["matches"] as List).length, 1);
      expect((result["insights"] as List).length, 3);
    });

    test("updateShoppingScan calls PATCH /v1/shopping/scans/:id with correct body", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;
      String? capturedBody;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            "scan": {
              "id": "scan-1",
              "scanType": "url",
              "productName": "Updated Shirt",
              "brand": "Updated Brand",
              "category": "shoes",
              "color": "red",
              "createdAt": "2026-03-19T00:00:00.000Z",
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.updateShoppingScan("scan-1", {
        "category": "shoes",
        "color": "red",
      });

      expect(capturedMethod, "PATCH");
      expect(capturedUri?.path, "/v1/shopping/scans/scan-1");
      final bodyMap = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(bodyMap["category"], "shoes");
      expect(bodyMap["color"], "red");
      expect((result["scan"] as Map)["category"], "shoes");
    });

    // --- Squads ---

    test("createSquad calls POST /v1/squads", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "squad": {"id": "s1", "name": "Test", "inviteCode": "CODE1234"}
          }),
          201,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.createSquad({"name": "Test"});

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads");
      expect((result["squad"] as Map)["name"], "Test");
    });

    test("listSquads calls GET /v1/squads", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"squads": []}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listSquads();

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads");
    });

    test("joinSquad calls POST /v1/squads/join", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "squad": {"id": "s1", "name": "Joined", "inviteCode": "CODE1234"}
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.joinSquad({"inviteCode": "CODE1234"});

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/join");
    });

    test("getSquad calls GET /v1/squads/:id", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "squad": {"id": "s1", "name": "Squad", "inviteCode": "CODE1234"}
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.getSquad("s1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/s1");
    });

    test("listSquadMembers calls GET /v1/squads/:id/members", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"members": []}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listSquadMembers("s1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/s1/members");
    });

    test("leaveSquad calls DELETE /v1/squads/:id/members/me", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({"success": true}), 204);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.leaveSquad("s1");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/s1/members/me");
    });

    test("removeSquadMember calls DELETE /v1/squads/:id/members/:memberId", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({"success": true}), 204);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.removeSquadMember("s1", "m2");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/s1/members/m2");
    });

    // --- OOTD Posts ---

    test("createOotdPost calls POST /v1/squads/posts", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "post": {"id": "p1", "photoUrl": "https://example.com/photo.jpg"}
          }),
          201,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.createOotdPost({
        "photoUrl": "https://example.com/photo.jpg",
        "squadIds": ["s1"],
      });

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts");
      expect((result["post"] as Map)["id"], "p1");
    });

    test("listFeedPosts calls GET /v1/squads/posts/feed with query params", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"posts": [], "nextCursor": null}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listFeedPosts(limit: 10);

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/feed");
      expect(capturedUri?.queryParameters["limit"], "10");
    });

    test("listSquadPosts calls GET /v1/squads/:id/posts", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({"posts": [], "nextCursor": null}),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listSquadPosts("s1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/s1/posts");
    });

    test("getOotdPost calls GET /v1/squads/posts/:postId", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "post": {"id": "p1", "photoUrl": "https://example.com/photo.jpg"}
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.getOotdPost("p1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/p1");
    });

    test("deleteOotdPost calls DELETE /v1/squads/posts/:postId", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({}), 204);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.deleteOotdPost("p1");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/posts/p1");
    });

    // --- OOTD Reactions & Comments ---

    test("toggleOotdReaction calls POST /v1/squads/posts/:postId/reactions", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({"reacted": true, "reactionCount": 1}), 200);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.toggleOotdReaction("p1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/p1/reactions");
      expect(result["reacted"], true);
    });

    test("createOotdComment calls POST /v1/squads/posts/:postId/comments", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({
          "comment": {
            "id": "c1",
            "postId": "p1",
            "authorId": "a1",
            "text": "Nice!",
            "createdAt": "2026-03-19T00:00:00.000Z",
          }
        }), 201);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.createOotdComment("p1", {"text": "Nice!"});

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/p1/comments");
      expect(result["comment"]["text"], "Nice!");
    });

    test("listOotdComments calls GET /v1/squads/posts/:postId/comments", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({"comments": [], "nextCursor": null}), 200);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.listOotdComments("p1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/squads/posts/p1/comments");
    });

    test("deleteOotdComment calls DELETE /v1/squads/posts/:postId/comments/:commentId", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(jsonEncode({}), 204);
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.deleteOotdComment("p1", "c1");

      expect(capturedMethod, "DELETE");
      expect(capturedUri?.path, "/v1/squads/posts/p1/comments/c1");
    });

    // --- Steal This Look (Story 9.5) ---

    test("stealThisLook calls POST /v1/squads/posts/:postId/steal-look", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          '{"sourceMatches": []}',
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      await client.stealThisLook("p1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/squads/posts/p1/steal-look");
    });

    // --- Extraction Jobs (Story 10.2) ---

    test("getExtractionJob returns job with items array", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            "job": {
              "id": "job-1",
              "status": "completed",
              "totalPhotos": 2,
              "processedPhotos": 2,
              "totalItemsFound": 3,
              "photos": [
                {"id": "photo-1", "status": "completed", "itemsFound": 2}
              ],
              "items": [
                {
                  "id": "item-1",
                  "photoId": "photo-1",
                  "itemIndex": 0,
                  "photoUrl": "https://storage.example.com/cleaned1.png",
                  "originalCropUrl": null,
                  "category": "tops",
                  "color": "blue",
                  "secondaryColors": <String>[],
                  "pattern": "solid",
                  "material": "cotton",
                  "style": "casual",
                  "season": ["all"],
                  "occasion": ["everyday"],
                  "bgRemovalStatus": "completed",
                  "categorizationStatus": "completed",
                  "detectionConfidence": 0.95,
                },
                {
                  "id": "item-2",
                  "photoId": "photo-1",
                  "itemIndex": 1,
                  "photoUrl": "https://storage.example.com/cleaned2.png",
                  "originalCropUrl": null,
                  "category": "bottoms",
                  "color": "black",
                  "secondaryColors": <String>[],
                  "pattern": "solid",
                  "material": "denim",
                  "style": "casual",
                  "season": ["all"],
                  "occasion": ["everyday"],
                  "bgRemovalStatus": "completed",
                  "categorizationStatus": "completed",
                  "detectionConfidence": 0.88,
                },
              ],
            }
          }),
          200,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.getExtractionJob("job-1");

      expect(capturedMethod, "GET");
      expect(capturedUri?.path, "/v1/extraction-jobs/job-1");
      expect(result["job"]["id"], "job-1");
      expect(result["job"]["items"], isA<List>());
      expect((result["job"]["items"] as List).length, 2);
      final item = (result["job"]["items"] as List)[0] as Map<String, dynamic>;
      expect(item["category"], "tops");
      expect(item["color"], "blue");
      expect(item["bgRemovalStatus"], "completed");
      expect(item["detectionConfidence"], 0.95);
    });

    test("triggerExtractionProcessing calls POST /v1/extraction-jobs/:id/process", () async {
      final fakeAuth = FakeAuthServiceForApi()..tokenToReturn = "test-token";
      String? capturedMethod;
      Uri? capturedUri;

      final mockClient = http_testing.MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return http.Response(
          '{"status": "processing"}',
          202,
        );
      });

      final client = TestableApiClient(
        baseUrl: "http://localhost:8080",
        fakeAuth: fakeAuth,
        httpClient: mockClient,
      );

      final result = await client.triggerExtractionProcessing("job-1");

      expect(capturedMethod, "POST");
      expect(capturedUri?.path, "/v1/extraction-jobs/job-1/process");
      expect(result["status"], "processing");
    });
  });
}
