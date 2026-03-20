import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../../..");

function readRepoFile(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
}

test("profiles migration creates a provision-safe root profile table", () => {
  const sql = readRepoFile("infra/sql/migrations/002_profiles.sql");

  assert.match(sql, /create table if not exists app_public\.profiles/i);
  assert.match(sql, /id uuid primary key default gen_random_uuid\(\)/i);
  assert.match(sql, /firebase_uid text not null unique/i);
  assert.match(sql, /auth_provider text not null/i);
  assert.match(sql, /email_verified boolean not null default false/i);
  assert.match(sql, /created_at timestamptz not null default timezone\('utc', now\(\)\)/i);
  assert.match(sql, /updated_at timestamptz not null default timezone\('utc', now\(\)\)/i);
});

test("profiles policy uses transaction-scoped user context for RLS", () => {
  const sql = readRepoFile("infra/sql/policies/002_profiles_rls.sql");

  assert.match(sql, /alter table app_public\.profiles enable row level security/i);
  assert.match(sql, /alter table app_public\.profiles force row level security/i);
  assert.match(sql, /current_setting\('app\.current_user_id', true\)/i);
  assert.match(sql, /create policy profiles_self_select/i);
  assert.match(sql, /create policy profiles_self_insert/i);
  assert.match(sql, /create policy profiles_self_update/i);
  assert.match(sql, /create policy profiles_self_delete/i);
  assert.match(sql, /execute function app_private\.set_updated_at\(\)/i);
});
