/**
 * Repository for OOTD post data access.
 *
 * Handles CRUD operations for ootd_posts, ootd_post_squads, ootd_post_items,
 * ootd_reactions, and ootd_comments tables.
 * Uses RLS via app.current_user_id setting for row-level security.
 *
 * Story 9.2: OOTD Post Creation (FR-SOC-06)
 * Story 9.4: Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)
 */

/**
 * Map an ootd_posts database row (snake_case) to camelCase.
 */
export function mapPostRow(row) {
  return {
    id: row.id,
    authorId: row.author_id,
    photoUrl: row.photo_url,
    caption: row.caption ?? null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    authorDisplayName: row.author_display_name ?? null,
    authorPhotoUrl: row.author_photo_url ?? null,
    taggedItems: row.tagged_items ?? [],
    squadIds: row.squad_ids ?? [],
    reactionCount: row.reaction_count ?? 0,
    commentCount: row.comment_count ?? 0,
    hasReacted: row.has_reacted ?? false,
  };
}

/**
 * Map an ootd_comments database row (snake_case) to camelCase.
 */
export function mapCommentRow(row) {
  return {
    id: row.id,
    postId: row.post_id,
    authorId: row.author_id,
    text: row.text,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    authorDisplayName: row.author_display_name ?? null,
    authorPhotoUrl: row.author_photo_url ?? null,
  };
}

/**
 * Map an ootd_post_items database row (snake_case) to camelCase.
 */
export function mapPostItemRow(row) {
  return {
    id: row.id,
    postId: row.post_id,
    itemId: row.item_id,
    itemName: row.item_name ?? null,
    itemPhotoUrl: row.item_photo_url ?? null,
    itemCategory: row.item_category ?? null,
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createOotdRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create an OOTD post with squad associations and tagged items in a single transaction.
     */
    async createPost(authContext, { photoUrl, caption, squadIds, taggedItemIds }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }

        const profileId = profileResult.rows[0].id;

        // Insert the post
        const postResult = await client.query(
          `INSERT INTO app_public.ootd_posts (author_id, photo_url, caption)
           VALUES ($1, $2, $3)
           RETURNING *`,
          [profileId, photoUrl, caption ?? null]
        );

        const post = postResult.rows[0];

        // Insert post-squad associations
        for (const squadId of squadIds) {
          await client.query(
            `INSERT INTO app_public.ootd_post_squads (post_id, squad_id)
             VALUES ($1, $2)`,
            [post.id, squadId]
          );
        }

        // Insert tagged items
        if (taggedItemIds && taggedItemIds.length > 0) {
          for (const itemId of taggedItemIds) {
            await client.query(
              `INSERT INTO app_public.ootd_post_items (post_id, item_id)
               VALUES ($1, $2)`,
              [post.id, itemId]
            );
          }
        }

        await client.query("commit");

        // Fetch tagged items with details
        const taggedItems = taggedItemIds && taggedItemIds.length > 0
          ? await this.getPostItemsByPostId(post.id)
          : [];

        return {
          ...mapPostRow({
            ...post,
            tagged_items: taggedItems,
            squad_ids: squadIds,
          }),
          taggedItems,
          squadIds,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get a post by ID with author profile info, tagged items, and squad IDs.
     */
    async getPostById(authContext, postId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id for hasReacted subquery
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        const profileId = profileResult.rows.length > 0 ? profileResult.rows[0].id : null;

        const result = await client.query(
          `SELECT op.*,
                  p.display_name AS author_display_name,
                  p.photo_url AS author_photo_url,
                  (SELECT COUNT(*) FROM app_public.ootd_reactions WHERE post_id = op.id)::int AS reaction_count,
                  (SELECT COUNT(*) FROM app_public.ootd_comments WHERE post_id = op.id AND deleted_at IS NULL)::int AS comment_count,
                  (SELECT EXISTS(SELECT 1 FROM app_public.ootd_reactions WHERE post_id = op.id AND user_id = $2)) AS has_reacted
           FROM app_public.ootd_posts op
           JOIN app_public.profiles p ON p.id = op.author_id
           WHERE op.id = $1`,
          [postId, profileId]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        const taggedItems = await this.getPostItemsByPostId(postId);
        const squadIds = await this.getPostSquadsByPostId(postId);

        return {
          ...mapPostRow({
            ...row,
            tagged_items: taggedItems,
            squad_ids: squadIds,
          }),
          taggedItems,
          squadIds,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List paginated posts for a specific squad, ordered by created_at DESC.
     */
    async listPostsForSquad(authContext, squadId, { limit = 20, cursor } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id for hasReacted subquery
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        const profileId = profileResult.rows.length > 0 ? profileResult.rows[0].id : null;

        const params = [squadId, limit + 1, profileId];
        let cursorClause = "";
        if (cursor) {
          cursorClause = "AND op.created_at < $4";
          params.push(cursor);
        }

        const result = await client.query(
          `SELECT op.*,
                  p.display_name AS author_display_name,
                  p.photo_url AS author_photo_url,
                  (SELECT COUNT(*) FROM app_public.ootd_reactions WHERE post_id = op.id)::int AS reaction_count,
                  (SELECT COUNT(*) FROM app_public.ootd_comments WHERE post_id = op.id AND deleted_at IS NULL)::int AS comment_count,
                  (SELECT EXISTS(SELECT 1 FROM app_public.ootd_reactions WHERE post_id = op.id AND user_id = $3)) AS has_reacted
           FROM app_public.ootd_posts op
           JOIN app_public.ootd_post_squads ops ON ops.post_id = op.id
           JOIN app_public.profiles p ON p.id = op.author_id
           WHERE ops.squad_id = $1
             AND op.deleted_at IS NULL
             ${cursorClause}
           ORDER BY op.created_at DESC
           LIMIT $2`,
          params
        );

        await client.query("commit");

        const hasMore = result.rows.length > limit;
        const rows = hasMore ? result.rows.slice(0, limit) : result.rows;

        const posts = await Promise.all(
          rows.map(async (row) => {
            const taggedItems = await this.getPostItemsByPostId(row.id);
            const squadIds = await this.getPostSquadsByPostId(row.id);
            return {
              ...mapPostRow({ ...row, tagged_items: taggedItems, squad_ids: squadIds }),
              taggedItems,
              squadIds,
            };
          })
        );

        const nextCursor = hasMore
          ? rows[rows.length - 1].created_at?.toISOString?.() ?? rows[rows.length - 1].created_at
          : null;

        return { posts, nextCursor };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List paginated posts across all user's squads, ordered by created_at DESC.
     */
    async listPostsForUser(authContext, { limit = 20, cursor } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Get user's profile ID
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length === 0) {
          await client.query("commit");
          return { posts: [], nextCursor: null };
        }
        const profileId = profileResult.rows[0].id;

        const params = [profileId, limit + 1];
        let cursorClause = "";
        if (cursor) {
          cursorClause = "AND op.created_at < $3";
          params.push(cursor);
        }

        const result = await client.query(
          `SELECT DISTINCT ON (op.id) op.*,
                  p.display_name AS author_display_name,
                  p.photo_url AS author_photo_url,
                  (SELECT COUNT(*) FROM app_public.ootd_reactions WHERE post_id = op.id)::int AS reaction_count,
                  (SELECT COUNT(*) FROM app_public.ootd_comments WHERE post_id = op.id AND deleted_at IS NULL)::int AS comment_count,
                  (SELECT EXISTS(SELECT 1 FROM app_public.ootd_reactions WHERE post_id = op.id AND user_id = $1)) AS has_reacted
           FROM app_public.ootd_posts op
           JOIN app_public.ootd_post_squads ops ON ops.post_id = op.id
           JOIN app_public.squad_memberships sm ON sm.squad_id = ops.squad_id
           JOIN app_public.profiles p ON p.id = op.author_id
           WHERE sm.user_id = $1
             AND op.deleted_at IS NULL
             ${cursorClause}
           ORDER BY op.id, op.created_at DESC
           LIMIT $2`,
          params
        );

        await client.query("commit");

        // Re-sort by created_at DESC since DISTINCT ON requires ordering by id first
        const sortedRows = result.rows.sort((a, b) => {
          const aTime = new Date(a.created_at).getTime();
          const bTime = new Date(b.created_at).getTime();
          return bTime - aTime;
        });

        const hasMore = sortedRows.length > limit;
        const rows = hasMore ? sortedRows.slice(0, limit) : sortedRows;

        const posts = await Promise.all(
          rows.map(async (row) => {
            const taggedItems = await this.getPostItemsByPostId(row.id);
            const squadIds = await this.getPostSquadsByPostId(row.id);
            return {
              ...mapPostRow({ ...row, tagged_items: taggedItems, squad_ids: squadIds }),
              taggedItems,
              squadIds,
            };
          })
        );

        const nextCursor = hasMore
          ? rows[rows.length - 1].created_at?.toISOString?.() ?? rows[rows.length - 1].created_at
          : null;

        return { posts, nextCursor };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Soft-delete a post by setting deleted_at = NOW().
     */
    async softDeletePost(authContext, postId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }
        const profileId = profileResult.rows[0].id;

        await client.query(
          "UPDATE app_public.ootd_posts SET deleted_at = NOW() WHERE id = $1 AND author_id = $2",
          [postId, profileId]
        );

        await client.query("commit");
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    // --- Reactions ---

    /**
     * Toggle a reaction on a post. If already reacted, removes; otherwise adds.
     * Uses a transaction for atomicity.
     */
    async toggleReaction(authContext, postId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }
        const profileId = profileResult.rows[0].id;

        // Check if reaction exists
        const existing = await client.query(
          "SELECT id FROM app_public.ootd_reactions WHERE post_id = $1 AND user_id = $2 LIMIT 1",
          [postId, profileId]
        );

        let reacted;
        if (existing.rows.length > 0) {
          // Remove reaction
          await client.query(
            "DELETE FROM app_public.ootd_reactions WHERE post_id = $1 AND user_id = $2",
            [postId, profileId]
          );
          reacted = false;
        } else {
          // Add reaction
          await client.query(
            "INSERT INTO app_public.ootd_reactions (post_id, user_id) VALUES ($1, $2)",
            [postId, profileId]
          );
          reacted = true;
        }

        await client.query("commit");
        return { reacted };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get reaction count for a post.
     */
    async getReactionCount(postId) {
      const result = await pool.query(
        "SELECT COUNT(*)::int AS count FROM app_public.ootd_reactions WHERE post_id = $1",
        [postId]
      );
      return result.rows[0].count;
    },

    /**
     * Check if a user has reacted to a post.
     */
    async hasUserReacted(postId, profileId) {
      const result = await pool.query(
        "SELECT 1 FROM app_public.ootd_reactions WHERE post_id = $1 AND user_id = $2 LIMIT 1",
        [postId, profileId]
      );
      return result.rows.length > 0;
    },

    // --- Comments ---

    /**
     * Create a comment on a post.
     */
    async createComment(authContext, postId, { text }) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up profile_id
        const profileResult = await client.query(
          "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
          [authContext.userId]
        );
        if (profileResult.rows.length === 0) {
          throw { statusCode: 401, message: "Profile not found" };
        }
        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `INSERT INTO app_public.ootd_comments (post_id, author_id, text)
           VALUES ($1, $2, $3)
           RETURNING *`,
          [postId, profileId, text]
        );

        // Get author profile info
        const authorResult = await client.query(
          "SELECT display_name, photo_url FROM app_public.profiles WHERE id = $1",
          [profileId]
        );

        await client.query("commit");

        const comment = result.rows[0];
        return mapCommentRow({
          ...comment,
          author_display_name: authorResult.rows[0]?.display_name ?? null,
          author_photo_url: authorResult.rows[0]?.photo_url ?? null,
        });
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List paginated comments for a post, ordered by created_at ASC (oldest first).
     */
    async listComments(authContext, postId, { limit = 50, cursor } = {}) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const params = [postId, limit + 1];
        let cursorClause = "";
        if (cursor) {
          cursorClause = "AND oc.created_at > $3";
          params.push(cursor);
        }

        const result = await client.query(
          `SELECT oc.*,
                  p.display_name AS author_display_name,
                  p.photo_url AS author_photo_url
           FROM app_public.ootd_comments oc
           JOIN app_public.profiles p ON p.id = oc.author_id
           WHERE oc.post_id = $1
             AND oc.deleted_at IS NULL
             ${cursorClause}
           ORDER BY oc.created_at ASC
           LIMIT $2`,
          params
        );

        await client.query("commit");

        const hasMore = result.rows.length > limit;
        const rows = hasMore ? result.rows.slice(0, limit) : result.rows;

        const comments = rows.map(mapCommentRow);
        const nextCursor = hasMore
          ? rows[rows.length - 1].created_at?.toISOString?.() ?? rows[rows.length - 1].created_at
          : null;

        return { comments, nextCursor };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Soft-delete a comment by setting deleted_at = NOW().
     */
    async softDeleteComment(authContext, commentId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        await client.query(
          "UPDATE app_public.ootd_comments SET deleted_at = NOW() WHERE id = $1",
          [commentId]
        );

        await client.query("commit");
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get a comment by ID (for authorization checks).
     */
    async getCommentById(commentId) {
      const result = await pool.query(
        "SELECT * FROM app_public.ootd_comments WHERE id = $1 AND deleted_at IS NULL LIMIT 1",
        [commentId]
      );
      return result.rows.length > 0 ? result.rows[0] : null;
    },

    /**
     * Get all tagged items for a post with item details.
     */
    async getPostItemsByPostId(postId) {
      const result = await pool.query(
        `SELECT opi.*, i.name AS item_name, i.photo_url AS item_photo_url, i.category AS item_category
         FROM app_public.ootd_post_items opi
         JOIN app_public.items i ON i.id = opi.item_id
         WHERE opi.post_id = $1`,
        [postId]
      );
      return result.rows.map(mapPostItemRow);
    },

    /**
     * Get tagged items for a post with full item metadata for Gemini prompt construction.
     * Story 9.5: "Steal This Look" Matcher (FR-SOC-12)
     */
    async getPostItemsWithDetails(postId) {
      const result = await pool.query(
        `SELECT i.id, i.name, i.category, i.color, i.secondary_colors, i.pattern, i.material, i.style, i.season, i.occasion, i.photo_url
         FROM app_public.ootd_post_items opi
         JOIN app_public.items i ON i.id = opi.item_id
         WHERE opi.post_id = $1`,
        [postId]
      );
      return result.rows.map((row) => ({
        id: row.id,
        name: row.name ?? null,
        category: row.category ?? null,
        color: row.color ?? null,
        secondaryColors: row.secondary_colors ?? [],
        pattern: row.pattern ?? null,
        material: row.material ?? null,
        style: row.style ?? null,
        season: row.season ?? [],
        occasion: row.occasion ?? [],
        photoUrl: row.photo_url ?? null,
      }));
    },

    /**
     * Get all squad IDs for a post.
     */
    async getPostSquadsByPostId(postId) {
      const result = await pool.query(
        "SELECT squad_id FROM app_public.ootd_post_squads WHERE post_id = $1",
        [postId]
      );
      return result.rows.map((r) => r.squad_id);
    },
  };
}
