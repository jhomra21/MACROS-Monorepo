import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const editorialSchema = ({ image }: { image: () => z.ZodType<ImageMetadata> }) =>
	z.object({
		title: z.string().max(60),
		description: z.string().max(160),
		published: z.coerce.date(),
		updated: z.coerce.date(),
		draft: z.boolean(),
		image: image(),
		imageAlt: z.string(),
		imageCaption: z.string().optional(),
		// Entries to link under "Related", written as "guides/<id>" or "blog/<id>". Drafts are skipped.
		related: z.array(z.string().regex(/^(guides|blog)\/[a-z0-9-]+$/)).max(4).optional(),
	}).refine(data => data.updated >= data.published, 'Updated must not precede published');

export const collections = {
	guides: defineCollection({
		loader: glob({ pattern: '**/*.md', base: './src/content/guides' }),
		schema: editorialSchema,
	}),
	blog: defineCollection({
		loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
		schema: editorialSchema,
	}),
};
