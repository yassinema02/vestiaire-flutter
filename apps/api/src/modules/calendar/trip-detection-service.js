/**
 * Trip detection service.
 *
 * Detects multi-day trips from calendar events using heuristics:
 * 1. Multi-day events (spanning 2+ days)
 * 2. Location clusters (multiple events in same non-home location within 7 days)
 * 3. Keyword detection (travel-related words in title/description)
 *
 * Also provides geocoding and destination weather via Open-Meteo APIs.
 */

const TRAVEL_KEYWORDS = [
  "flight",
  "hotel",
  "airbnb",
  "conference",
  "vacation",
  "trip",
  "travel",
  "check-in",
  "checkout",
  "boarding",
];

const GEOCODING_TIMEOUT_MS = 5000;

/**
 * Generate a deterministic trip ID from destination + dates.
 * @param {string} destination
 * @param {string} startDate - YYYY-MM-DD
 * @param {string} endDate - YYYY-MM-DD
 * @returns {string}
 */
function generateTripId(destination, startDate, endDate) {
  const normalized = (destination || "unknown").toLowerCase().replace(/\s+/g, "_");
  return `trip_${normalized}_${startDate}_${endDate}`;
}

/**
 * Calculate the number of calendar days between two dates (inclusive).
 * @param {Date} start
 * @param {Date} end
 * @returns {number}
 */
function daysBetween(start, end) {
  const msPerDay = 86400000;
  const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
  const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
  return Math.round((endDay - startDay) / msPerDay);
}

/**
 * Normalize a location string for comparison.
 * @param {string|null} location
 * @returns {string}
 */
function normalizeLocation(location) {
  if (!location) return "";
  return location.toLowerCase().trim();
}

/**
 * Check if an event title or description contains travel keywords.
 * @param {object} event
 * @returns {boolean}
 */
function hasKeywordMatch(event) {
  const text = `${event.title || ""} ${event.description || ""}`.toLowerCase();
  return TRAVEL_KEYWORDS.some((kw) => text.includes(kw));
}

/**
 * Merge overlapping trip candidates by date range.
 * @param {Array<object>} candidates - Array of { destination, startDate, endDate, eventIds }
 * @returns {Array<object>}
 */
function mergeOverlappingTrips(candidates) {
  if (candidates.length === 0) return [];

  // Sort by startDate
  const sorted = [...candidates].sort(
    (a, b) => new Date(a.startDate) - new Date(b.startDate)
  );

  const merged = [{ ...sorted[0] }];

  for (let i = 1; i < sorted.length; i++) {
    const current = sorted[i];
    const last = merged[merged.length - 1];

    const lastEnd = new Date(last.endDate);
    const currentStart = new Date(current.startDate);

    // Overlap if current starts within or adjacent to last
    if (currentStart <= new Date(lastEnd.getTime() + 86400000)) {
      // Merge: extend end date if needed
      if (new Date(current.endDate) > lastEnd) {
        last.endDate = current.endDate;
      }
      // Merge event IDs
      last.eventIds = [...new Set([...last.eventIds, ...current.eventIds])];
      // Keep the more specific destination (longer string)
      if ((current.destination || "").length > (last.destination || "").length) {
        last.destination = current.destination;
      }
    } else {
      merged.push({ ...current });
    }
  }

  return merged;
}

/**
 * @param {object} options
 * @param {object} options.calendarEventRepo - Calendar event repository.
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createTripDetectionService({ calendarEventRepo, pool }) {
  if (!calendarEventRepo) {
    throw new TypeError("calendarEventRepo is required");
  }

  return {
    /**
     * Detect upcoming trips from calendar events.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} [options]
     * @param {number} [options.lookaheadDays=14] - Number of days to look ahead.
     * @returns {Promise<Array<object>>} Detected trips.
     */
    async detectTrips(authContext, { lookaheadDays = 14 } = {}) {
      const today = new Date();
      const todayStr = today.toISOString().split("T")[0];
      const endDate = new Date(today.getTime() + lookaheadDays * 86400000);
      const endDateStr = endDate.toISOString().split("T")[0];

      // Fetch events in the lookahead window
      const events = await calendarEventRepo.getEventsForDateRange(authContext, {
        startDate: todayStr,
        endDate: endDateStr,
      });

      if (!events || events.length === 0) {
        return [];
      }

      // Infer home location (most frequent non-empty location)
      const locationCounts = {};
      for (const event of events) {
        const loc = normalizeLocation(event.location);
        if (loc) {
          locationCounts[loc] = (locationCounts[loc] || 0) + 1;
        }
      }
      let homeLocation = "";
      let maxCount = 0;
      for (const [loc, count] of Object.entries(locationCounts)) {
        if (count > maxCount) {
          maxCount = count;
          homeLocation = loc;
        }
      }

      const candidates = [];

      // Heuristic 1: Multi-day events (2+ days)
      for (const event of events) {
        const start = new Date(event.start_time);
        const end = new Date(event.end_time);
        const days = daysBetween(start, end);

        if (days >= 2 || (event.all_day && days >= 2)) {
          const startStr = start.toISOString().split("T")[0];
          const endStr = end.toISOString().split("T")[0];
          candidates.push({
            destination: event.location || event.title || "Unknown",
            startDate: startStr,
            endDate: endStr,
            eventIds: [event.id],
          });
        }
      }

      // Heuristic 2: Location clusters
      const locationGroups = {};
      for (const event of events) {
        const loc = normalizeLocation(event.location);
        if (!loc || loc === homeLocation) continue;

        if (!locationGroups[loc]) {
          locationGroups[loc] = [];
        }
        locationGroups[loc].push(event);
      }

      for (const [loc, groupEvents] of Object.entries(locationGroups)) {
        if (groupEvents.length < 2) continue;

        // Check if events are within a 7-day window
        const sorted = [...groupEvents].sort(
          (a, b) => new Date(a.start_time) - new Date(b.start_time)
        );
        const firstDate = new Date(sorted[0].start_time);
        const lastDate = new Date(sorted[sorted.length - 1].start_time);

        if (daysBetween(firstDate, lastDate) <= 7) {
          const startStr = firstDate.toISOString().split("T")[0];
          const lastEnd = new Date(sorted[sorted.length - 1].end_time || sorted[sorted.length - 1].start_time);
          const endStr = lastEnd.toISOString().split("T")[0];

          // Use the original (non-normalized) location from first event
          candidates.push({
            destination: sorted[0].location || loc,
            startDate: startStr,
            endDate: endStr === startStr
              ? new Date(lastEnd.getTime() + 86400000).toISOString().split("T")[0]
              : endStr,
            eventIds: sorted.map((e) => e.id),
          });
        }
      }

      // Heuristic 3: Keyword detection
      const keywordEvents = events.filter(
        (e) => hasKeywordMatch(e) && !candidates.some((c) => c.eventIds.includes(e.id))
      );

      if (keywordEvents.length > 0) {
        // Cluster keyword events by date proximity (within 3 days)
        const sorted = [...keywordEvents].sort(
          (a, b) => new Date(a.start_time) - new Date(b.start_time)
        );

        let cluster = [sorted[0]];
        for (let i = 1; i < sorted.length; i++) {
          const prevDate = new Date(sorted[i - 1].start_time);
          const currDate = new Date(sorted[i].start_time);
          if (daysBetween(prevDate, currDate) <= 3) {
            cluster.push(sorted[i]);
          } else {
            // Emit current cluster if it has events
            if (cluster.length > 0) {
              const clusterStart = new Date(cluster[0].start_time);
              const clusterEnd = new Date(cluster[cluster.length - 1].end_time || cluster[cluster.length - 1].start_time);
              const startStr = clusterStart.toISOString().split("T")[0];
              const endStr = clusterEnd.toISOString().split("T")[0];
              candidates.push({
                destination: cluster[0].location || cluster[0].title || "Trip",
                startDate: startStr,
                endDate: endStr === startStr
                  ? new Date(clusterEnd.getTime() + 86400000).toISOString().split("T")[0]
                  : endStr,
                eventIds: cluster.map((e) => e.id),
              });
            }
            cluster = [sorted[i]];
          }
        }
        // Emit last cluster
        if (cluster.length > 0) {
          const clusterStart = new Date(cluster[0].start_time);
          const clusterEnd = new Date(cluster[cluster.length - 1].end_time || cluster[cluster.length - 1].start_time);
          const startStr = clusterStart.toISOString().split("T")[0];
          const endStr = clusterEnd.toISOString().split("T")[0];
          candidates.push({
            destination: cluster[0].location || cluster[0].title || "Trip",
            startDate: startStr,
            endDate: endStr === startStr
              ? new Date(clusterEnd.getTime() + 86400000).toISOString().split("T")[0]
              : endStr,
            eventIds: cluster.map((e) => e.id),
          });
        }
      }

      // Merge overlapping candidates
      const merged = mergeOverlappingTrips(candidates);

      // Build final trip objects with geocoding
      const trips = [];
      for (const candidate of merged) {
        const startDate = candidate.startDate;
        const endDate = candidate.endDate;
        const durationDays = daysBetween(new Date(startDate), new Date(endDate));

        let destinationCoordinates = null;
        try {
          destinationCoordinates = await this.geocodeLocation(candidate.destination);
        } catch (_) {
          // Geocoding failure is non-fatal
        }

        trips.push({
          id: generateTripId(candidate.destination, startDate, endDate),
          destination: candidate.destination,
          startDate,
          endDate,
          durationDays: Math.max(durationDays, 1),
          eventIds: candidate.eventIds,
          destinationCoordinates,
        });
      }

      return trips;
    },

    /**
     * Geocode a location string to coordinates using Open-Meteo geocoding API.
     *
     * @param {string} locationString - Location to geocode.
     * @returns {Promise<{ latitude: number, longitude: number } | null>}
     */
    async geocodeLocation(locationString) {
      if (!locationString || !locationString.trim()) {
        return null;
      }

      try {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(locationString)}&count=1&language=en`;
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), GEOCODING_TIMEOUT_MS);

        try {
          const response = await fetch(url, { signal: controller.signal });
          clearTimeout(timeout);

          if (!response.ok) {
            return null;
          }

          const data = await response.json();
          if (!data.results || data.results.length === 0) {
            return null;
          }

          const result = data.results[0];
          return {
            latitude: result.latitude,
            longitude: result.longitude,
          };
        } catch (err) {
          clearTimeout(timeout);
          return null;
        }
      } catch (_) {
        return null;
      }
    },

    /**
     * Fetch destination weather forecast from Open-Meteo.
     *
     * @param {number} latitude
     * @param {number} longitude
     * @param {string} startDate - YYYY-MM-DD
     * @param {string} endDate - YYYY-MM-DD
     * @returns {Promise<Array<{ date: string, highTemp: number, lowTemp: number, weatherCode: number }> | null>}
     */
    async fetchDestinationWeather(latitude, longitude, startDate, endDate) {
      try {
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&daily=temperature_2m_max,temperature_2m_min,weather_code&start_date=${startDate}&end_date=${endDate}&timezone=auto`;

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), GEOCODING_TIMEOUT_MS);

        try {
          const response = await fetch(url, { signal: controller.signal });
          clearTimeout(timeout);

          if (!response.ok) {
            return null;
          }

          const data = await response.json();
          if (!data.daily || !data.daily.time) {
            return null;
          }

          const forecasts = [];
          for (let i = 0; i < data.daily.time.length; i++) {
            forecasts.push({
              date: data.daily.time[i],
              highTemp: data.daily.temperature_2m_max[i],
              lowTemp: data.daily.temperature_2m_min[i],
              weatherCode: data.daily.weather_code[i],
            });
          }

          return forecasts;
        } catch (err) {
          clearTimeout(timeout);
          return null;
        }
      } catch (_) {
        return null;
      }
    },
  };
}

// Export helpers for testing
export {
  generateTripId,
  daysBetween,
  normalizeLocation,
  hasKeywordMatch,
  mergeOverlappingTrips,
  TRAVEL_KEYWORDS,
};
