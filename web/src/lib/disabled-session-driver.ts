import type { SessionDriver } from 'astro';

function createDisabledSessionsError(): Error {
	return new Error('Astro sessions are disabled for this project.');
}

export default function disabledSessionDriver(): SessionDriver {
	return {
		async getItem() {
			throw createDisabledSessionsError();
		},
		async setItem() {
			throw createDisabledSessionsError();
		},
		async removeItem() {
			throw createDisabledSessionsError();
		},
	};
}
