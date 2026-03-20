function mapProfileRow(row) {
  return {
    id: row.id,
    firebaseUid: row.firebase_uid,
    email: row.email,
    authProvider: row.auth_provider,
    emailVerified: row.email_verified,
    displayName: row.display_name ?? null,
    photoUrl: row.photo_url ?? null,
    stylePreferences: row.style_preferences ?? [],
    pushToken: row.push_token ?? null,
    notificationPreferences: row.notification_preferences ?? {
      outfit_reminders: true,
      wear_logging: true,
      analytics: true,
      social: true,
    },
    onboardingCompletedAt:
      row.onboarding_completed_at?.toISOString?.() ??
      row.onboarding_completed_at ??
      null,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null
  };
}

export function createProfileRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    async getOrCreateProfile(authContext) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const insertResult = await client.query(
          `insert into app_public.profiles (
             firebase_uid,
             email,
             auth_provider,
             email_verified
           )
           values ($1, $2, $3, $4)
           on conflict (firebase_uid) do nothing
           returning *`,
          [
            authContext.userId,
            authContext.email,
            authContext.provider,
            authContext.emailVerified
          ]
        );

        if (insertResult.rows.length > 0) {
          await client.query("commit");
          return {
            profile: mapProfileRow(insertResult.rows[0]),
            created: true
          };
        }

        const selectResult = await client.query(
          `select *
             from app_public.profiles
            where firebase_uid = $1
            limit 1`,
          [authContext.userId]
        );

        await client.query("commit");

        return {
          profile: mapProfileRow(selectResult.rows[0]),
          created: false
        };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async deleteProfile(authContext) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const selectResult = await client.query(
          `select id, firebase_uid from app_public.profiles where firebase_uid = $1`,
          [authContext.userId]
        );

        if (selectResult.rows.length === 0) {
          throw new Error("Profile not found");
        }

        const { firebase_uid } = selectResult.rows[0];

        await client.query(
          `delete from app_public.profiles where firebase_uid = $1`,
          [authContext.userId]
        );

        await client.query("commit");

        return { firebaseUid: firebase_uid };
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    },

    async updateProfile(authContext, updates) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const setClauses = [];
        const params = [];
        let paramIndex = 1;

        if (updates.display_name !== undefined) {
          setClauses.push(`display_name = $${paramIndex}`);
          params.push(updates.display_name);
          paramIndex++;
        }

        if (updates.photo_url !== undefined) {
          setClauses.push(`photo_url = $${paramIndex}`);
          params.push(updates.photo_url);
          paramIndex++;
        }

        if (updates.style_preferences !== undefined) {
          setClauses.push(`style_preferences = $${paramIndex}`);
          params.push(updates.style_preferences);
          paramIndex++;
        }

        if (updates.onboarding_completed_at !== undefined) {
          setClauses.push(`onboarding_completed_at = $${paramIndex}`);
          params.push(updates.onboarding_completed_at);
          paramIndex++;
        }

        if (updates.push_token !== undefined) {
          setClauses.push(`push_token = $${paramIndex}`);
          params.push(updates.push_token);
          paramIndex++;
        }

        if (updates.notification_preferences !== undefined) {
          // Use JSONB merge operator to preserve server-added keys
          setClauses.push(`notification_preferences = notification_preferences || $${paramIndex}::jsonb`);
          params.push(JSON.stringify(updates.notification_preferences));
          paramIndex++;
        }

        if (setClauses.length === 0) {
          // Nothing to update, just fetch and return
          const selectResult = await client.query(
            `select * from app_public.profiles where firebase_uid = $1 limit 1`,
            [authContext.userId]
          );
          await client.query("commit");
          return mapProfileRow(selectResult.rows[0]);
        }

        params.push(authContext.userId);
        const result = await client.query(
          `update app_public.profiles
              set ${setClauses.join(", ")}
            where firebase_uid = $${paramIndex}
            returning *`,
          params
        );

        await client.query("commit");

        if (result.rows.length === 0) {
          throw new Error("Profile not found");
        }

        return mapProfileRow(result.rows[0]);
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }
  };
}
