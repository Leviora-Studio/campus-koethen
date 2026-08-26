-- Public-calendar presentation metadata is no longer editorially configurable.
ALTER TABLE "public_calendars"
  DROP COLUMN "descriptionDe",
  DROP COLUMN "descriptionEn",
  DROP COLUMN "iconKey",
  DROP COLUMN "attributionDe",
  DROP COLUMN "attributionEn",
  DROP COLUMN "fallbackTimeZone";

ALTER TABLE "public_calendars"
  RENAME COLUMN "showDescription" TO "includeEventDescription";

ALTER TABLE "public_calendars"
  RENAME COLUMN "showLocation" TO "includeEventLocation";
