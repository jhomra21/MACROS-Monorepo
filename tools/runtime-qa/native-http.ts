import http from "node:http";
import { once } from "node:events";
import type { IncomingHttpHeaders } from "node:http";
import type { AddressInfo } from "node:net";

export interface LocalServer {
  port: number;
  ready: Promise<void>;
  stop(): Promise<void>;
}

export function serve(options: {
  hostname: string;
  port: number;
  fetch(request: Request): Promise<Response>;
}): LocalServer {
  const server = http.createServer(async (incoming, outgoing) => {
    try {
      const chunks: Buffer[] = [];

      for await (const chunk of incoming) chunks.push(chunk);
      const address = tcpAddress(server.address());

      if (address == null) throw new Error("No loopback address.");

      const headers = toWebHeaders(incoming.headers);

      const requestInit: RequestInit = {
        method: incoming.method,
        headers,
      };

      if (incoming.method !== "GET") {
        requestInit.body = Buffer.concat(chunks);
      }

      const request = new Request(`http://127.0.0.1:${address.port}${incoming.url}`, requestInit);

      const response = await options.fetch(request);
      outgoing.writeHead(response.status, Object.fromEntries(response.headers));
      outgoing.end(Buffer.from(await response.arrayBuffer()));
    } catch {
      outgoing.writeHead(500);
      outgoing.end("Harness proxy error");
    }
  });

  server.listen(options.port, options.hostname);

  return {
    get port() {
      const address = tcpAddress(server.address());

      if (address == null) throw new Error("No loopback address.");

      return address.port;
    },
    ready: once(server, "listening").then(() => {}),
    stop() {
      server.closeAllConnections();

      return new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    },
  };
}

function tcpAddress(address: string | AddressInfo | null): AddressInfo | null {
  // SAFETY: serve() binds a numeric TCP port and hostname, so Node returns AddressInfo, never a pipe path.
  return address as AddressInfo | null;
}

function toWebHeaders(headers: IncomingHttpHeaders): Headers {
  const result = new Headers();

  for (const [name, value] of Object.entries(headers)) {
    if (value == null) {
      continue;
    }

    for (const item of Array.isArray(value) ? value : [value]) {
      result.append(name, item);
    }
  }

  return result;
}
