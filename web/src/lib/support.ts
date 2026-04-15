import { z } from 'astro/zod';

export const supportRequestLimits = {
	nameMinLength: 2,
	nameMaxLength: 80,
	emailMaxLength: 320,
	messageMinLength: 10,
	messageMaxLength: 2000,
} as const;

export const supportFieldAttributes = {
	name: {
		minLength: supportRequestLimits.nameMinLength,
		maxLength: supportRequestLimits.nameMaxLength,
	},
	email: {
		maxLength: supportRequestLimits.emailMaxLength,
	},
	message: {
		minLength: supportRequestLimits.messageMinLength,
		maxLength: supportRequestLimits.messageMaxLength,
	},
} as const;

export const supportStatusMessages = {
	submitted: 'Thanks — your support request was received.',
	error: 'Something went wrong while sending your request. Please try again.',
	invalid: 'Please review your form and try again.',
} as const;

export const supportStatusQueryKey = 'status';

export const supportRequestInput = z.object({
	name: z
		.string()
		.trim()
		.min(supportRequestLimits.nameMinLength, 'Please enter your name.')
		.max(supportRequestLimits.nameMaxLength, 'Name is too long.'),
	email: z
		.email('Please enter a valid email address.')
		.max(supportRequestLimits.emailMaxLength, 'Email is too long.'),
	message: z
		.string()
		.trim()
		.min(supportRequestLimits.messageMinLength, 'Please share a few more details.')
		.max(supportRequestLimits.messageMaxLength, 'Message is too long.'),
});

export type SupportRequestInput = z.infer<typeof supportRequestInput>;
export type SupportRequestFieldName = keyof SupportRequestInput;
export type SupportRequestFieldErrors = Partial<Record<SupportRequestFieldName, string>>;
export type SupportPageStatus = keyof typeof supportStatusMessages;

function collectSupportRequestFieldErrors(
	issues: Array<{ path: PropertyKey[]; message: string }>,
): SupportRequestFieldErrors {
	const fieldErrors: SupportRequestFieldErrors = {};

	for (const issue of issues) {
		const fieldName = issue.path[0];

		if (typeof fieldName !== 'string' || fieldName in fieldErrors) {
			continue;
		}

		fieldErrors[fieldName as SupportRequestFieldName] = issue.message;
	}

	return fieldErrors;
}

export function validateSupportRequest(input: unknown):
	| { success: true; data: SupportRequestInput }
	| {
			success: false;
			message: string;
			fieldErrors: SupportRequestFieldErrors;
	  } {
	const parsed = supportRequestInput.safeParse(input);

	if (parsed.success) {
		return parsed;
	}

	const fieldErrors = collectSupportRequestFieldErrors(parsed.error.issues);
	const message =
		Object.values(fieldErrors).find((value) => value !== undefined) ??
		supportStatusMessages.invalid;

	return {
		success: false,
		message,
		fieldErrors,
	};
}

export function getSupportPageStatus(searchParams: URLSearchParams): SupportPageStatus | null {
	const status = searchParams.get(supportStatusQueryKey);

	if (status === 'submitted' || status === 'error' || status === 'invalid') {
		return status;
	}

	return null;
}

export function getSupportStatusMessage(status: SupportPageStatus): string {
	return supportStatusMessages[status];
}

export function getSupportRedirectPath(status: SupportPageStatus): string {
	const searchParams = new URLSearchParams({
		[supportStatusQueryKey]: status,
	});

	return `/support?${searchParams.toString()}`;
}
