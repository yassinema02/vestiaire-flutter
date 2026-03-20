import {
  VALID_CATEGORIES,
  VALID_COLORS,
  VALID_PATTERNS,
  VALID_MATERIALS,
  VALID_STYLES,
  VALID_SEASONS,
  VALID_OCCASIONS,
  VALID_CURRENCIES
} from "../ai/taxonomy.js";

export class ItemValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ItemValidationError";
    this.statusCode = 400;
    this.code = "VALIDATION_ERROR";
  }
}

export function createItemService({ repo, backgroundRemovalService = null, categorizationService = null }) {
  if (!repo || typeof repo.createItem !== "function") {
    throw new TypeError("repo.createItem is required");
  }

  return {
    async createItemForUser(authContext, itemData) {
      if (!itemData.photoUrl || typeof itemData.photoUrl !== "string") {
        throw new ItemValidationError("photoUrl is required and must be a string");
      }

      if (itemData.name !== undefined && itemData.name !== null) {
        if (typeof itemData.name !== "string" || itemData.name.length > 200) {
          throw new ItemValidationError(
            "name must be a string of at most 200 characters"
          );
        }
      }

      // Determine if background removal should be triggered
      const shouldRemoveBg = backgroundRemovalService?.geminiClient?.isAvailable?.() ?? false;
      const shouldCategorize = categorizationService !== null && shouldRemoveBg;

      const item = await repo.createItem(authContext, {
        photoUrl: itemData.photoUrl,
        name: itemData.name ?? null,
        originalPhotoUrl: shouldRemoveBg ? itemData.photoUrl : null,
        bgRemovalStatus: shouldRemoveBg ? "pending" : null,
        categorizationStatus: shouldCategorize ? "pending" : null
      });

      // Fire-and-forget background removal, then chain categorization
      if (shouldRemoveBg && backgroundRemovalService) {
        const bgPromise = backgroundRemovalService
          .removeBackground(authContext, {
            itemId: item.id,
            imageUrl: item.photoUrl
          })
          .catch((err) => {
            console.error("[bg-removal] Failed:", err.message ?? err);
            return { cleanedImageUrl: null };
          });

        // Chain categorization AFTER background removal
        if (shouldCategorize) {
          bgPromise.then((bgResult) => {
            const imageForCategorization = bgResult?.cleanedImageUrl || item.photoUrl;
            categorizationService
              .categorizeItem(authContext, {
                itemId: item.id,
                imageUrl: imageForCategorization
              })
              .catch((err) => {
                console.error("[categorization] Failed:", err.message ?? err);
              });
          });
        }
      }

      return { item };
    },

    async listItemsForUser(authContext, options = {}) {
      const limit =
        options.limit !== undefined ? parseInt(String(options.limit), 10) : undefined;

      const filterParams = {};

      if (options.category !== undefined) {
        if (!VALID_CATEGORIES.includes(options.category)) {
          throw new ItemValidationError(`Invalid category filter: ${options.category}`);
        }
        filterParams.category = options.category;
      }

      if (options.color !== undefined) {
        if (!VALID_COLORS.includes(options.color)) {
          throw new ItemValidationError(`Invalid color filter: ${options.color}`);
        }
        filterParams.color = options.color;
      }

      if (options.season !== undefined) {
        if (!VALID_SEASONS.includes(options.season)) {
          throw new ItemValidationError(`Invalid season filter: ${options.season}`);
        }
        filterParams.season = options.season;
      }

      if (options.occasion !== undefined) {
        if (!VALID_OCCASIONS.includes(options.occasion)) {
          throw new ItemValidationError(`Invalid occasion filter: ${options.occasion}`);
        }
        filterParams.occasion = options.occasion;
      }

      // Brand is user-entered freeform text, no taxonomy validation
      if (options.brand !== undefined) {
        filterParams.brand = options.brand;
      }

      // Neglect status filter: only "neglected" is valid
      if (options.neglectStatus !== undefined) {
        if (options.neglectStatus !== "neglected") {
          throw new ItemValidationError(`Invalid neglect_status filter: ${options.neglectStatus}. Only "neglected" is supported.`);
        }
        filterParams.neglectStatus = options.neglectStatus;
      }

      const items = await repo.listItems(authContext, { limit, ...filterParams });
      return { items };
    },

    async getItemForUser(authContext, itemId) {
      const item = await repo.getItem(authContext, itemId);
      if (!item) {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
      return { item };
    },

    async updateItemForUser(authContext, itemId, updateData) {
      const validatedFields = {};

      // Validate taxonomy fields
      if (updateData.category !== undefined) {
        if (!VALID_CATEGORIES.includes(updateData.category)) {
          throw new ItemValidationError(`Invalid category: ${updateData.category}`);
        }
        validatedFields.category = updateData.category;
      }

      if (updateData.color !== undefined) {
        if (!VALID_COLORS.includes(updateData.color)) {
          throw new ItemValidationError(`Invalid color: ${updateData.color}`);
        }
        validatedFields.color = updateData.color;
      }

      if (updateData.secondaryColors !== undefined || updateData.secondary_colors !== undefined) {
        const colors = updateData.secondaryColors ?? updateData.secondary_colors;
        if (!Array.isArray(colors) || !colors.every((c) => VALID_COLORS.includes(c))) {
          throw new ItemValidationError("Invalid secondary_colors: each value must be a valid color");
        }
        validatedFields.secondary_colors = colors;
      }

      if (updateData.pattern !== undefined) {
        if (!VALID_PATTERNS.includes(updateData.pattern)) {
          throw new ItemValidationError(`Invalid pattern: ${updateData.pattern}`);
        }
        validatedFields.pattern = updateData.pattern;
      }

      if (updateData.material !== undefined) {
        if (!VALID_MATERIALS.includes(updateData.material)) {
          throw new ItemValidationError(`Invalid material: ${updateData.material}`);
        }
        validatedFields.material = updateData.material;
      }

      if (updateData.style !== undefined) {
        if (!VALID_STYLES.includes(updateData.style)) {
          throw new ItemValidationError(`Invalid style: ${updateData.style}`);
        }
        validatedFields.style = updateData.style;
      }

      if (updateData.season !== undefined) {
        if (!Array.isArray(updateData.season) || !updateData.season.every((s) => VALID_SEASONS.includes(s))) {
          throw new ItemValidationError("Invalid season: each value must be a valid season");
        }
        validatedFields.season = updateData.season;
      }

      if (updateData.occasion !== undefined) {
        if (!Array.isArray(updateData.occasion) || !updateData.occasion.every((o) => VALID_OCCASIONS.includes(o))) {
          throw new ItemValidationError("Invalid occasion: each value must be a valid occasion");
        }
        validatedFields.occasion = updateData.occasion;
      }

      // Validate optional metadata fields
      if (updateData.name !== undefined) {
        if (updateData.name !== null && (typeof updateData.name !== "string" || updateData.name.length > 200)) {
          throw new ItemValidationError("name must be a string of at most 200 characters");
        }
        validatedFields.name = updateData.name;
      }

      if (updateData.brand !== undefined) {
        if (updateData.brand !== null && (typeof updateData.brand !== "string" || updateData.brand.length > 100)) {
          throw new ItemValidationError("brand must be a string of at most 100 characters");
        }
        validatedFields.brand = updateData.brand;
      }

      if (updateData.purchasePrice !== undefined || updateData.purchase_price !== undefined) {
        const price = updateData.purchasePrice ?? updateData.purchase_price;
        if (price !== null && (typeof price !== "number" || price < 0)) {
          throw new ItemValidationError("purchase_price must be a number >= 0");
        }
        validatedFields.purchasePrice = price;
      }

      if (updateData.purchaseDate !== undefined || updateData.purchase_date !== undefined) {
        const dateStr = updateData.purchaseDate ?? updateData.purchase_date;
        if (dateStr !== null) {
          const parsed = new Date(dateStr);
          if (isNaN(parsed.getTime())) {
            throw new ItemValidationError("purchase_date must be a valid ISO date string");
          }
        }
        validatedFields.purchaseDate = dateStr;
      }

      if (updateData.currency !== undefined) {
        if (updateData.currency !== null && !VALID_CURRENCIES.includes(updateData.currency)) {
          throw new ItemValidationError(`Invalid currency: ${updateData.currency}. Must be one of: ${VALID_CURRENCIES.join(", ")}`);
        }
        validatedFields.currency = updateData.currency;
      }

      if (updateData.isFavorite !== undefined) {
        if (typeof updateData.isFavorite !== "boolean") {
          throw new ItemValidationError("isFavorite must be a boolean");
        }
        validatedFields.isFavorite = updateData.isFavorite;
      }

      if (updateData.resaleStatus !== undefined) {
        const validStatuses = ["listed", "sold", "donated", null];
        if (!validStatuses.includes(updateData.resaleStatus)) {
          throw new ItemValidationError(`Invalid resaleStatus: ${updateData.resaleStatus}`);
        }
        validatedFields.resaleStatus = updateData.resaleStatus;
      }

      if (Object.keys(validatedFields).length === 0) {
        throw new ItemValidationError("No valid fields to update");
      }

      const updatedItem = await repo.updateItem(authContext, itemId, validatedFields);
      if (!updatedItem) {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }

      return { item: updatedItem };
    },

    async deleteItemForUser(authContext, itemId) {
      const result = await repo.deleteItem(authContext, itemId);
      if (!result) {
        const error = new Error("Item not found");
        error.statusCode = 404;
        error.code = "NOT_FOUND";
        throw error;
      }
      return { deleted: true };
    }
  };
}
