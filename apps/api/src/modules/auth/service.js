export class AuthenticationError extends Error {
  constructor(message = "Authentication required") {
    super(message);
    this.name = "AuthenticationError";
    this.statusCode = 401;
    this.code = "UNAUTHORIZED";
  }
}

export class AuthorizationError extends Error {
  constructor(message = "Forbidden", code = "FORBIDDEN") {
    super(message);
    this.name = "AuthorizationError";
    this.statusCode = 403;
    this.code = code;
  }
}

function readBearerToken(headers = {}) {
  const authorization =
    headers.authorization ?? headers.Authorization ?? "";
  const [scheme, token] = authorization.split(" ");

  if (scheme !== "Bearer" || !token) {
    throw new AuthenticationError("Bearer token required");
  }

  return token;
}

function normalizeAuthContext(claims) {
  const provider = claims.firebase?.sign_in_provider ?? "unknown";
  const emailVerified = claims.email_verified === true;

  if (provider === "password" && !emailVerified) {
    throw new AuthorizationError(
      "Email verification required",
      "EMAIL_VERIFICATION_REQUIRED"
    );
  }

  return {
    userId: claims.sub,
    email: claims.email ?? null,
    emailVerified,
    provider
  };
}

export function createAuthService({ verifyToken }) {
  if (typeof verifyToken !== "function") {
    throw new TypeError("verifyToken must be a function");
  }

  return {
    async authenticate(req) {
      const token = readBearerToken(req.headers);

      try {
        const claims = await verifyToken(token);
        return normalizeAuthContext(claims);
      } catch (error) {
        if (
          error instanceof AuthenticationError ||
          error instanceof AuthorizationError
        ) {
          throw error;
        }

        throw new AuthenticationError("Invalid Firebase token");
      }
    }
  };
}
