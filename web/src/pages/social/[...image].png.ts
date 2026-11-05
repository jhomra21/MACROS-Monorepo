import type { APIRoute } from 'astro';
import { publicPages } from '../../lib/seo';
import { renderSocialImage, socialImage, socialInput, type SocialInput } from '../../lib/social';

export const prerender = true;

export async function getStaticPaths() {
	return Promise.all((await publicPages()).map(async page => {
		const input = await socialInput(page.path, page.title, page.description, page.image);
		const image = socialImage(input);

		return { params: { image: image.src.slice('/social/'.length, -'.png'.length) }, props: { input } };
	}));
}

export const GET: APIRoute = async ({ props }) => {
	// SAFETY: getStaticPaths supplies this input for every prerendered image.
	const { input } = props as { input: SocialInput };
	const image = await renderSocialImage(input);

	return new Response(new Uint8Array(image), { headers: { 'Content-Type': 'image/png' } });
};
