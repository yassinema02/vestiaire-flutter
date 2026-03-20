import { randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const ALLOWED_PURPOSES = ["profile_photo", "item_photo", "shopping_screenshot", "ootd_post", "extraction_photo"];
const ALLOWED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/webp"];

export class UploadValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "UploadValidationError";
    this.statusCode = 400;
    this.code = "VALIDATION_ERROR";
  }
}

/**
 * Creates the upload service.
 *
 * @param {object} options
 * @param {string} [options.gcsBucket] - Google Cloud Storage bucket name (optional).
 * @param {string} [options.localUploadDir] - Local fallback upload directory.
 * @param {string} [options.publicBaseUrl] - Base URL for serving local uploads.
 */
export function createUploadService({
  gcsBucket,
  localUploadDir,
  publicBaseUrl = "http://localhost:8080"
} = {}) {
  return {
    async deleteUserFiles(firebaseUid) {
      try {
        if (gcsBucket) {
          // In production, use @google-cloud/storage to delete files with prefix
          // const { Storage } = await import("@google-cloud/storage");
          // const storage = new Storage();
          // const bucket = storage.bucket(gcsBucket);
          // const [files] = await bucket.getFiles({ prefix: `users/${firebaseUid}/` });
          // await Promise.all(files.map(f => f.delete()));
          // return { filesDeleted: files.length };
          console.log(`[uploads] Would delete GCS files under users/${firebaseUid}/ in bucket ${gcsBucket}`);
          return { filesDeleted: 0 };
        }

        // Local fallback: delete user's local upload directory
        const uploadDir = localUploadDir || path.join(process.cwd(), "uploads");
        const userDir = path.join(uploadDir, "users", firebaseUid);

        if (fs.existsSync(userDir)) {
          fs.rmSync(userDir, { recursive: true, force: true });
          console.log(`[uploads] Deleted local files at ${userDir}`);
          return { filesDeleted: 1 };
        }

        return { filesDeleted: 0 };
      } catch (error) {
        console.error(`[uploads] Error deleting files for user ${firebaseUid}:`, error.message);
        // Don't throw — storage cleanup failure should not block account deletion
        return { filesDeleted: 0, error: error.message };
      }
    },

    async generateSignedUploadUrl(authContext, { purpose, contentType }) {
      if (!ALLOWED_PURPOSES.includes(purpose)) {
        throw new UploadValidationError(
          `Invalid purpose: ${purpose}. Allowed values: ${ALLOWED_PURPOSES.join(", ")}`
        );
      }

      if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
        throw new UploadValidationError(
          `Invalid contentType: ${contentType}. Allowed values: ${ALLOWED_CONTENT_TYPES.join(", ")}`
        );
      }

      const ext = contentType === "image/png" ? "png" : contentType === "image/webp" ? "webp" : "jpg";
      const fileId = randomUUID();

      const subDir =
        purpose === "profile_photo"
          ? `users/${authContext.userId}/profile`
          : purpose === "shopping_screenshot"
            ? `users/${authContext.userId}/shopping`
            : purpose === "ootd_post"
              ? `users/${authContext.userId}/ootd`
              : purpose === "extraction_photo"
                ? `users/${authContext.userId}/extractions`
                : `users/${authContext.userId}/items`;

      const objectPath = `${subDir}/${fileId}.${ext}`;

      // If GCS bucket is configured, generate a signed URL (placeholder for production)
      if (gcsBucket) {
        // In production, this would use @google-cloud/storage to generate a signed URL.
        // For now, return a placeholder structure.
        const uploadUrl = `https://storage.googleapis.com/upload/storage/v1/b/${gcsBucket}/o?uploadType=media&name=${encodeURIComponent(objectPath)}`;
        const publicUrl = `https://storage.googleapis.com/${gcsBucket}/${objectPath}`;

        return { uploadUrl, publicUrl };
      }

      // Local fallback: create the directory and return a local URL
      const uploadDir = localUploadDir || path.join(process.cwd(), "uploads");
      const fullDir = path.join(uploadDir, subDir);
      fs.mkdirSync(fullDir, { recursive: true });

      const localPath = path.join(fullDir, `${fileId}.${ext}`);
      const uploadUrl = localPath; // In dev, client writes directly to this path
      const publicUrl = `${publicBaseUrl}/uploads/${objectPath}`;

      return { uploadUrl, publicUrl };
    }
  };
}
