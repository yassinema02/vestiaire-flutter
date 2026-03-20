/**
 * Service for badge evaluation and catalog business logic.
 *
 * Contains business logic for badge evaluation, catalog retrieval,
 * and user badge collection. Delegates to badgeRepo for data access.
 */

/**
 * @param {object} options
 * @param {object} options.badgeRepo - Badge repository instance.
 */
export function createBadgeService({ badgeRepo }) {
  if (!badgeRepo) {
    throw new TypeError("badgeRepo is required");
  }

  return {
    /**
     * Evaluate and award badges for a user.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { badgesAwarded: [...] }
     */
    async evaluateAndAward(authContext) {
      const badgesAwarded = await badgeRepo.evaluateBadges(authContext);
      return { badgesAwarded };
    },

    /**
     * Check and award a specific badge for a user.
     *
     * Triggers a full badge evaluation which checks all badges,
     * including the specified one. Returns the list of newly awarded badges.
     *
     * @param {object} authContext - Must have userId.
     * @param {string} badgeKey - The badge key to check (e.g., 'circular_champion').
     * @returns {Promise<object>} { badgesAwarded: [...] }
     */
    async checkAndAward(authContext, badgeKey) {
      const badgesAwarded = await badgeRepo.evaluateBadges(authContext);
      return { badgesAwarded };
    },

    /**
     * Get the full badge catalog.
     *
     * @returns {Promise<Array<object>>} All badge definitions.
     */
    async getBadgeCatalog() {
      return badgeRepo.getAllBadges();
    },

    /**
     * Get a user's badge collection with count.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { badges: [...], badgeCount: N }
     */
    async getUserBadgeCollection(authContext) {
      const badges = await badgeRepo.getUserBadges(authContext);
      return { badges, badgeCount: badges.length };
    },
  };
}
