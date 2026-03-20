export function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, { "content-type": "application/json" });
  res.end(JSON.stringify(payload));
}
