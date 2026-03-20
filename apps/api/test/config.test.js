import test from "node:test";
import assert from "node:assert/strict";
import { getConfig } from "../src/config/env.js";

test("getConfig returns Cloud Run-safe defaults", async () => {
  const config = getConfig({});

  assert.equal(config.host, "0.0.0.0");
  assert.equal(config.port, 8080);
  assert.equal(config.nodeEnv, "development");
  assert.equal(config.appName, "vestiaire-api");
  assert.equal(config.databaseUrl, "");
  assert.equal(config.firebaseProjectId, "");
});

test("getConfig rejects invalid port values", async () => {
  assert.throws(
    () => getConfig({ PORT: "not-a-number" }),
    /Invalid PORT value/
  );
});
