import { z } from 'zod';
import type { ParsedRequestBody } from './json';
import {
	getWaitlistEmailValidationMessage,
	normalizeWaitlistEmail,
	waitlistEntryLimits,
	waitlistStatusMessages,
} from './waitlist-validation';

export {
	getWaitlistEmailValidationMessage,
	normalizeWaitlistEmail,
	waitlistEntryLimits,
	waitlistFieldAttributes,
	waitlistStatusMessages,
} from './waitlist-validation';

export const waitlistRequestInput = z.object({
	email: z.preprocess(
		(value) => {
			const parsed = z.string().safeParse(value);

			return parsed.success ? normalizeWaitlistEmail(parsed.data) : value;
		},
		z
			.string()
			.max(waitlistEntryLimits.emailMaxLength, 'Email is too long.')
			.superRefine((value, ctx) => {
				const message = getWaitlistEmailValidationMessage(value);

				if (!message) {
					return;
				}

				ctx.addIssue({
					code: 'custom',
					message,
				});
			}),
	),
});

export type WaitlistRequestInput = z.infer<typeof waitlistRequestInput>;

export type WaitlistRequestFieldName = keyof WaitlistRequestInput;

export type WaitlistRequestFieldErrors = Partial<Record<WaitlistRequestFieldName, string>>;

function collectWaitlistFieldErrors(
	issues: Array<{ path: PropertyKey[]; message: string }>,
): WaitlistRequestFieldErrors {
	const fieldErrors: WaitlistRequestFieldErrors = {};

	for (const issue of issues) {
		const fieldName = issue.path[0];

		if (!isWaitlistRequestFieldName(fieldName) || fieldName in fieldErrors) {
			continue;
		}

		fieldErrors[fieldName] = issue.message;
	}

	return fieldErrors;
}

function isWaitlistRequestFieldName(value: PropertyKey | undefined): value is WaitlistRequestFieldName {
	return value != null && Object.hasOwn(waitlistRequestInput.shape, value);
}

export function validateWaitlistRequest(input: ParsedRequestBody):
	| { success: true; data: WaitlistRequestInput }
	| {
			success: false;
			message: string;
			fieldErrors: WaitlistRequestFieldErrors;
	  } {
	const parsed = waitlistRequestInput.safeParse(input);

	if (parsed.success) {
		return parsed;
	}

	const fieldErrors = collectWaitlistFieldErrors(parsed.error.issues);

	const message =
		Object.values(fieldErrors).find((value) => value !== undefined) ??
		waitlistStatusMessages.invalid;

	return {
		success: false,
		message,
		fieldErrors,
	};
}
