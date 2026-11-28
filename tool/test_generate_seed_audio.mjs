import assert from "node:assert/strict";
import { execFile as execFileCallback } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import http from "node:http";
import https from "node:https";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFile = promisify(execFileCallback);
const script = fileURLToPath(new URL("generate_seed_audio.mjs", import.meta.url));

async function listen(t, server) {
  await new Promise((done, fail) => server.once("error", fail).listen(0, "127.0.0.1", done));
  t.after(() => new Promise((done) => server.close(done)));
  return server.address().port;
}

test("seed publishing rejects HTTP and never sends either key type to a redirect target", async (t) => {
  const temp = resolve(tmpdir());
  const workspace = await mkdtemp(join(temp, "ponderin-seed-audio-test-"));
  assert.equal(dirname(workspace), temp);
  t.after(() => rm(workspace, { recursive: true, force: true }));
  const corpus = join(workspace, "assets", "seed", "vocab", "lang");
  await mkdir(corpus, { recursive: true });
  await writeFile(join(corpus, "fr.json"), JSON.stringify({
    entries: { fixture: { words: [{ word: "fixture" }] } },
  }));
  const keyFile = join(workspace, "key.pem");
  const certFile = join(workspace, "cert.pem");
  await execFile("openssl", [
    "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
    "-keyout", keyFile, "-out", certFile, "-subj", "/CN=127.0.0.1",
    "-addext", "subjectAltName=IP:127.0.0.1",
  ]);

  const targetCalls = [];
  const target = await listen(t, http.createServer((request, response) => {
    targetCalls.push(request.headers);
    response.end("{}");
  }));
  const originCalls = [];
  const origin = await listen(t, https.createServer({
    key: await readFile(keyFile), cert: await readFile(certFile),
  }, (request, response) => {
    originCalls.push({ path: request.url, headers: request.headers });
    request.resume();
    response.writeHead(307, { Location: `http://127.0.0.1:${target}/redirect-target` });
    response.end();
  }));

  const publish = (url, key) => execFile(process.execPath, [script], {
    cwd: workspace,
    env: {
      ...process.env, SUPABASE_URL: url, SUPABASE_SERVICE_ROLE_KEY: key,
      AUDIO_LANGS: "fr", NODE_EXTRA_CA_CERTS: certFile,
    },
    timeout: 10_000,
  });
  await assert.rejects(publish(`http://127.0.0.1:${target}`, "eyJ.fixture"),
    /Invalid Supabase HTTPS project origin/);

  for (const key of ["eyJ.fixture-admin", "sb_secret_fixture"]) {
    await assert.rejects(publish(`https://127.0.0.1:${origin}`, key), { code: 1 });
    const request = originCalls.at(-1);
    assert.equal(request.path, "/functions/v1/seed-audio-publish");
    assert.equal(request.headers.apikey, key);
    assert.equal(request.headers.authorization, key.startsWith("eyJ") ? `Bearer ${key}` : undefined);
  }
  assert.equal(originCalls.length, 2);
  assert.deepEqual(targetCalls, []);
});
