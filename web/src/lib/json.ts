// zod/mini is tree-shakable; these schemas ship to the browser with the form scripts.
import * as z from 'zod/mini';

export const jsonValueSchema = z.json();

export type JsonValue = z.infer<typeof jsonValueSchema>;

export type ParsedRequestBody = JsonValue | Record<string, FormDataEntryValue> | null;

export const jsonObjectSchema = z.record(z.string(), jsonValueSchema);

export type JsonObject = z.infer<typeof jsonObjectSchema>;

export const formResponseSchema = z.object({
	message: z.optional(z.string()),
	fieldErrors: z.optional(z.record(z.string(), jsonValueSchema)),
});

export type FormResponse = z.infer<typeof formResponseSchema>;

export const stringValueSchema = z.string();
