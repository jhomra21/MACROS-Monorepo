// @ts-check
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

// https://astro.build/config
export default defineConfig({
	session: {
		driver: {
			entrypoint: new URL('./src/lib/disabled-session-driver.ts', import.meta.url),
		},
	},
	adapter: cloudflare({
		imageService: 'compile',
	}),
});
