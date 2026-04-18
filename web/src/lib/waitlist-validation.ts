import { waitlistKnownTldValues } from './waitlist-tlds';

export const waitlistEntryLimits = {
	emailMaxLength: 320,
} as const;

const waitlistKnownTlds = new Set(
	waitlistKnownTldValues
		.toLowerCase()
		.split(/\s+/)
		.filter((value) => value.length > 0),
);
const waitlistEmailSyntaxRegex =
	/^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z0-9-]{2,63}$/i;

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
	invalidDomain: 'Please use an email address with a real top-level domain like .com or .io.',
} as const;

export function normalizeWaitlistEmail(value: string): string {
	return value.trim().toLowerCase();
}

type ParsedWaitlistEmail = {
	domain: string;
};

function parseWaitlistEmail(value: string): ParsedWaitlistEmail | null {
	const normalizedValue = normalizeWaitlistEmail(value);
	const atIndex = normalizedValue.indexOf('@');

	if (
		!waitlistEmailSyntaxRegex.test(normalizedValue) ||
		atIndex <= 0 ||
		atIndex !== normalizedValue.lastIndexOf('@') ||
		atIndex === normalizedValue.length - 1
	) {
		return null;
	}

	const domain = normalizedValue.slice(atIndex + 1);

	if (!hasValidWaitlistEmailDomainLabels(domain)) {
		return null;
	}

	return { domain };
}

export function hasValidWaitlistEmailSyntax(value: string): boolean {
	return parseWaitlistEmail(value) !== null;
}

function hasValidWaitlistEmailDomainLabels(domain: string): boolean {
	const labels = domain.split('.');

	if (labels.length < 2) {
		return false;
	}

	return labels.every((label) =>
		label.length > 0 &&
		label.length <= 63 &&
		/^[a-z0-9-]+$/i.test(label) &&
		!label.startsWith('-') &&
		!label.endsWith('-'),
	);
}

export function hasValidWaitlistEmailTld(value: string): boolean {
	const parsedEmail = parseWaitlistEmail(value);

	if (!parsedEmail) {
		return false;
	}

	const lastDotIndex = parsedEmail.domain.lastIndexOf('.');

	if (lastDotIndex < 0 || lastDotIndex === parsedEmail.domain.length - 1) {
		return false;
	}

	return waitlistKnownTlds.has(parsedEmail.domain.slice(lastDotIndex + 1).toLowerCase());
}

export function getWaitlistEmailValidationMessage(value: string): string | null {
	if (!hasValidWaitlistEmailSyntax(value)) {
		return waitlistStatusMessages.invalid;
	}

	return hasValidWaitlistEmailTld(value) ? null : waitlistStatusMessages.invalidDomain;
}
