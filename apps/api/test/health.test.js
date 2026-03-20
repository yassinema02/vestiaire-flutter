import test from "node:test";
import assert from "node:assert/strict";
import { handleRequest } from "../src/main.js";

function createResponseCapture() {
  return {
    statusCode: undefined,
    headers: undefined,
    body: undefined,
    writeHead(statusCode, headers) {
      this.statusCode = statusCode;
      this.headers = headers;
    },
    end(body) {
      this.body = body;
    }
  };
}

test("GET /healthz returns service health payload", async () => {
  const response = createResponseCapture();

  await handleRequest(
    { method: "GET", url: "/healthz" },
    response,
    { appName: "vestiaire-api", nodeEnv: "test" }
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(JSON.parse(response.body), {
    service: "vestiaire-api",
    status: "ok",
    environment: "test"
  });
});

test("unknown routes return 404", async () => {
  const response = createResponseCapture();

  await handleRequest(
    { method: "GET", url: "/missing" },
    response,
    { appName: "vestiaire-api", nodeEnv: "test" }
  );

  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "Not Found");
});
