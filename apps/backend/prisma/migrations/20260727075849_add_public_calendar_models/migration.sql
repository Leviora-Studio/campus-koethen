-- CreateTable
CREATE TABLE "public_calendars" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "googleCalendarId" TEXT NOT NULL,
    "nameDe" TEXT NOT NULL,
    "nameEn" TEXT,
    "descriptionDe" TEXT,
    "descriptionEn" TEXT,
    "colorHex" TEXT NOT NULL,
    "iconKey" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "defaultSubscribed" BOOLEAN NOT NULL DEFAULT false,
    "attributionDe" TEXT,
    "attributionEn" TEXT,
    "showDescription" BOOLEAN NOT NULL DEFAULT false,
    "showLocation" BOOLEAN NOT NULL DEFAULT false,
    "fallbackTimeZone" TEXT NOT NULL DEFAULT 'Europe/Berlin',
    "operationalStatus" TEXT NOT NULL DEFAULT 'pending',
    "lastEtag" TEXT,
    "lastModified" TEXT,
    "lastContentHash" TEXT,
    "lastCatalogSyncAt" TIMESTAMP(3),
    "lastSuccessfulSyncAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "public_calendars_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public_calendar_events" (
    "id" TEXT NOT NULL,
    "calendarId" TEXT NOT NULL,
    "occurrenceKey" TEXT NOT NULL,
    "uid" TEXT NOT NULL,
    "recurrenceId" TEXT,
    "sequence" INTEGER,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "location" TEXT,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "allDay" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'confirmed',
    "sourceUpdatedAt" TIMESTAMP(3),
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "public_calendar_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public_calendar_sync_runs" (
    "id" TEXT NOT NULL,
    "calendarSlug" TEXT,
    "kind" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "rangeFrom" DATE,
    "rangeTo" DATE,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),
    "feedBytes" INTEGER NOT NULL DEFAULT 0,
    "calendarComponentsReceived" INTEGER NOT NULL DEFAULT 0,
    "eventsReceived" INTEGER NOT NULL DEFAULT 0,
    "eventsExpanded" INTEGER NOT NULL DEFAULT 0,
    "recordsAccepted" INTEGER NOT NULL DEFAULT 0,
    "recordsRejected" INTEGER NOT NULL DEFAULT 0,
    "recordsWritten" INTEGER NOT NULL DEFAULT 0,
    "recordsRemoved" INTEGER NOT NULL DEFAULT 0,
    "errorCode" TEXT,
    "errorMessage" TEXT,

    CONSTRAINT "public_calendar_sync_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "public_calendars_slug_key" ON "public_calendars"("slug");

-- CreateIndex
CREATE INDEX "public_calendars_isActive_sortOrder_idx" ON "public_calendars"("isActive", "sortOrder");

-- CreateIndex
CREATE INDEX "public_calendars_operationalStatus_idx" ON "public_calendars"("operationalStatus");

-- CreateIndex
CREATE INDEX "public_calendar_events_calendarId_startsAt_idx" ON "public_calendar_events"("calendarId", "startsAt");

-- CreateIndex
CREATE INDEX "public_calendar_events_startsAt_idx" ON "public_calendar_events"("startsAt");

-- CreateIndex
CREATE UNIQUE INDEX "public_calendar_events_calendarId_occurrenceKey_key" ON "public_calendar_events"("calendarId", "occurrenceKey");

-- CreateIndex
CREATE INDEX "public_calendar_sync_runs_kind_status_startedAt_idx" ON "public_calendar_sync_runs"("kind", "status", "startedAt");

-- CreateIndex
CREATE INDEX "public_calendar_sync_runs_status_startedAt_idx" ON "public_calendar_sync_runs"("status", "startedAt");

-- AddForeignKey
ALTER TABLE "public_calendar_events" ADD CONSTRAINT "public_calendar_events_calendarId_fkey" FOREIGN KEY ("calendarId") REFERENCES "public_calendars"("id") ON DELETE CASCADE ON UPDATE CASCADE;
