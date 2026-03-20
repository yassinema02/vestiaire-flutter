/**
 * Centralized notification service with FCM delivery.
 *
 * Handles push notification delivery via Firebase Cloud Messaging,
 * social notification preference checking, quiet hours enforcement,
 * and batch squad member notifications.
 *
 * Story 9.6: Social Notification Preferences (FR-NTF-01, FR-NTF-03)
 */

/**
 * Check if the current hour falls within quiet hours (22:00-07:00).
 * During quiet hours, notifications are silently dropped (not queued).
 *
 * @param {Date} [now] - Optional Date for testing. Defaults to new Date().
 * @returns {boolean} True if within quiet hours.
 */
export function isQuietHours(now) {
  const hour = (now || new Date()).getHours();
  return hour >= 22 || hour < 7;
}

/**
 * Factory to create a notification service.
 *
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 * @returns {object} Notification service instance.
 */
export function createNotificationService({ pool }) {
  /**
   * Lazily import and initialize firebase-admin for FCM messaging.
   * Returns the admin.messaging() instance, or null if unavailable.
   */
  async function getMessaging() {
    try {
      if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        return null;
      }
      const { default: admin } = await import("firebase-admin");
      if (admin.apps.length === 0) {
        admin.initializeApp();
      }
      return admin.messaging();
    } catch (err) {
      console.warn("[notification-service] FCM not available:", err.message);
      return null;
    }
  }

  return {
    /**
     * Send a push notification to a specific profile.
     *
     * Looks up push_token and notification_preferences, checks quiet hours,
     * and sends via FCM. Fire-and-forget: logs errors but does not throw.
     *
     * @param {string} profileId - Target profile UUID.
     * @param {object} notification - Notification payload.
     * @param {string} notification.title - Notification title.
     * @param {string} notification.body - Notification body.
     * @param {object} [notification.data] - Optional data payload for deep links.
     * @param {object} [options] - Additional options.
     * @param {boolean} [options.checkSocialNotOff] - If true, skip when social === "off".
     * @param {string} [options.preferenceKey] - If provided, check this key in notification_preferences.
     *   If the key value is false, skip sending. If key is missing, default to true (opt-in).
     */
    async sendPushNotification(profileId, { title, body, data }, options = {}) {
      try {
        const result = await pool.query(
          "SELECT push_token, notification_preferences FROM app_public.profiles WHERE id = $1 LIMIT 1",
          [profileId]
        );
        if (result.rows.length === 0) return;

        const { push_token, notification_preferences } = result.rows[0];

        // Check preferenceKey if provided (generalized preference check)
        if (options.preferenceKey) {
          const prefValue = notification_preferences?.[options.preferenceKey];
          // If the key exists and is explicitly false/off, skip
          if (prefValue === false || prefValue === "off") {
            return;
          }
        }

        // Check social preference if requested (legacy support)
        if (options.checkSocialNotOff) {
          const socialMode = notification_preferences?.social;
          if (socialMode === "off" || socialMode === false) {
            return;
          }
        }

        // Check quiet hours
        if (isQuietHours()) return;

        // Check push token
        if (!push_token) return;

        // Send via FCM
        const messaging = await getMessaging();
        if (!messaging) {
          console.log(`[notification-service] FCM not available. Would send to ${profileId}: ${title}`);
          return;
        }

        await messaging.send({
          token: push_token,
          notification: { title, body },
          data: data ? Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)])
          ) : undefined,
        });
      } catch (err) {
        console.error("[notification-service] Failed to send push notification:", err.message);
      }
    },

    /**
     * Send push notifications to all qualifying members of a squad.
     *
     * Batch-fetches all members' tokens and preferences in a single query,
     * then sends to each qualifying member. Fire-and-forget for each send.
     *
     * @param {string} squadId - Squad UUID.
     * @param {string} excludeProfileId - Profile to exclude (e.g., the post author).
     * @param {object} notification - Notification payload.
     * @param {string} notification.title - Notification title.
     * @param {string} notification.body - Notification body.
     * @param {object} [notification.data] - Optional data payload.
     * @param {string} [notification.checkSocialMode] - If provided, only send to members
     *   whose social preference matches this mode (e.g., "all" means only send to "all" users).
     */
    async sendToSquadMembers(squadId, excludeProfileId, { title, body, data, checkSocialMode }) {
      try {
        // Batch fetch all squad members' profiles (excluding sender)
        const result = await pool.query(
          `SELECT p.id, p.push_token, p.notification_preferences
           FROM app_public.squad_members sm
           JOIN app_public.profiles p ON p.id = sm.profile_id
           WHERE sm.squad_id = $1 AND sm.profile_id != $2`,
          [squadId, excludeProfileId]
        );

        if (isQuietHours()) return;

        const messaging = await getMessaging();

        for (const member of result.rows) {
          try {
            // Check social mode preference
            if (checkSocialMode) {
              const socialPref = member.notification_preferences?.social;
              if (socialPref !== checkSocialMode) continue;
            }

            if (!member.push_token) continue;

            if (!messaging) {
              console.log(`[notification-service] FCM not available. Would send to ${member.id}: ${title}`);
              continue;
            }

            await messaging.send({
              token: member.push_token,
              notification: { title, body },
              data: data ? Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v)])
              ) : undefined,
            });
          } catch (memberErr) {
            console.error(`[notification-service] Failed to send to ${member.id}:`, memberErr.message);
          }
        }
      } catch (err) {
        console.error("[notification-service] Failed to send squad notifications:", err.message);
      }
    },
  };
}
