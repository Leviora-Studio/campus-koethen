-- CreateTable
CREATE TABLE "timetable_contexts" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'webuntis',
    "externalId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "validFrom" DATE NOT NULL,
    "validTo" DATE NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "timetable_contexts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "timetable_groups" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'webuntis',
    "externalId" TEXT NOT NULL,
    "shortName" TEXT NOT NULL,
    "longName" TEXT NOT NULL,
    "department" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "timetable_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "timetable_entries" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'webuntis',
    "externalKey" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "subjectCode" TEXT,
    "type" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "sourceStatus" TEXT,
    "teachers" JSONB NOT NULL DEFAULT '[]',
    "rooms" JSONB NOT NULL DEFAULT '[]',
    "note" TEXT,
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "timetable_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "timetable_entry_groups" (
    "entryId" TEXT NOT NULL,
    "groupId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "timetable_entry_groups_pkey" PRIMARY KEY ("entryId","groupId")
);

-- CreateTable
CREATE TABLE "timetable_sync_runs" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'webuntis',
    "kind" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),
    "status" TEXT NOT NULL,
    "rangeFrom" DATE,
    "rangeTo" DATE,
    "groupsRequested" INTEGER NOT NULL DEFAULT 0,
    "recordsReceived" INTEGER NOT NULL DEFAULT 0,
    "recordsAccepted" INTEGER NOT NULL DEFAULT 0,
    "recordsRejected" INTEGER NOT NULL DEFAULT 0,
    "recordsWritten" INTEGER NOT NULL DEFAULT 0,
    "recordsRemoved" INTEGER NOT NULL DEFAULT 0,
    "errorCode" TEXT,
    "errorMessage" TEXT,

    CONSTRAINT "timetable_sync_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "timetable_contexts_source_active_idx" ON "timetable_contexts"("source", "active");

-- CreateIndex
CREATE UNIQUE INDEX "timetable_contexts_source_externalId_key" ON "timetable_contexts"("source", "externalId");

-- CreateIndex
CREATE INDEX "timetable_groups_active_shortName_idx" ON "timetable_groups"("active", "shortName");

-- CreateIndex
CREATE INDEX "timetable_groups_department_idx" ON "timetable_groups"("department");

-- CreateIndex
CREATE UNIQUE INDEX "timetable_groups_source_externalId_key" ON "timetable_groups"("source", "externalId");

-- CreateIndex
CREATE INDEX "timetable_entries_date_idx" ON "timetable_entries"("date");

-- CreateIndex
CREATE INDEX "timetable_entries_startsAt_idx" ON "timetable_entries"("startsAt");

-- CreateIndex
CREATE UNIQUE INDEX "timetable_entries_source_externalKey_key" ON "timetable_entries"("source", "externalKey");

-- CreateIndex
CREATE INDEX "timetable_entry_groups_groupId_idx" ON "timetable_entry_groups"("groupId");

-- CreateIndex
CREATE INDEX "timetable_sync_runs_kind_status_startedAt_idx" ON "timetable_sync_runs"("kind", "status", "startedAt");

-- CreateIndex
CREATE INDEX "timetable_sync_runs_status_startedAt_idx" ON "timetable_sync_runs"("status", "startedAt");

-- AddForeignKey
ALTER TABLE "timetable_entry_groups" ADD CONSTRAINT "timetable_entry_groups_entryId_fkey" FOREIGN KEY ("entryId") REFERENCES "timetable_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "timetable_entry_groups" ADD CONSTRAINT "timetable_entry_groups_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "timetable_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
