// Shared by the Astro build and the Worker, so it must not import Astro assets.
export const siteOrigin = 'https://macrosios.com';

/** Hosts that answer with a permanent redirect to `siteOrigin` instead of duplicate content. */
export const redirectHosts: ReadonlySet<string> = new Set([
	'www.macrosios.com',
	'macros-web.jhonra121.workers.dev',
]);
