-- Migration 027: OOTD Reactions & Comments
-- Story 9.4: Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)
--
-- Creates ootd_reactions (toggle-based, one per user per post) and
-- ootd_comments (text comments with soft delete) tables.

-- ==========================================
-- Table: ootd_reactions
-- ==========================================
CREATE TABLE app_public.ootd_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

COMMENT ON TABLE app_public.ootd_reactions IS 'Fire emoji reactions on OOTD posts. One reaction per user per post (toggle semantics).';
COMMENT ON COLUMN app_public.ootd_reactions.id IS 'Primary key UUID, auto-generated.';
COMMENT ON COLUMN app_public.ootd_reactions.post_id IS 'The OOTD post being reacted to.';
COMMENT ON COLUMN app_public.ootd_reactions.user_id IS 'The profile ID of the user who reacted.';
COMMENT ON COLUMN app_public.ootd_reactions.created_at IS 'Timestamp when the reaction was created.';

-- Indexes for ootd_reactions
CREATE INDEX idx_ootd_reactions_post_id ON app_public.ootd_reactions(post_id);
CREATE INDEX idx_ootd_reactions_user_id ON app_public.ootd_reactions(user_id);

-- ==========================================
-- Table: ootd_comments
-- ==========================================
CREATE TABLE app_public.ootd_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  text VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE app_public.ootd_comments IS 'Text comments on OOTD posts. Supports soft delete via deleted_at.';
COMMENT ON COLUMN app_public.ootd_comments.id IS 'Primary key UUID, auto-generated.';
COMMENT ON COLUMN app_public.ootd_comments.post_id IS 'The OOTD post being commented on.';
COMMENT ON COLUMN app_public.ootd_comments.author_id IS 'The profile ID of the comment author.';
COMMENT ON COLUMN app_public.ootd_comments.text IS 'Comment text content, max 200 characters.';
COMMENT ON COLUMN app_public.ootd_comments.created_at IS 'Timestamp when the comment was created.';
COMMENT ON COLUMN app_public.ootd_comments.deleted_at IS 'Soft delete timestamp. NULL means active, non-NULL means deleted.';

-- Indexes for ootd_comments
CREATE INDEX idx_ootd_comments_post_id ON app_public.ootd_comments(post_id);
CREATE INDEX idx_ootd_comments_author_id ON app_public.ootd_comments(author_id);
CREATE INDEX idx_ootd_comments_deleted_at ON app_public.ootd_comments(deleted_at);
