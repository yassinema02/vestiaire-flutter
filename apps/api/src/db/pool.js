import pg from "pg";

const { Pool } = pg;

export function createPool(config) {
  if (!config.databaseUrl) {
    throw new Error("DATABASE_URL is required for protected profile access");
  }

  return new Pool({
    connectionString: config.databaseUrl
  });
}
