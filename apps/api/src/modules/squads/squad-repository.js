/**
 * Repository for squad data access.
 *
 * Handles CRUD operations for style_squads and squad_memberships tables.
 * Uses RLS via app.current_user_id setting for row-level security.
 *
 * Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)
 */

/**
 * Map a style_squads database row (snake_case) to camelCase.
 */
export function mapSquadRow(row) {
  return {
    id: row.id,
    name: row.name,
    description: row.description ?? null,
    inviteCode: row.invite_code,
    createdBy: row.created_by,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
    memberCount: row.member_count != null ? parseInt(row.member_count, 10) : undefined,
    lastActivity: row.last_activity?.toISOString?.() ?? row.last_activity ?? null,
  };
}

/**
 * Map a squad_memberships database row (snake_case) to camelCase,
 * including joined profile info.
 */
export function mapMembershipRow(row) {
  return {
    id: row.id,
    squadId: row.squad_id,
    userId: row.user_id,
    role: row.role,
    joinedAt: row.joined_at?.toISOString?.() ?? row.joined_at ?? null,
    displayName: row.display_name ?? null,
    photoUrl: row.photo_url ?? null,
  };
}

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createSquadRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Create a squad and the admin membership in a single transaction.
     */
    async createSquad(authContext, { name, description, inviteCode }) {
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

        // Insert squad
        const squadResult = await client.query(
          `INSERT INTO app_public.style_squads (name, description, invite_code, created_by)
           VALUES ($1, $2, $3, $4)
           RETURNING *`,
          [name, description ?? null, inviteCode, profileId]
        );

        const squad = squadResult.rows[0];

        // Insert admin membership
        await client.query(
          `INSERT INTO app_public.squad_memberships (squad_id, user_id, role)
           VALUES ($1, $2, 'admin')`,
          [squad.id, profileId]
        );

        await client.query("commit");

        return {
          ...mapSquadRow(squad),
          memberCount: 1,
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Look up a squad by its invite code (ignoring soft-deleted squads).
     */
    async getSquadByInviteCode(inviteCode) {
      const result = await pool.query(
        `SELECT * FROM app_public.style_squads
         WHERE invite_code = $1 AND deleted_at IS NULL`,
        [inviteCode]
      );

      if (result.rows.length === 0) return null;
      return mapSquadRow(result.rows[0]);
    },

    /**
     * Get a squad by ID (with RLS - user must be a member).
     */
    async getSquadById(authContext, squadId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT s.*,
                  (SELECT COUNT(*) FROM app_public.squad_memberships sm WHERE sm.squad_id = s.id) AS member_count
           FROM app_public.style_squads s
           WHERE s.id = $1`,
          [squadId]
        );

        await client.query("commit");

        if (result.rows.length === 0) return null;
        return mapSquadRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * List all squads for the authenticated user with member count and last activity.
     */
    async listSquadsForUser(authContext) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT s.*,
                  (SELECT COUNT(*) FROM app_public.squad_memberships sm WHERE sm.squad_id = s.id) AS member_count,
                  (SELECT MAX(sm2.joined_at) FROM app_public.squad_memberships sm2 WHERE sm2.squad_id = s.id) AS last_activity
           FROM app_public.style_squads s
           ORDER BY s.updated_at DESC`
        );

        await client.query("commit");
        return result.rows.map(mapSquadRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Get the member count for a squad.
     */
    async getSquadMemberCount(squadId) {
      const result = await pool.query(
        "SELECT COUNT(*) AS count FROM app_public.squad_memberships WHERE squad_id = $1",
        [squadId]
      );
      return parseInt(result.rows[0].count, 10);
    },

    /**
     * Add a member to a squad.
     */
    async addMember(squadId, userId, role = "member") {
      await pool.query(
        `INSERT INTO app_public.squad_memberships (squad_id, user_id, role)
         VALUES ($1, $2, $3)`,
        [squadId, userId, role]
      );
    },

    /**
     * Remove a member from a squad.
     */
    async removeMember(squadId, memberId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        // We need RLS context for delete policy, but removeMember is called from service
        // which already validated auth. Use direct delete here.
        await client.query(
          "DELETE FROM app_public.squad_memberships WHERE squad_id = $1 AND user_id = $2",
          [squadId, memberId]
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
     * Get a membership row for a specific user in a squad.
     */
    async getMembership(squadId, userId) {
      const result = await pool.query(
        `SELECT sm.*, p.display_name, p.photo_url
         FROM app_public.squad_memberships sm
         JOIN app_public.profiles p ON p.id = sm.user_id
         WHERE sm.squad_id = $1 AND sm.user_id = $2`,
        [squadId, userId]
      );

      if (result.rows.length === 0) return null;
      return mapMembershipRow(result.rows[0]);
    },

    /**
     * List all members of a squad with profile info.
     */
    async listMembers(authContext, squadId) {
      const client = await pool.connect();
      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT sm.*, p.display_name, p.photo_url
           FROM app_public.squad_memberships sm
           JOIN app_public.profiles p ON p.id = sm.user_id
           WHERE sm.squad_id = $1
           ORDER BY sm.joined_at ASC`,
          [squadId]
        );

        await client.query("commit");
        return result.rows.map(mapMembershipRow);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    /**
     * Soft-delete a squad by setting deleted_at.
     */
    async softDeleteSquad(squadId) {
      await pool.query(
        "UPDATE app_public.style_squads SET deleted_at = NOW() WHERE id = $1",
        [squadId]
      );
    },

    /**
     * Transfer ownership of a squad to a new owner.
     */
    async transferOwnership(squadId, newOwnerId) {
      const client = await pool.connect();
      try {
        await client.query("begin");

        // Update squad created_by
        await client.query(
          "UPDATE app_public.style_squads SET created_by = $1, updated_at = NOW() WHERE id = $2",
          [newOwnerId, squadId]
        );

        // Update old admin to member
        await client.query(
          `UPDATE app_public.squad_memberships SET role = 'member'
           WHERE squad_id = $1 AND role = 'admin'`,
          [squadId]
        );

        // Update new owner to admin
        await client.query(
          `UPDATE app_public.squad_memberships SET role = 'admin'
           WHERE squad_id = $1 AND user_id = $2`,
          [squadId, newOwnerId]
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
     * Look up profile ID from firebase UID.
     */
    async getProfileIdForUser(userId) {
      const result = await pool.query(
        "SELECT id FROM app_public.profiles WHERE firebase_uid = $1 LIMIT 1",
        [userId]
      );
      if (result.rows.length === 0) return null;
      return result.rows[0].id;
    },
  };
}
