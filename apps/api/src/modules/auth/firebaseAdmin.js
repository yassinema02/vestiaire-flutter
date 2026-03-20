/**
 * Firebase Admin SDK service for server-side user management.
 *
 * Provides a deleteUser(uid) method that uses Firebase Admin SDK
 * to delete a Firebase Auth account. Falls back to a stub in
 * local dev when credentials are not available.
 */
export function createFirebaseAdminService({ serviceAccountPath } = {}) {
  let adminAuth = null;
  let initialized = false;

  function initialize() {
    if (initialized) return;
    initialized = true;

    try {
      // Dynamic import would be ideal but for simplicity we use
      // require-style detection. In ESM we attempt import at call time.
      if (!serviceAccountPath && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        console.warn(
          "[firebase-admin] No service account path or application default credentials found. " +
          "Firebase Admin SDK will not be initialized. User deletion from Firebase Auth will be skipped."
        );
        return;
      }
    } catch {
      console.warn("[firebase-admin] Could not initialize Firebase Admin SDK.");
    }
  }

  return {
    async deleteUser(uid) {
      initialize();

      if (!serviceAccountPath && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        console.warn(
          `[firebase-admin] Skipping Firebase Auth deletion for user ${uid} — no credentials configured.`
        );
        return { skipped: true };
      }

      try {
        // Lazy import firebase-admin
        const { default: admin } = await import("firebase-admin");

        if (admin.apps.length === 0) {
          if (serviceAccountPath) {
            const { default: fs } = await import("node:fs");
            const serviceAccount = JSON.parse(
              fs.readFileSync(serviceAccountPath, "utf8")
            );
            admin.initializeApp({
              credential: admin.credential.cert(serviceAccount)
            });
          } else {
            admin.initializeApp();
          }
        }

        await admin.auth().deleteUser(uid);
        return { deleted: true };
      } catch (error) {
        console.error(
          `[firebase-admin] Failed to delete Firebase Auth user ${uid}:`,
          error.message
        );
        // Don't throw — Firebase deletion failure should not block account deletion
        return { error: error.message };
      }
    }
  };
}
