# MACROS Support Worker

Accepts optional in-app support submissions and emails the request to `support@macrosios.com`. It does not persist the request or log request bodies, email addresses, or messages.

## Prerequisites before deploying

1. Configure `macrosios.com` in Cloudflare Email Routing and verify `support@macrosios.com` as a destination address. The send binding restricts delivery to this destination.
2. Enable Cloudflare Email Service sending for `macrosios.com`, finish onboarding the sender domain, and verify/authorize `no-reply@macrosios.com`. Email Routing alone does not make a sender eligible for the current Email Service Workers API. Cloudflare may permit only verified destination addresses until the sender domain is onboarded.
3. Ensure the account and zone are active for Email Service sending. The binding is configured as `EMAIL` in `wrangler.jsonc`.
4. Create the request-limit KV namespace and put its ID in `wrangler.jsonc`:

   ```sh
   bunx wrangler kv namespace create SUPPORT_RATE_LIMITS
   ```

5. Replace the all-zero placeholder `REQUEST_LIMITS` namespace ID in `wrangler.jsonc` with the ID returned by Wrangler.
6. Confirm DNS and authentication records required by Cloudflare's Email Service setup. No DNS records are changed by this project.

## Local development and checks

```sh
bun install --frozen-lockfile
bun run check
bun run dev
```

## Deploy steps (not performed)

From `worker/support/` after the prerequisites above:

```sh
bun install --frozen-lockfile
bun run deploy:dry-run
bun run deploy
```

The Wrangler file is prepared to attach the custom domain `support.macrosios.com`; deployment will require the `macrosios.com` zone to be active in this Cloudflare account and may provision its DNS record. Review the diff and authorize that DNS/custom-domain change before deploying. After deployment, verify `POST https://support.macrosios.com/v1/requests` with a non-sensitive test message.

The Worker uses Cloudflare's native `send_email` binding (`env.EMAIL.send(...)`) from the [Workers Email Sending API](https://developers.cloudflare.com/email-routing/email-workers/send-email-workers/). It applies a five-per-IP rolling-hour count in KV plus a five-per-minute Cloudflare rate-limit binding to bound bursts. KV is eventually consistent and does not provide atomic increments, so simultaneous requests at the quota boundary can race; strict concurrent quota enforcement would require an atomic coordinator such as a Durable Object. Request bodies are capped at 16 KiB.
