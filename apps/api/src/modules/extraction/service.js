export class ExtractionValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ExtractionValidationError";
    this.statusCode = 400;
    this.code = "VALIDATION_ERROR";
  }
}

export function createExtractionService({ extractionRepo, itemRepo, itemService }) {
  if (!extractionRepo) {
    throw new TypeError("extractionRepo is required");
  }

  return {
    async createExtractionJob(authContext, { totalPhotos, photos }) {
      // Validate inputs
      if (!totalPhotos || totalPhotos < 1 || totalPhotos > 50) {
        throw new ExtractionValidationError(
          "totalPhotos must be between 1 and 50"
        );
      }

      if (!Array.isArray(photos) || photos.length === 0) {
        throw new ExtractionValidationError(
          "photos array is required and must not be empty"
        );
      }

      if (photos.length !== totalPhotos) {
        throw new ExtractionValidationError(
          `totalPhotos (${totalPhotos}) must match photos array length (${photos.length})`
        );
      }

      // Validate each photo has a photoUrl
      for (const photo of photos) {
        if (!photo.photoUrl) {
          throw new ExtractionValidationError(
            "Each photo must have a photoUrl"
          );
        }
      }

      // Create the job record
      const job = await extractionRepo.createJob(authContext, { totalPhotos });

      // Insert each photo record
      const insertedPhotos = [];
      for (const photo of photos) {
        const inserted = await extractionRepo.addJobPhoto(authContext, {
          jobId: job.id,
          photoUrl: photo.photoUrl,
          originalFilename: photo.originalFilename || null
        });
        insertedPhotos.push(inserted);
      }

      // Update job status to 'processing' and set uploaded count
      const updatedJob = await extractionRepo.updateJobStatus(authContext, job.id, {
        status: "processing",
        uploadedPhotos: insertedPhotos.length
      });

      return {
        ...updatedJob,
        photos: insertedPhotos
      };
    },

    async confirmExtractionJob(authContext, jobId, { keptItemIds, metadataEdits }) {
      // Load the job and verify status
      const job = await extractionRepo.getJob(authContext, jobId);
      if (!job) {
        const error = new Error("Extraction job not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }

      if (!["completed", "partial"].includes(job.status)) {
        throw new ExtractionValidationError(
          `Cannot confirm job with status '${job.status}'. Job must be 'completed' or 'partial'.`
        );
      }

      const keptIds = keptItemIds || [];
      const edits = metadataEdits || {};

      // If no items to keep, still mark as confirmed
      if (keptIds.length === 0) {
        await extractionRepo.updateJobStatus(authContext, jobId, {
          status: "confirmed"
        });
        return { confirmedCount: 0, items: [] };
      }

      // Validate that kept item IDs belong to this job
      const extractionItems = await extractionRepo.getExtractionItemsByIds(
        authContext, jobId, keptIds
      );

      if (extractionItems.length !== keptIds.length) {
        const foundIds = new Set(extractionItems.map(i => i.id));
        const invalidIds = keptIds.filter(id => !foundIds.has(id));
        throw new ExtractionValidationError(
          `Invalid item IDs: ${invalidIds.join(", ")}. Items must belong to this extraction job.`
        );
      }

      // Create real items for each kept extraction item
      const createdItems = [];
      for (const extractionItem of extractionItems) {
        // Apply metadata edits if present
        const itemEdits = edits[extractionItem.id] || {};
        const name = itemEdits.name ?? extractionItem.name ??
          (extractionItem.color && extractionItem.category
            ? `${extractionItem.color.charAt(0).toUpperCase() + extractionItem.color.slice(1)} ${extractionItem.category.charAt(0).toUpperCase() + extractionItem.category.slice(1)}`
            : null);

        const newItem = await itemRepo.createItemFromExtraction(authContext, {
          photoUrl: extractionItem.photoUrl,
          name,
          originalPhotoUrl: extractionItem.originalCropUrl || null,
          category: itemEdits.category ?? extractionItem.category,
          color: itemEdits.color ?? extractionItem.color,
          secondaryColors: itemEdits.secondaryColors ?? extractionItem.secondaryColors,
          pattern: itemEdits.pattern ?? extractionItem.pattern,
          material: itemEdits.material ?? extractionItem.material,
          style: itemEdits.style ?? extractionItem.style,
          season: itemEdits.season ?? extractionItem.season,
          occasion: itemEdits.occasion ?? extractionItem.occasion,
          bgRemovalStatus: extractionItem.bgRemovalStatus || "completed",
          categorizationStatus: extractionItem.categorizationStatus || "completed",
          creationMethod: "ai_extraction",
          extractionJobId: jobId
        });

        createdItems.push(newItem);
      }

      // Update job status to confirmed
      await extractionRepo.updateJobStatus(authContext, jobId, {
        status: "confirmed"
      });

      return { confirmedCount: createdItems.length, items: createdItems };
    },

    async checkDuplicates(authContext, jobId) {
      // Load the job
      const job = await extractionRepo.getJob(authContext, jobId);
      if (!job) {
        const error = new Error("Extraction job not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }

      // Get extraction items
      const extractionItems = await extractionRepo.getJobItems(authContext, jobId);

      // Get user's existing wardrobe items
      const { items: wardrobeItems } = await itemService.listItemsForUser(authContext, {});

      // Match by category + color
      const duplicates = [];
      for (const ei of extractionItems) {
        if (!ei.category || !ei.color) continue;
        const match = wardrobeItems.find(wi =>
          wi.category === ei.category && wi.color === ei.color
        );
        if (match) {
          duplicates.push({
            extractionItemId: ei.id,
            matchingItemId: match.id,
            matchingItemPhotoUrl: match.photoUrl,
            matchingItemName: match.name
          });
        }
      }

      return { duplicates };
    }
  };
}
