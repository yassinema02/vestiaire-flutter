import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../.."
);

function parseEnvFile(contents) {
  const values = {};

  for (const rawLine of contents.split(/\r?\n/u)) {
    const line = rawLine.trim();

    if (!line || line.startsWith("#")) {
      continue;
    }

    const normalizedLine = line.startsWith("export ")
      ? line.slice("export ".length)
      : line;
    const separatorIndex = normalizedLine.indexOf("=");

    if (separatorIndex === -1) {
      continue;
    }

    const key = normalizedLine.slice(0, separatorIndex).trim();
    let value = normalizedLine.slice(separatorIndex + 1).trim();

    if (!key) {
      continue;
    }

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    values[key] = value.replace(/\\n/g, "\n");
  }

  return values;
}

function loadFileEnv() {
  const candidates = [
    path.join(process.cwd(), ".env"),
    path.join(process.cwd(), ".env.local"),
    path.join(repoRoot, ".env"),
    path.join(repoRoot, ".env.local")
  ];
  const loaded = {};

  for (const candidate of candidates) {
    if (!fs.existsSync(candidate)) {
      continue;
    }

    Object.assign(loaded, parseEnvFile(fs.readFileSync(candidate, "utf8")));
  }

  return loaded;
}

function parsePort(value) {
  const parsed = Number.parseInt(String(value ?? "8080"), 10);

  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
    throw new Error(`Invalid PORT value: ${value}`);
  }

  return parsed;
}

export function getConfig(env = process.env) {
  const resolvedEnv = {
    ...loadFileEnv(),
    ...env
  };

  return {
    host: resolvedEnv.HOST ?? "0.0.0.0",
    port: parsePort(resolvedEnv.PORT ?? 8080),
    nodeEnv: resolvedEnv.NODE_ENV ?? "development",
    appName: "vestiaire-api",
    databaseUrl: resolvedEnv.DATABASE_URL ?? "",
    firebaseProjectId: resolvedEnv.FIREBASE_PROJECT_ID ?? "",
    gcsBucket: resolvedEnv.GOOGLE_CLOUD_STORAGE_BUCKET ?? "",
    firebaseServiceAccountPath: resolvedEnv.FIREBASE_SERVICE_ACCOUNT_PATH || null,
    vertexAiLocation: resolvedEnv.VERTEX_AI_LOCATION ?? "europe-west1",
    gcpProjectId: resolvedEnv.GCP_PROJECT_ID ?? "",
    revenueCatApiKey: resolvedEnv.REVENUECAT_API_KEY ?? "",
    revenueCatWebhookAuthHeader: resolvedEnv.REVENUECAT_WEBHOOK_AUTH_HEADER ?? ""
  };
}
