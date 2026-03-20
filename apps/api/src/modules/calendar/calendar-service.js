/**
 * Calendar service orchestrating event sync, classification, and cleanup.
 *
 * Accepts raw device events, classifies them, persists via repository,
 * and cleans up stale entries.
 */

/**
 * @param {object} options
 * @param {object} options.calendarEventRepo - Calendar event repository.
 * @param {object} options.classificationService - Event classification service.
 */
export function createCalendarService({ calendarEventRepo, classificationService }) {
  return {
    /**
     * Sync a batch of device calendar events.
     *
     * Classifies each event, upserts them, and marks stale events for each
     * unique source calendar in the batch.
     *
     * @param {object} authContext - Auth context with userId.
     * @param {object} params
     * @param {Array<object>} params.events - Raw device events.
     * @returns {Promise<{ synced: number, classified: number }>}
     */
    async syncEvents(authContext, { events }) {
      if (!events || events.length === 0) {
        return { synced: 0, classified: 0 };
      }

      // Step 1: Classify each event
      const classifiedEvents = [];
      for (const event of events) {
        const classification = await classificationService.classifyEvent(authContext, {
          title: event.title,
          description: event.description,
          location: event.location,
          startTime: event.startTime
        });

        classifiedEvents.push({
          sourceCalendarId: event.sourceCalendarId,
          sourceEventId: event.sourceEventId,
          title: event.title,
          description: event.description ?? null,
          location: event.location ?? null,
          startTime: event.startTime,
          endTime: event.endTime,
          allDay: event.allDay ?? false,
          eventType: classification.eventType,
          formalityScore: classification.formalityScore,
          classificationSource: classification.classificationSource
        });
      }

      // Step 2: Upsert all classified events
      await calendarEventRepo.upsertEvents(authContext, classifiedEvents);

      // Step 3: Mark stale events per calendar
      // Group events by sourceCalendarId to determine date range and IDs per calendar
      const calendarGroups = {};
      for (const event of classifiedEvents) {
        if (!calendarGroups[event.sourceCalendarId]) {
          calendarGroups[event.sourceCalendarId] = {
            sourceEventIds: [],
            startDates: [],
            endDates: []
          };
        }
        calendarGroups[event.sourceCalendarId].sourceEventIds.push(event.sourceEventId);
        calendarGroups[event.sourceCalendarId].startDates.push(new Date(event.startTime));
        calendarGroups[event.sourceCalendarId].endDates.push(new Date(event.endTime));
      }

      for (const [calendarId, group] of Object.entries(calendarGroups)) {
        const minStart = new Date(Math.min(...group.startDates.map(d => d.getTime())));
        const maxEnd = new Date(Math.max(...group.endDates.map(d => d.getTime())));

        await calendarEventRepo.markStaleEvents(authContext, {
          sourceCalendarId: calendarId,
          sourceEventIds: group.sourceEventIds,
          startDate: minStart.toISOString().split("T")[0],
          endDate: maxEnd.toISOString().split("T")[0]
        });
      }

      return {
        synced: classifiedEvents.length,
        classified: classifiedEvents.length
      };
    }
  };
}
