const ALLOWED_STYLE_PREFERENCES = [
  "casual",
  "streetwear",
  "minimalist",
  "classic",
  "bohemian",
  "sporty",
  "vintage",
  "glamorous"
];

const ALLOWED_UPDATE_FIELDS = new Set([
  "display_name",
  "photo_url",
  "style_preferences",
  "onboarding_completed_at",
  "push_token",
  "notification_preferences"
]);

const ALLOWED_NOTIFICATION_KEYS = new Set([
  "outfit_reminders",
  "wear_logging",
  "analytics",
  "social",
  "event_reminders",
  "resale_prompts"
]);

const SOCIAL_NOTIFICATION_MODES = ["all", "morning", "off"];

const BOOLEAN_ONLY_NOTIFICATION_KEYS = new Set([
  "outfit_reminders",
  "wear_logging",
  "analytics",
  "event_reminders",
  "resale_prompts"
]);

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ValidationError";
    this.statusCode = 400;
    this.code = "VALIDATION_ERROR";
  }
}

export function createProfileService({ repo, uploadService, firebaseAdminService } = {}) {
  if (!repo || typeof repo.getOrCreateProfile !== "function") {
    throw new TypeError("repo.getOrCreateProfile is required");
  }

  return {
    async deleteAccountForAuthenticatedUser(authContext) {
      // Step 1: Delete profile from DB (cascade deletes items)
      const { firebaseUid } = await repo.deleteProfile(authContext);

      // Step 2: Clean up storage files (best effort)
      if (uploadService && typeof uploadService.deleteUserFiles === "function") {
        try {
          const result = await uploadService.deleteUserFiles(firebaseUid);
          console.log(`[profile-service] Storage cleanup: ${JSON.stringify(result)}`);
        } catch (error) {
          console.error(`[profile-service] Storage cleanup failed:`, error.message);
        }
      }

      // Step 3: Delete Firebase Auth account (best effort)
      if (firebaseAdminService && typeof firebaseAdminService.deleteUser === "function") {
        try {
          const result = await firebaseAdminService.deleteUser(firebaseUid);
          console.log(`[profile-service] Firebase Auth cleanup: ${JSON.stringify(result)}`);
        } catch (error) {
          console.error(`[profile-service] Firebase Auth cleanup failed:`, error.message);
        }
      }

      return { deleted: true };
    },

    async getProfileForAuthenticatedUser(authContext) {
      const result = await repo.getOrCreateProfile(authContext);

      return {
        profile: result.profile,
        provisioned: result.created
      };
    },

    async updateProfileForAuthenticatedUser(authContext, updates) {
      // Reject unknown fields
      const unknownFields = Object.keys(updates).filter(
        (key) => !ALLOWED_UPDATE_FIELDS.has(key)
      );
      if (unknownFields.length > 0) {
        throw new ValidationError(
          `Unknown fields: ${unknownFields.join(", ")}`
        );
      }

      // Validate display_name
      if (updates.display_name !== undefined) {
        if (
          typeof updates.display_name !== "string" ||
          updates.display_name.length > 100
        ) {
          throw new ValidationError(
            "display_name must be a string of at most 100 characters"
          );
        }
      }

      // Validate photo_url
      if (updates.photo_url !== undefined) {
        if (
          typeof updates.photo_url !== "string" ||
          updates.photo_url.length === 0
        ) {
          throw new ValidationError("photo_url must be a non-empty string");
        }
      }

      // Validate style_preferences
      if (updates.style_preferences !== undefined) {
        if (!Array.isArray(updates.style_preferences)) {
          throw new ValidationError("style_preferences must be an array");
        }
        for (const pref of updates.style_preferences) {
          if (!ALLOWED_STYLE_PREFERENCES.includes(pref)) {
            throw new ValidationError(
              `Invalid style preference: ${pref}. Allowed values: ${ALLOWED_STYLE_PREFERENCES.join(", ")}`
            );
          }
        }
      }

      // Validate push_token
      if (updates.push_token !== undefined) {
        if (
          updates.push_token !== null &&
          typeof updates.push_token !== "string"
        ) {
          throw new ValidationError(
            "push_token must be a string or null"
          );
        }
      }

      // Validate notification_preferences
      if (updates.notification_preferences !== undefined) {
        if (
          updates.notification_preferences === null ||
          typeof updates.notification_preferences !== "object" ||
          Array.isArray(updates.notification_preferences)
        ) {
          throw new ValidationError(
            "notification_preferences must be an object"
          );
        }
        for (const key of Object.keys(updates.notification_preferences)) {
          if (!ALLOWED_NOTIFICATION_KEYS.has(key)) {
            throw new ValidationError(
              `Unknown notification preference key: ${key}`
            );
          }
          const value = updates.notification_preferences[key];
          if (key === "social") {
            // social accepts boolean (backward compat) or string mode
            if (typeof value === "boolean") {
              // Normalize boolean to string
              updates.notification_preferences[key] = value ? "all" : "off";
            } else if (typeof value === "string") {
              if (!SOCIAL_NOTIFICATION_MODES.includes(value)) {
                throw new ValidationError(
                  `notification_preferences.social must be one of: ${SOCIAL_NOTIFICATION_MODES.join(", ")}`
                );
              }
            } else {
              throw new ValidationError(
                `notification_preferences.social must be a boolean or one of: ${SOCIAL_NOTIFICATION_MODES.join(", ")}`
              );
            }
          } else {
            if (typeof value !== "boolean") {
              throw new ValidationError(
                `notification_preferences.${key} must be a boolean`
              );
            }
          }
        }
      }

      // Validate onboarding_completed_at
      if (updates.onboarding_completed_at !== undefined) {
        if (updates.onboarding_completed_at !== null) {
          const date = new Date(updates.onboarding_completed_at);
          if (isNaN(date.getTime())) {
            throw new ValidationError(
              "onboarding_completed_at must be a valid ISO timestamp or null"
            );
          }
          // Normalize to ISO string for the database
          updates.onboarding_completed_at = date.toISOString();
        }
      }

      const profile = await repo.updateProfile(authContext, updates);
      return { profile };
    }
  };
}
