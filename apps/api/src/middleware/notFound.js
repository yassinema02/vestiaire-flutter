export function notFound(req, res) {
  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ error: "Not Found" }));
}
