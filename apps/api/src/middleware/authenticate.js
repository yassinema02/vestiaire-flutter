import { AuthenticationError } from "../modules/auth/service.js";

function hasBearerToken(headers = {}) {
  const authorization =
    headers.authorization ?? headers.Authorization ?? "";

  return authorization.startsWith("Bearer ");
}

export async function requireAuth(req, authService) {
  if (!hasBearerToken(req.headers)) {
    throw new AuthenticationError("Bearer token required");
  }

  return authService.authenticate(req);
}
