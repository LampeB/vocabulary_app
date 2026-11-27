// Retired: runtime TTS bypassed the authenticated provision-once/cache policy.
// Deploy this tombstone (or delete the old hosted function) before release.
// Current clients download pre-rendered assets and have no caller for this API.
Deno.serve(() =>
  Response.json({ error: "Endpoint retired; use audio-provision" }, {
    status: 410,
    headers: { "Access-Control-Allow-Origin": "*" },
  })
);
