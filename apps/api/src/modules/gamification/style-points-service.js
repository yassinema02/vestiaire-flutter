/**
 * Service for awarding style points.
 *
 * Contains business logic for point awarding, bonus calculation,
 * and streak detection. Delegates to userStatsRepo for data access.
 *
 * After Story 6.3, streak detection is handled by evaluate_streak RPC.
 * The awardWearLogPoints method now accepts an optional isStreakDay parameter
 * (pre-computed from evaluate_streak) instead of calling checkStreakDay() internally.
 */

/**
 * @param {object} options
 * @param {object} options.userStatsRepo - User stats repository instance.
 */
export function createStylePointsService({ userStatsRepo }) {
  if (!userStatsRepo) {
    throw new TypeError("userStatsRepo is required");
  }

  return {
    /**
     * Award points for uploading a wardrobe item.
     * Always awards 10 points.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} { pointsAwarded, totalPoints, action }
     */
    async awardItemUploadPoints(authContext) {
      const result = await userStatsRepo.awardPoints(authContext, { points: 10 });
      return {
        pointsAwarded: 10,
        totalPoints: result.totalPoints,
        action: "item_upload",
      };
    },

    /**
     * Award points for logging a wear log.
     * Base: 5 points. Bonuses: +2 first log of day, +3 streak day.
     *
     * After Story 6.3, isStreakDay can be passed as an option (pre-computed
     * from evaluate_streak) to avoid double streak detection.
     * If not provided, falls back to checkStreakDay() for backward compatibility.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} [options]
     * @param {boolean} [options.isStreakDay] - Pre-computed streak day flag from evaluate_streak.
     * @returns {Promise<object>} { pointsAwarded, totalPoints, currentStreak, bonuses, action }
     */
    async awardWearLogPoints(authContext, { isStreakDay } = {}) {
      const isFirstLogToday = await userStatsRepo.checkFirstLogToday(authContext);

      // Use pre-computed isStreakDay if provided, otherwise fall back to checkStreakDay
      const streakDay = isStreakDay !== undefined
        ? isStreakDay
        : await userStatsRepo.checkStreakDay(authContext);

      const result = await userStatsRepo.awardPointsWithStreak(authContext, {
        basePoints: 5,
        isFirstLogToday,
        isStreakDay: streakDay,
      });

      return {
        pointsAwarded: result.pointsAwarded,
        totalPoints: result.totalPoints,
        currentStreak: result.currentStreak,
        bonuses: {
          firstLogOfDay: isFirstLogToday ? 2 : 0,
          streakDay: streakDay ? 3 : 0,
        },
        action: "wear_log",
      };
    },
  };
}
