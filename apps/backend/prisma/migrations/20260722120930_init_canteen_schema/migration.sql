-- CreateTable
CREATE TABLE "canteens" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "sourceLocationId" INTEGER NOT NULL,
    "displayNameDe" TEXT NOT NULL,
    "displayNameEn" TEXT NOT NULL,
    "campusLabelDe" TEXT NOT NULL,
    "campusLabelEn" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "canteens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meals" (
    "id" TEXT NOT NULL,
    "sourcePlanId" INTEGER NOT NULL,
    "sourceFoodId" INTEGER,
    "canteenId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "counterId" INTEGER,
    "isSprint" BOOLEAN NOT NULL DEFAULT false,
    "name" TEXT NOT NULL,
    "subtitle" TEXT,
    "extras" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "ingredientCodes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "sourceUpdatedAt" TIMESTAMP(3),
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "meals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "meal_prices" (
    "id" TEXT NOT NULL,
    "mealId" TEXT NOT NULL,
    "group" TEXT NOT NULL,
    "amount" DECIMAL(6,2) NOT NULL,

    CONSTRAINT "meal_prices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ingredient_definitions" (
    "code" TEXT NOT NULL,
    "labelDe" TEXT NOT NULL,
    "labelEn" TEXT,
    "kind" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ingredient_definitions_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "sync_runs" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'meine-mensa',
    "canteenId" TEXT,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finishedAt" TIMESTAMP(3),
    "status" TEXT NOT NULL,
    "recordsReceived" INTEGER NOT NULL DEFAULT 0,
    "recordsUpserted" INTEGER NOT NULL DEFAULT 0,
    "recordsRejected" INTEGER NOT NULL DEFAULT 0,
    "errorMessage" TEXT,

    CONSTRAINT "sync_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "canteens_slug_key" ON "canteens"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "canteens_sourceLocationId_key" ON "canteens"("sourceLocationId");

-- CreateIndex
CREATE INDEX "canteens_active_sortOrder_idx" ON "canteens"("active", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "meals_sourcePlanId_key" ON "meals"("sourcePlanId");

-- CreateIndex
CREATE INDEX "meals_canteenId_date_idx" ON "meals"("canteenId", "date");

-- CreateIndex
CREATE INDEX "meals_date_idx" ON "meals"("date");

-- CreateIndex
CREATE UNIQUE INDEX "meal_prices_mealId_group_key" ON "meal_prices"("mealId", "group");

-- CreateIndex
CREATE INDEX "sync_runs_canteenId_status_startedAt_idx" ON "sync_runs"("canteenId", "status", "startedAt");

-- CreateIndex
CREATE INDEX "sync_runs_status_startedAt_idx" ON "sync_runs"("status", "startedAt");

-- AddForeignKey
ALTER TABLE "meals" ADD CONSTRAINT "meals_canteenId_fkey" FOREIGN KEY ("canteenId") REFERENCES "canteens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "meal_prices" ADD CONSTRAINT "meal_prices_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "meals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_runs" ADD CONSTRAINT "sync_runs_canteenId_fkey" FOREIGN KEY ("canteenId") REFERENCES "canteens"("id") ON DELETE SET NULL ON UPDATE CASCADE;
