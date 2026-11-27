// Execute the staged entrypoints without network access or an HTTP listener.
type Handler = (request: Request) => Response | Promise<Response>;
const handlers: Handler[] = [];
Object.defineProperty(Deno, "serve", {
  value(handler: Handler) {
    handlers.push(handler);
  },
});

for (const entrypoint of Deno.args) {
  await import(entrypoint);
  if (handlers.length !== 1) {
    throw new Error(`Expected a single HTTP handler in ${entrypoint}`);
  }
  const response = await handlers.pop()!(
    new Request("https://bundle.invalid", {
      method: "OPTIONS",
    }),
  );
  if (response.status >= 500) {
    throw new Error(`Entrypoint ${entrypoint} failed to serve the probe`);
  }
  await response.body?.cancel();
}
