// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';
import { ContentBlock } from '../../common/content/content-blocks';

/**
 * Public shapes returned by /v1/posts*.
 *
 * These are classes rather than interfaces so the generated OpenAPI document
 * carries real response schemas — an interface is erased at compile time and
 * would leave the published contract without any payload description.
 *
 * Strapi's `documentId`, `localizations` and `formats` stop at the mapper and
 * never appear here.
 */

export class ImageDto {
  @ApiProperty({ example: 'https://cdn.example/hero.jpg', description: 'Always https.' })
  url!: string;

  @ApiProperty({ type: String, nullable: true })
  alternativeText!: string | null;

  @ApiProperty({ type: Number, nullable: true })
  width!: number | null;

  @ApiProperty({ type: Number, nullable: true })
  height!: number | null;
}

export class ChannelDto {
  @ApiProperty({ example: 'campus-news', description: 'Stable, never localised.' })
  slug!: string;

  @ApiProperty({ example: 'Campus News' })
  name!: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  description!: string | null;

  @ApiProperty({ example: '#5B3FD0', pattern: '^#[0-9A-Fa-f]{6}$' })
  colorHex!: string;

  @ApiProperty({ example: 10 })
  sortOrder!: number;

  @ApiProperty({
    description: 'Applied by the client exactly once, when the slug first appears.',
  })
  defaultSubscribed!: boolean;

  @ApiPropertyOptional({
    type: String,
    nullable: true,
    description: 'Slug of the associated public Google calendar, if linked 1-to-1.',
  })
  publicCalendarSlug!: string | null;
}

export class ChannelRefDto {
  @ApiProperty() slug!: string;
  @ApiProperty() name!: string;
  @ApiProperty() colorHex!: string;
}

export class TagDto {
  @ApiProperty({ example: 'event', description: 'Stable, never localised.' })
  slug!: string;

  @ApiProperty({ example: 'Event' })
  name!: string;
}

export class TagRefDto {
  @ApiProperty() slug!: string;
  @ApiProperty() name!: string;
}

export class PostListItemDto {
  @ApiProperty({ example: 'semesterstart-2026' }) slug!: string;
  @ApiProperty() title!: string;

  @ApiPropertyOptional({ type: String, nullable: true, format: 'date-time' })
  publishedAt!: string | null;

  @ApiPropertyOptional({ type: ImageDto, nullable: true })
  heroImage!: ImageDto | null;

  @ApiProperty({ type: TagRefDto, description: 'Mandatory single tag classification.' })
  tag!: TagRefDto;

  @ApiProperty({ type: ChannelRefDto, description: 'Mandatory primary publishing channel.' })
  primaryChannel!: ChannelRefDto;

  @ApiProperty({ type: [ChannelRefDto], description: 'All channels this post is published to.' })
  channels!: ChannelRefDto[];

  @ApiPropertyOptional({ type: String, nullable: true })
  sourceName!: string | null;

  @ApiPropertyOptional({
    type: String,
    nullable: true,
    description: 'Validated https URL of the original source, or null.',
  })
  sourceUrl!: string | null;

  @ApiProperty({
    type: 'array',
    items: { type: 'object', additionalProperties: true },
    description:
      'Sanitised content blocks, delivered with the LIST entry so a feed can render the post inline without a request per card. Only paragraph, heading, list, quote and image survive; anything else is removed server-side and reported in meta.droppedBlockTypes.',
  })
  content!: ContentBlock[];

  @ApiPropertyOptional({ type: String, nullable: true, format: 'date-time' })
  eventStart!: string | null;

  @ApiPropertyOptional({ type: String, nullable: true, format: 'date-time' })
  eventEnd!: string | null;

  @ApiProperty({ example: false })
  eventAllDay!: boolean;
}

/**
 * Identical to the list entry.
 */
export class PostDetailDto extends PostListItemDto {}

// --- Response envelopes ------------------------------------------------------

export class ChannelsResponseDto {
  @ApiProperty({ type: [ChannelDto] }) data!: ChannelDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class TagsResponseDto {
  @ApiProperty({ type: [TagDto] }) data!: TagDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class PostListResponseDto {
  @ApiProperty({ type: [PostListItemDto] }) data!: PostListItemDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class PostDetailResponseDto {
  @ApiProperty({ type: PostDetailDto }) data!: PostDetailDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
