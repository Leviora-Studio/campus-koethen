CREATE TABLE "post_reactions" (
    "postSlug" VARCHAR(100) NOT NULL,
    "installation" CHAR(64) NOT NULL,
    "emoji" VARCHAR(64) NOT NULL,
    CONSTRAINT "post_reactions_pkey" PRIMARY KEY ("postSlug", "installation")
);

CREATE TABLE "post_poll_votes" (
    "postSlug" VARCHAR(100) NOT NULL,
    "pollKey" VARCHAR(60) NOT NULL,
    "installation" CHAR(64) NOT NULL,
    "optionKey" VARCHAR(60) NOT NULL,
    CONSTRAINT "post_poll_votes_pkey" PRIMARY KEY ("postSlug", "pollKey", "installation")
);
