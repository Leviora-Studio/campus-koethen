-- CreateIndex
CREATE INDEX "public_calendar_sync_runs_kind_status_finishedAt_idx" ON "public_calendar_sync_runs"("kind", "status", "finishedAt");

-- CreateIndex
CREATE INDEX "sync_runs_canteenId_status_finishedAt_idx" ON "sync_runs"("canteenId", "status", "finishedAt");

-- CreateIndex
CREATE INDEX "timetable_sync_runs_kind_status_finishedAt_idx" ON "timetable_sync_runs"("kind", "status", "finishedAt");
