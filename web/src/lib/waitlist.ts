import { z } from 'astro/zod';

export const waitlistEntryLimits = {
	emailMaxLength: 320,
} as const;

export const waitlistFieldAttributes = {
	email: {
		maxLength: waitlistEntryLimits.emailMaxLength,
	},
} as const;

export const waitlistStatusMessages = {
	submitted: 'Thanks — you’re on the waitlist.',
	alreadyJoined: 'You’re already on the waitlist.',
	error: 'Something went wrong while joining the waitlist. Please try again.',
	invalid: 'Please enter a valid email address.',
} as const;

export const waitlistRequestInput = z.object({
	email: z.preprocess(
		(value) => (typeof value === 'string' ? value.trim().toLowerCase() : value),
		z.string().max(waitlistEntryLimits.emailMaxLength, 'Email is too long.').pipe(
			z.email(waitlistStatusMessages.invalid),
		),
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

		if (typeof fieldName !== 'string' || fieldName in fieldErrors) {
			continue;
		}

		fieldErrors[fieldName as WaitlistRequestFieldName] = issue.message;
	}

	return fieldErrors;
}

export function validateWaitlistRequest(input: unknown):
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
