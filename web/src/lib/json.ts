import { z } from 'zod';

export const jsonValueSchema = z.json();

export type JsonValue = z.infer<typeof jsonValueSchema>;

export type ParsedRequestBody = JsonValue | Record<string, FormDataEntryValue> | null;

export const jsonObjectSchema = z.record(z.string(), jsonValueSchema);

export type JsonObject = z.infer<typeof jsonObjectSchema>;

export const formResponseSchema = z.object({
	message: z.string().optional(),
	fieldErrors: z.record(z.string(), jsonValueSchema).optional(),
});

export type FormResponse = z.infer<typeof formResponseSchema>;

export const stringValueSchema = z.string();
