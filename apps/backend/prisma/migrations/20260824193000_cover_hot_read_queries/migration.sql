-- Replace the narrower indexes with covering variants that match the hot API
-- query order. Keeping the same index count avoids extra write amplification.

-- Timetable reads start from one group and immediately need each entry id for
-- the join. Including entryId lets PostgreSQL satisfy that lookup from the
-- index instead of visiting every join-table heap row.
CREATE INDEX "timetable_entry_groups_groupId_entryId_idx"
ON "timetable_entry_groups"("groupId", "entryId");
DROP INDEX "timetable_entry_groups_groupId_idx";

-- Event endpoints filter and order by these exact prefixes, then use id as the
-- deterministic tie-breaker for the bounded LIMIT query.
CREATE INDEX "public_calendar_events_calendarId_startsAt_id_idx"
ON "public_calendar_events"("calendarId", "startsAt", "id");
DROP INDEX "public_calendar_events_calendarId_startsAt_idx";

CREATE INDEX "public_calendar_events_startsAt_calendarId_id_idx"
ON "public_calendar_events"("startsAt", "calendarId", "id");
DROP INDEX "public_calendar_events_startsAt_idx";
