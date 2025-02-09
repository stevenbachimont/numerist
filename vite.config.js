import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// https://vite.dev/config/
export default defineConfig({
	plugins: [sveltekit()],
	server: {
		host: '0.0.0.0',
		port: 3333,
		allowedHosts: [
			'numerist.stevenbachimont.com',
			'localhost'
		]
	}
});
