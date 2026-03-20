/// Service for managing resale prompts via the API.
///
/// Handles fetching pending prompts, triggering monthly evaluation,
/// and updating prompt actions (accept/dismiss).
///
/// Story 13.2: Monthly Resale Prompts (FR-RSL-01, FR-RSL-05, FR-RSL-06)
import "../../../core/networking/api_client.dart";
import "../models/resale_prompt.dart";

class ResalePromptService {
  ResalePromptService({required this.apiClient});

  final ApiClient apiClient;

  /// Fetch pending resale prompts for the current month.
  ///
  /// Returns an empty list on error.
  Future<List<ResalePrompt>> fetchPendingPrompts() async {
    try {
      final response = await apiClient.getResalePrompts();
      final prompts = response["prompts"] as List<dynamic>? ?? [];
      return prompts
          .map((json) =>
              ResalePrompt.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Trigger monthly resale evaluation.
  ///
  /// Returns true if candidates were found, false on error or zero candidates.
  Future<bool> triggerEvaluation() async {
    try {
      final response = await apiClient.evaluateResalePrompts();
      final candidates = response["candidates"] as int? ?? 0;
      return candidates > 0;
    } catch (_) {
      return false;
    }
  }

  /// Accept a resale prompt (user wants to list the item for sale).
  Future<void> acceptPrompt(String promptId) async {
    await apiClient.updateResalePrompt(promptId, {"action": "accepted"});
  }

  /// Dismiss a resale prompt (user wants to keep the item).
  Future<void> dismissPrompt(String promptId) async {
    await apiClient.updateResalePrompt(promptId, {"action": "dismissed"});
  }

  /// Fetch the count of pending resale prompts.
  ///
  /// Returns 0 on error.
  Future<int> fetchPendingCount() async {
    try {
      final response = await apiClient.getResalePromptsCount();
      return response["count"] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
