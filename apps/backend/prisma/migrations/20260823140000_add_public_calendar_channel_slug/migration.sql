-- AlterTable
ALTER TABLE "public_calendars" ADD COLUMN "channelSlug" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "public_calendars_channelSlug_key" ON "public_calendars"("channelSlug");
