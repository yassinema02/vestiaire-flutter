-- Migration 026: OOTD Posts, Post-Squads join table, Post-Items join table
-- Story 9.2: OOTD Post Creation (FR-SOC-06)
--
-- Creates the tables for OOTD (Outfit of the Day) posts with
-- many-to-many relationships to squads and tagged wardrobe items.

BEGIN;

-- ============================================================
-- ootd_posts: User-created outfit photos shared to squads
-- ============================================================
CREATE TABLE app_public.ootd_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  caption VARCHAR(150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE app_public.ootd_posts IS 'OOTD (Outfit of the Day) posts shared by users to their style squads.';
COMMENT ON COLUMN app_public.ootd_posts.id IS 'Primary key, auto-generated UUID.';
COMMENT ON COLUMN app_public.ootd_posts.author_id IS 'References the profile of the user who created the post.';
COMMENT ON COLUMN app_public.ootd_posts.photo_url IS 'URL to the outfit photo in Cloud Storage.';
COMMENT ON COLUMN app_public.ootd_posts.caption IS 'Optional caption for the post (max 150 characters).';
COMMENT ON COLUMN app_public.ootd_posts.created_at IS 'Timestamp when the post was created.';
COMMENT ON COLUMN app_public.ootd_posts.deleted_at IS 'Soft-delete timestamp. Non-null means the post is deleted and excluded from queries.';

-- ============================================================
-- ootd_post_squads: Many-to-many join table (posts <-> squads)
-- ============================================================
CREATE TABLE app_public.ootd_post_squads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE,
  UNIQUE (post_id, squad_id)
);

COMMENT ON TABLE app_public.ootd_post_squads IS 'Join table linking OOTD posts to the squads they are shared with.';
COMMENT ON COLUMN app_public.ootd_post_squads.id IS 'Primary key, auto-generated UUID.';
COMMENT ON COLUMN app_public.ootd_post_squads.post_id IS 'References the OOTD post.';
COMMENT ON COLUMN app_public.ootd_post_squads.squad_id IS 'References the squad the post is shared to.';

-- ============================================================
-- ootd_post_items: Tagged wardrobe items on a post
-- ============================================================
CREATE TABLE app_public.ootd_post_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  UNIQUE (post_id, item_id)
);

COMMENT ON TABLE app_public.ootd_post_items IS 'Tagged wardrobe items on an OOTD post, enabling Steal This Look matching.';
COMMENT ON COLUMN app_public.ootd_post_items.id IS 'Primary key, auto-generated UUID.';
COMMENT ON COLUMN app_public.ootd_post_items.post_id IS 'References the OOTD post.';
COMMENT ON COLUMN app_public.ootd_post_items.item_id IS 'References the tagged wardrobe item.';

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX idx_ootd_posts_author_id ON app_public.ootd_posts(author_id);
CREATE INDEX idx_ootd_posts_created_at ON app_public.ootd_posts(created_at DESC);
CREATE INDEX idx_ootd_posts_deleted_at ON app_public.ootd_posts(deleted_at);
CREATE INDEX idx_ootd_post_squads_squad_id ON app_public.ootd_post_squads(squad_id);
CREATE INDEX idx_ootd_post_squads_post_id ON app_public.ootd_post_squads(post_id);
CREATE INDEX idx_ootd_post_items_post_id ON app_public.ootd_post_items(post_id);
CREATE INDEX idx_ootd_post_items_item_id ON app_public.ootd_post_items(item_id);

COMMIT;
