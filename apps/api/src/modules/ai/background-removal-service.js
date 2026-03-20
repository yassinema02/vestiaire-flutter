/**
 * Background removal service using Gemini 2.0 Flash via Vertex AI.
 *
 * Downloads the original image, sends it to Gemini for background removal,
 * uploads the cleaned image, updates the item record, and logs the AI call.
 */

import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";

const BG_REMOVAL_MODEL = "gemini-2.0-flash";
const BG_REMOVAL_PROMPT =
  "Remove the background from this clothing item image. Replace the background with solid white (#FFFFFF). Preserve the clothing item with clean, natural edges. Output only the processed image.";

/**
 * @param {object} options
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.itemRepo - Item repository with updateItem method.
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {object} [options.uploadService] - Upload service for generating paths.
 */
export function createBackgroundRemovalService({
  geminiClient,
  itemRepo,
  aiUsageLogRepo,
  uploadService
}) {
  return {
    /**
     * Remove the background from an item's image.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {string} params.itemId - The item's UUID.
     * @param {string} params.imageUrl - URL or path of the original image.
     * @returns {Promise<{ cleanedImageUrl: string | null, status: string }>}
     */
    async removeBackground(authContext, { itemId, imageUrl }) {
      if (!geminiClient.isAvailable()) {
        console.warn("[bg-removal] Gemini client not available. Skipping background removal.");
        return { cleanedImageUrl: null, status: "skipped" };
      }

      const startTime = Date.now();

      try {
        // Step 1: Read the image data
        const imageData = await readImageData(imageUrl);

        // Step 2: Call Gemini for background removal
        const model = await geminiClient.getGenerativeModel(BG_REMOVAL_MODEL);
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [
                {
                  inlineData: {
                    mimeType: "image/jpeg",
                    data: imageData.toString("base64")
                  }
                },
                { text: BG_REMOVAL_PROMPT }
              ]
            }
          ]
        });

        const response = result.response;
        const latencyMs = Date.now() - startTime;

        // Extract the cleaned image from the response
        const cleanedImageData = extractImageFromResponse(response);

        if (!cleanedImageData) {
          throw new Error("Gemini response did not contain an image");
        }

        // Step 3: Upload the cleaned image
        const cleanedImageUrl = await uploadCleanedImage(
          authContext,
          itemId,
          cleanedImageData,
          imageUrl,
          uploadService
        );

        // Step 4: Update the item record
        await itemRepo.updateItem(authContext, itemId, {
          photoUrl: cleanedImageUrl,
          bgRemovalStatus: "completed"
        });

        // Step 5: Log the AI usage
        const usageMetadata = response?.usageMetadata ?? {};
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "background_removal",
          model: BG_REMOVAL_MODEL,
          inputTokens: usageMetadata.promptTokenCount ?? null,
          outputTokens: usageMetadata.candidatesTokenCount ?? null,
          latencyMs,
          estimatedCostUsd: estimateCost(usageMetadata),
          status: "success"
        });

        return { cleanedImageUrl, status: "completed" };
      } catch (error) {
        const latencyMs = Date.now() - startTime;

        console.error("[bg-removal] Failed:", error.message);

        // Update item status to failed
        try {
          await itemRepo.updateItem(authContext, itemId, {
            bgRemovalStatus: "failed"
          });
        } catch (updateError) {
          console.error("[bg-removal] Failed to update item status:", updateError.message);
        }

        // Log the failure
        try {
          await aiUsageLogRepo.logUsage(authContext, {
            feature: "background_removal",
            model: BG_REMOVAL_MODEL,
            latencyMs,
            status: "failure",
            errorMessage: error.message
          });
        } catch (logError) {
          console.error("[bg-removal] Failed to log AI usage:", logError.message);
        }

        return { cleanedImageUrl: null, status: "failed" };
      }
    }
  };
}

/**
 * Read image data from a URL or local file path.
 */
async function readImageData(imageUrl) {
  // Local file path
  if (imageUrl.startsWith("/") || imageUrl.startsWith("file://")) {
    const filePath = imageUrl.replace("file://", "");
    return fs.readFileSync(filePath);
  }

  // HTTP(S) URL - fetch the image
  if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to download image: ${response.status} ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }

  throw new Error(`Unsupported image URL format: ${imageUrl}`);
}

/**
 * Extract image data from the Gemini response.
 */
function extractImageFromResponse(response) {
  if (!response?.candidates?.[0]?.content?.parts) {
    return null;
  }

  for (const part of response.candidates[0].content.parts) {
    if (part.inlineData?.data) {
      return Buffer.from(part.inlineData.data, "base64");
    }
  }

  return null;
}

/**
 * Upload the cleaned image and return its URL.
 */
async function uploadCleanedImage(authContext, itemId, imageData, originalUrl, uploadService) {
  // For local development, write to a local path
  if (originalUrl.startsWith("/") || originalUrl.includes("/uploads/")) {
    const uploadsDir = path.join(process.cwd(), "uploads", "users", authContext.userId, "items");
    fs.mkdirSync(uploadsDir, { recursive: true });
    const cleanedPath = path.join(uploadsDir, `${itemId}_cleaned.png`);
    fs.writeFileSync(cleanedPath, imageData);

    if (uploadService?.publicBaseUrl) {
      return `${uploadService.publicBaseUrl}/uploads/users/${authContext.userId}/items/${itemId}_cleaned.png`;
    }
    return cleanedPath;
  }

  // For GCS URLs, upload via the storage SDK
  // This would use @google-cloud/storage in production
  const cleanedFileName = `${itemId}_cleaned.png`;
  const uploadsDir = path.join(process.cwd(), "uploads", "users", authContext.userId, "items");
  fs.mkdirSync(uploadsDir, { recursive: true });
  const cleanedPath = path.join(uploadsDir, cleanedFileName);
  fs.writeFileSync(cleanedPath, imageData);

  return cleanedPath;
}

/**
 * Estimate the cost of a Gemini API call based on token usage.
 * Gemini 2.0 Flash pricing: ~$0.075 per 1M input tokens, ~$0.30 per 1M output tokens.
 */
function estimateCost(usageMetadata) {
  const inputTokens = usageMetadata?.promptTokenCount ?? 0;
  const outputTokens = usageMetadata?.candidatesTokenCount ?? 0;

  const inputCost = (inputTokens / 1_000_000) * 0.075;
  const outputCost = (outputTokens / 1_000_000) * 0.30;

  return inputCost + outputCost;
}
