// Local probe for routing-matrix.sh: wraps the real Worker so every response that ran Worker code
// carries `x-probe-worker: 1`. Responses served by the asset router alone never have it.
import worker from '../../../web/src/worker';
import type { WorkerEnv } from '../../../web/src/worker';

export default {
	async fetch(request: Request, env: WorkerEnv): Promise<Response> {
		const response = await worker.fetch(request, env);
		const probed = new Response(response.body, response);

		probed.headers.set('x-probe-worker', '1');

		return probed;
	},
};
