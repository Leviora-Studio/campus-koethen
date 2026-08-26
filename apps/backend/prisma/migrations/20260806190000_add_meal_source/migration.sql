-- Keep real meine-mensa imports isolated from the explicitly enabled,
-- synthetic user-test seed. Existing rows all came from meine-mensa.
ALTER TABLE "meals"
ADD COLUMN "source" TEXT NOT NULL DEFAULT 'meine-mensa';

CREATE INDEX "meals_source_canteenId_date_idx"
ON "meals"("source", "canteenId", "date");
