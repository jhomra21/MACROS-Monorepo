# MACROS Support Worker

Accepts optional in-app support submissions and emails the request to the verified destination behind `support@macrosios.com`. The Worker does not persist the request or log request bodies, email addresses, or messages.

## Prerequisites before deploying

1. Configure `macrosios.com` in Cloudflare Email Routing and verify its forwarding destination under **Email Routing → Destination Addresses**. Email Sending must target that verified destination, not the public `support@macrosios.com` routing alias.
2. Store the verified destination as the Worker secret `SUPPORT_DESTINATION`. Cloudflare Email Service sends to verified destination addresses are available even when Email Routing is the only Email feature configured. If a send fails with `E_SENDER_DOMAIN_NOT_AVAILABLE`, stop and onboard the sender domain to Email Sending before retrying.
3. Keep the destination private. Set it with Wrangler's secret prompt, or store it in a private file outside the repository:

   ```dotenv
   SUPPORT_DESTINATION=verified-destination@example.com
   ```

   Replace the placeholder with the exact verified destination. Do not commit the file or the real address.

   Do not put the personal destination in source, command arguments, or logs. Cloudflare's [`send_email` recipient restrictions](https://developers.cloudflare.com/email-service/configuration/send-bindings/) are static and cannot reference a Wrangler secret, so this binding intentionally has no recipient allowlist. The Worker always uses the secret as its recipient; clients cannot supply a recipient.
4. The `EMAIL` binding is configured in `wrangler.jsonc`.
5. Create the request-limit KV namespace and put its ID in `wrangler.jsonc`:

   ```sh
   bunx wrangler kv namespace create SUPPORT_RATE_LIMITS
   ```

6. Replace the all-zero placeholder `REQUEST_LIMITS` namespace ID in `wrangler.jsonc` with the ID returned by Wrangler.

## Local development and checks

```sh
bun install --frozen-lockfile
bun run check
bun run dev
```

## Deploy

From `worker/support/`:

```sh
bun install --frozen-lockfile
bun run deploy:dry-run
bun run deploy
```

Set `SUPPORT_DESTINATION` with `wrangler secret put` before deploying. The Wrangler file attaches the custom domain `support.macrosios.com`; deployment may provision its DNS record. After deployment, verify `POST https://support.macrosios.com/v1/requests` with a non-sensitive test message.

The Worker uses Cloudflare's native [`send_email` binding](https://developers.cloudflare.com/email-service/api/send-emails/workers-api/). It applies a five-per-IP rolling-hour count in KV plus a five-per-minute Cloudflare rate-limit binding to bound bursts. KV is eventually consistent and does not provide atomic increments, so simultaneous requests at the quota boundary can race; strict concurrent quota enforcement would require an atomic coordinator such as a Durable Object. Request bodies are capped at 16 KiB.
