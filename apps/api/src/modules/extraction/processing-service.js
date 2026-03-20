/**
 * Extraction processing service for bulk photo item detection.
 *
 * Processes extraction job photos sequentially: detects multiple clothing items
 * per photo using Gemini Vision, runs background removal and categorization on
 * each detected item, and stores results in extraction_job_items.
 *
 * Story 10.2: Bulk Extraction Processing (FR-EXT-02, FR-EXT-03, FR-EXT-04)
 */

import { validateTaxonomy } from "../ai/categorization-service.js";

const DETECTION_MODEL = "gemini-2.0-flash";

const MULTI_ITEM_DETECTION_PROMPT = `Analyze this photo and identify all individual clothing items visible.
For each item detected, provide its details as a JSON array.
Return ONLY valid JSON with this structure:
{
  "items": [
    {
      "description": "Brief description of the item (e.g., 'blue denim jacket')",
      "confidence": 0.95,
      "category": "one of: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other",
      "color": "primary color, one of: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown",
      "secondary_colors": ["array of additional colors, empty if solid"],
      "pattern": "one of: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other",
      "material": "best guess, one of: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown",
      "style": "one of: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other",
      "season": ["suitable seasons: spring, summer, fall, winter, all"],
      "occasion": ["suitable occasions: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge"]
    }
  ]
}

Rules:
- Detect up to 5 clothing items maximum.
- If the photo shows a single item clearly, return an array with 1 item.
- If the photo contains no recognizable clothing, return {"items": []}.
- Do NOT include people, backgrounds, or non-clothing objects.
- Each item should be a distinct garment or accessory.`;

const BG_REMOVAL_PROMPT = "Remove the background from this clothing item image. Replace the background with solid white (#FFFFFF). Preserve the clothing item with clean, natural edges. Output only the processed image.";

/**
 * Read image data from a URL or local file path.
 * Reuses the same pattern from background-removal-service.js.
 */
async function readImageData(imageUrl) {
  if (imageUrl.startsWith("/") || imageUrl.startsWith("file://")) {
    const { default: fs } = await import("node:fs");
    const filePath = imageUrl.replace("file://", "");
    return fs.readFileSync(filePath);
  }

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

/**
 * Extract image data from a Gemini response (for bg removal).
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
 * Upload a cleaned image and return its URL.
 */
async function uploadCleanedImage(authContext, jobId, photoId, itemIndex, imageData, uploadService) {
  const { default: fs } = await import("node:fs");
  const { default: path } = await import("node:path");

  const fileName = `${photoId}_${itemIndex}_cleaned.png`;
  const uploadsDir = path.join(process.cwd(), "uploads", "users", authContext.userId, "extractions", jobId);
  fs.mkdirSync(uploadsDir, { recursive: true });
  const cleanedPath = path.join(uploadsDir, fileName);
  fs.writeFileSync(cleanedPath, imageData);

  if (uploadService?.publicBaseUrl) {
    return `${uploadService.publicBaseUrl}/uploads/users/${authContext.userId}/extractions/${jobId}/${fileName}`;
  }
  return cleanedPath;
}

/**
 * @param {object} options
 * @param {object} options.extractionRepo - Extraction repository with item CRUD.
 * @param {object} options.geminiClient - Gemini client with getGenerativeModel and isAvailable.
 * @param {object} options.backgroundRemovalService - Background removal service (used for pattern, not directly).
 * @param {object} options.aiUsageLogRepo - AI usage log repository.
 * @param {object} [options.uploadService] - Upload service for generating paths.
 */
export function createExtractionProcessingService({
  extractionRepo,
  geminiClient,
  backgroundRemovalService,
  aiUsageLogRepo,
  uploadService
}) {
  if (!extractionRepo) throw new TypeError("extractionRepo is required");
  if (!geminiClient) throw new TypeError("geminiClient is required");
  if (!aiUsageLogRepo) throw new TypeError("aiUsageLogRepo is required");

  return {
    /**
     * Process an entire extraction job: detect items in each photo,
     * run bg removal and categorization, store results.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {string} jobId - The extraction job UUID.
     */
    async processExtractionJob(authContext, jobId) {
      // Load the job and all its photos
      const job = await extractionRepo.getJob(authContext, jobId);

      if (!job) {
        throw new Error(`Extraction job not found: ${jobId}`);
      }

      if (job.status !== "processing") {
        throw new Error(`Extraction job ${jobId} is not in 'processing' status (current: ${job.status})`);
      }

      const photos = job.photos || [];
      let processedCount = 0;
      let totalItemsFound = 0;

      // Process photos sequentially to avoid Gemini rate limits
      for (const photo of photos) {
        if (photo.status !== "uploaded") {
          continue;
        }

        try {
          const itemsFound = await processPhoto(authContext, job, photo);
          totalItemsFound += itemsFound;
          processedCount++;

          // Update job counters after each photo
          await extractionRepo.updateJobStatus(authContext, jobId, {
            processedPhotos: processedCount,
            totalItemsFound
          });
        } catch (error) {
          console.error(`[extraction-processing] Photo ${photo.id} failed:`, error.message);

          // Mark photo as failed and continue
          try {
            await extractionRepo.updatePhotoStatus(authContext, photo.id, {
              status: "failed",
              errorMessage: error.message
            });
          } catch (updateError) {
            console.error(`[extraction-processing] Failed to update photo status:`, updateError.message);
          }

          processedCount++;
          await extractionRepo.updateJobStatus(authContext, jobId, {
            processedPhotos: processedCount,
            totalItemsFound
          });
        }
      }

      // Compute final job status
      // Re-fetch to get updated photo statuses
      const updatedJob = await extractionRepo.getJob(authContext, jobId);
      const updatedPhotos = updatedJob?.photos || [];
      const succeededPhotos = updatedPhotos.filter(p => p.status === "completed").length;
      const totalPhotos = updatedPhotos.length;

      let finalStatus;
      if (succeededPhotos === totalPhotos) {
        finalStatus = "completed";
      } else if (succeededPhotos === 0) {
        finalStatus = "failed";
      } else {
        finalStatus = "partial";
      }

      await extractionRepo.updateJobStatus(authContext, jobId, {
        status: finalStatus,
        processedPhotos: processedCount,
        totalItemsFound
      });
    }
  };

  /**
   * Process a single photo: detect items, run bg removal + categorization per item.
   *
   * @param {object} authContext
   * @param {object} job
   * @param {object} photo
   * @returns {Promise<number>} Number of items found
   */
  async function processPhoto(authContext, job, photo) {
    const startTime = Date.now();

    // Read image data
    const imageData = await readImageData(photo.photoUrl);

    // Call Gemini for multi-item detection
    const model = await geminiClient.getGenerativeModel(DETECTION_MODEL);
    const result = await model.generateContent({
      contents: [{
        role: "user",
        parts: [
          { inlineData: { mimeType: "image/jpeg", data: imageData.toString("base64") } },
          { text: MULTI_ITEM_DETECTION_PROMPT }
        ]
      }],
      generationConfig: { responseMimeType: "application/json" }
    });

    const response = result.response;
    const latencyMs = Date.now() - startTime;

    // Log the detection AI call
    const usageMetadata = response?.usageMetadata ?? {};
    try {
      await aiUsageLogRepo.logUsage(authContext, {
        feature: "extraction_detection",
        model: DETECTION_MODEL,
        inputTokens: usageMetadata.promptTokenCount ?? null,
        outputTokens: usageMetadata.candidatesTokenCount ?? null,
        latencyMs,
        estimatedCostUsd: estimateCost(usageMetadata),
        status: "success"
      });
    } catch (logError) {
      console.error("[extraction-processing] Failed to log detection AI usage:", logError.message);
    }

    // Parse detection results
    const rawText = response.candidates[0].content.parts[0].text;
    const parsed = JSON.parse(rawText);
    const detectedItems = (parsed.items || []).slice(0, 5);

    // Process each detected item
    for (let i = 0; i < detectedItems.length; i++) {
      await extractAndProcessItem(authContext, job.id, photo.id, detectedItems[i], imageData, i);
    }

    // Update photo status
    await extractionRepo.updatePhotoStatus(authContext, photo.id, {
      status: "completed",
      itemsFound: detectedItems.length
    });

    return detectedItems.length;
  }

  /**
   * Extract and process a single item from a photo.
   *
   * @param {object} authContext
   * @param {string} jobId
   * @param {string} photoId
   * @param {object} itemData - Detection data from Gemini
   * @param {Buffer} imageData - Original photo image data
   * @param {number} itemIndex - 0-based index within the photo
   */
  async function extractAndProcessItem(authContext, jobId, photoId, itemData, imageData, itemIndex) {
    // Validate categorization from detection response
    const validated = validateTaxonomy(itemData);

    let cleanedImageUrl = null;
    let bgRemovalStatus = "pending";
    let originalCropUrl = null;

    // Run background removal
    try {
      const bgStartTime = Date.now();
      const bgModel = await geminiClient.getGenerativeModel(DETECTION_MODEL);

      // For multi-item photos, ask Gemini to isolate the specific item
      const bgPrompt = itemData.description
        ? `Remove the background and isolate only the ${itemData.description} from this image. Replace the background with solid white (#FFFFFF). Output only the processed image.`
        : BG_REMOVAL_PROMPT;

      const bgResult = await bgModel.generateContent({
        contents: [{
          role: "user",
          parts: [
            { inlineData: { mimeType: "image/jpeg", data: imageData.toString("base64") } },
            { text: bgPrompt }
          ]
        }]
      });

      const bgResponse = bgResult.response;
      const bgLatencyMs = Date.now() - bgStartTime;

      const cleanedData = extractImageFromResponse(bgResponse);

      if (cleanedData) {
        cleanedImageUrl = await uploadCleanedImage(
          authContext, jobId, photoId, itemIndex, cleanedData, uploadService
        );
        bgRemovalStatus = "completed";
      } else {
        bgRemovalStatus = "failed";
      }

      // Log bg removal AI usage
      const bgUsageMetadata = bgResponse?.usageMetadata ?? {};
      try {
        await aiUsageLogRepo.logUsage(authContext, {
          feature: "extraction_bg_removal",
          model: DETECTION_MODEL,
          inputTokens: bgUsageMetadata.promptTokenCount ?? null,
          outputTokens: bgUsageMetadata.candidatesTokenCount ?? null,
          latencyMs: bgLatencyMs,
          estimatedCostUsd: estimateCost(bgUsageMetadata),
          status: cleanedData ? "success" : "failure"
        });
      } catch (logError) {
        console.error("[extraction-processing] Failed to log bg removal AI usage:", logError.message);
      }
    } catch (bgError) {
      console.error("[extraction-processing] Background removal failed for item:", bgError.message);
      bgRemovalStatus = "failed";
    }

    // Log categorization (already done via detection prompt, just log it)
    try {
      await aiUsageLogRepo.logUsage(authContext, {
        feature: "extraction_categorization",
        model: DETECTION_MODEL,
        inputTokens: null,
        outputTokens: null,
        latencyMs: 0,
        estimatedCostUsd: 0,
        status: "success"
      });
    } catch (logError) {
      console.error("[extraction-processing] Failed to log categorization AI usage:", logError.message);
    }

    // Use the cleaned image URL or fall back to the original photo URL
    const finalPhotoUrl = cleanedImageUrl || `extraction://${jobId}/${photoId}/${itemIndex}`;

    // Insert into extraction_job_items
    await extractionRepo.addJobItem(authContext, {
      jobId,
      photoId,
      itemIndex,
      photoUrl: finalPhotoUrl,
      originalCropUrl,
      category: validated.category,
      color: validated.color,
      secondaryColors: validated.secondaryColors,
      pattern: validated.pattern,
      material: validated.material,
      style: validated.style,
      season: validated.season,
      occasion: validated.occasion,
      bgRemovalStatus,
      categorizationStatus: "completed",
      detectionConfidence: itemData.confidence ?? null
    });
  }
}
