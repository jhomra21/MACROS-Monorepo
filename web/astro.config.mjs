// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
	trailingSlash: 'always',
	// Native document transitions need neither the router nor its prefetch script.
	prefetch: false,
	vite: {
		server: {
			proxy: {
				'/api': {
					target: 'http://127.0.0.1:8787',
					changeOrigin: true,
				},
			},
		},
	},
});
