import crypto from "node:crypto";

const CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

function decodeBase64Url(input) {
  return Buffer.from(input, "base64url").toString("utf8");
}

function parseJwt(token) {
  const segments = String(token).split(".");

  if (segments.length !== 3) {
    throw new Error("Malformed Firebase JWT");
  }

  return {
    encodedHeader: segments[0],
    encodedPayload: segments[1],
    signature: segments[2],
    header: JSON.parse(decodeBase64Url(segments[0])),
    payload: JSON.parse(decodeBase64Url(segments[1]))
  };
}

function createCertCache(fetchImpl) {
  let cached = null;

  return async function getCertificates() {
    const now = Date.now();

    if (cached && cached.expiresAt > now) {
      return cached.certificates;
    }

    const response = await fetchImpl(CERTS_URL);

    if (!response.ok) {
      throw new Error(`Failed to load Firebase signing certificates: ${response.status}`);
    }

    const cacheControl = response.headers.get("cache-control") ?? "";
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/i);
    const maxAgeSeconds = maxAgeMatch
      ? Number.parseInt(maxAgeMatch[1], 10)
      : 3600;

    cached = {
      certificates: await response.json(),
      expiresAt: now + maxAgeSeconds * 1000
    };

    return cached.certificates;
  };
}

export function createFirebaseTokenVerifier({
  projectId,
  fetchImpl = fetch,
  clock = () => Date.now()
}) {
  if (!projectId) {
    throw new Error("FIREBASE_PROJECT_ID is required for Firebase JWT validation");
  }

  const getCertificates = createCertCache(fetchImpl);

  return async function verifyToken(token) {
    const parsed = parseJwt(token);
    const { header, payload, encodedHeader, encodedPayload, signature } = parsed;

    if (header.alg !== "RS256" || !header.kid) {
      throw new Error("Unsupported Firebase JWT header");
    }

    const certificates = await getCertificates();
    const certificate = certificates[header.kid];

    if (!certificate) {
      throw new Error("Unknown Firebase signing key");
    }

    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(`${encodedHeader}.${encodedPayload}`);
    verifier.end();

    const isValidSignature = verifier.verify(certificate, signature, "base64url");

    if (!isValidSignature) {
      throw new Error("Invalid Firebase JWT signature");
    }

    const nowSeconds = Math.floor(clock() / 1000);
    const expectedIssuer = `https://securetoken.google.com/${projectId}`;

    if (payload.aud !== projectId) {
      throw new Error("Firebase JWT audience mismatch");
    }

    if (payload.iss !== expectedIssuer) {
      throw new Error("Firebase JWT issuer mismatch");
    }

    if (!payload.sub || typeof payload.sub !== "string") {
      throw new Error("Firebase JWT subject is missing");
    }

    if (payload.exp <= nowSeconds) {
      throw new Error("Firebase JWT is expired");
    }

    if (payload.iat > nowSeconds) {
      throw new Error("Firebase JWT issued-at time is invalid");
    }

    return payload;
  };
}
