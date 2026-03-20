/**
 * Squad service: business logic for squad creation, joining, and management.
 *
 * Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)
 */

import crypto from "node:crypto";

/**
 * Generate an 8-character uppercase alphanumeric invite code.
 */
export function generateInviteCode() {
  return crypto.randomBytes(6).toString("base64url").slice(0, 8).toUpperCase();
}

/**
 * Validate squad creation input.
 * @throws {{ statusCode: 400, message: string }} on validation failure.
 */
export function validateSquadInput({ name, description }) {
  if (!name || typeof name !== "string" || name.trim().length === 0) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "Name is required" };
  }
  if (name.trim().length > 50) {
    throw { statusCode: 400, code: "BAD_REQUEST", message: "Name must be at most 50 characters" };
  }
  if (description !== undefined && description !== null) {
    if (typeof description !== "string") {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "Description must be a string" };
    }
    if (description.length > 200) {
      throw { statusCode: 400, code: "BAD_REQUEST", message: "Description must be at most 200 characters" };
    }
  }
}

const MAX_SQUAD_MEMBERS = 20;
const MAX_INVITE_CODE_RETRIES = 3;

/**
 * @param {object} options
 * @param {object} options.squadRepo - Squad repository instance.
 */
export function createSquadService({ squadRepo }) {
  if (!squadRepo) {
    throw new TypeError("squadRepo is required");
  }

  return {
    /**
     * Create a new squad. The caller becomes the admin.
     */
    async createSquad(authContext, { name, description }) {
      validateSquadInput({ name, description });

      let inviteCode;
      let retries = 0;
      while (retries < MAX_INVITE_CODE_RETRIES) {
        inviteCode = generateInviteCode();
        // Check for collision
        const existing = await squadRepo.getSquadByInviteCode(inviteCode);
        if (!existing) break;
        retries++;
        if (retries >= MAX_INVITE_CODE_RETRIES) {
          throw { statusCode: 500, code: "INTERNAL_SERVER_ERROR", message: "Failed to generate unique invite code" };
        }
      }

      const squad = await squadRepo.createSquad(authContext, {
        name: name.trim(),
        description: description?.trim() ?? null,
        inviteCode,
      });

      return { squad };
    },

    /**
     * Join a squad via invite code.
     */
    async joinSquad(authContext, { inviteCode }) {
      if (!inviteCode || typeof inviteCode !== "string" || inviteCode.trim().length === 0) {
        throw { statusCode: 400, code: "BAD_REQUEST", message: "Invite code is required" };
      }

      const squad = await squadRepo.getSquadByInviteCode(inviteCode.trim().toUpperCase());
      if (!squad) {
        throw { statusCode: 404, code: "INVALID_INVITE_CODE", message: "Not Found" };
      }

      // Get the user's profile ID
      const profileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!profileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }

      // Check if already a member
      const existingMembership = await squadRepo.getMembership(squad.id, profileId);
      if (existingMembership) {
        throw { statusCode: 409, code: "ALREADY_MEMBER", message: "You are already a member of this squad" };
      }

      // Check member count
      const memberCount = await squadRepo.getSquadMemberCount(squad.id);
      if (memberCount >= MAX_SQUAD_MEMBERS) {
        throw { statusCode: 422, code: "SQUAD_FULL", message: "Squad Full" };
      }

      await squadRepo.addMember(squad.id, profileId, "member");

      return { squad };
    },

    /**
     * List all squads for the authenticated user.
     */
    async listMySquads(authContext) {
      const squads = await squadRepo.listSquadsForUser(authContext);
      return { squads };
    },

    /**
     * Get a single squad by ID.
     */
    async getSquad(authContext, { squadId }) {
      const squad = await squadRepo.getSquadById(authContext, squadId);
      if (!squad) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Squad not found" };
      }
      return { squad };
    },

    /**
     * List members of a squad.
     */
    async listMembers(authContext, { squadId }) {
      // Verify user is a member (getSquadById uses RLS)
      const squad = await squadRepo.getSquadById(authContext, squadId);
      if (!squad) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "Squad not found" };
      }

      const members = await squadRepo.listMembers(authContext, squadId);
      return { members };
    },

    /**
     * Remove a member from a squad. Only the admin can do this.
     */
    async removeMember(authContext, { squadId, memberId }) {
      // Look up caller profile
      const callerProfileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!callerProfileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }

      // Verify caller is admin
      const callerMembership = await squadRepo.getMembership(squadId, callerProfileId);
      if (!callerMembership || callerMembership.role !== "admin") {
        throw { statusCode: 403, code: "FORBIDDEN", message: "Only squad admins can remove members" };
      }

      // Cannot remove the admin
      if (memberId === callerProfileId) {
        throw { statusCode: 403, code: "FORBIDDEN", message: "Admin cannot be removed. Use leave instead." };
      }

      await squadRepo.removeMember(squadId, memberId);

      return { success: true };
    },

    /**
     * Leave a squad. If the caller is admin, transfer ownership or soft-delete.
     */
    async leaveSquad(authContext, { squadId }) {
      const callerProfileId = await squadRepo.getProfileIdForUser(authContext.userId);
      if (!callerProfileId) {
        throw { statusCode: 401, message: "Profile not found" };
      }

      const callerMembership = await squadRepo.getMembership(squadId, callerProfileId);
      if (!callerMembership) {
        throw { statusCode: 404, code: "NOT_FOUND", message: "You are not a member of this squad" };
      }

      if (callerMembership.role === "admin") {
        // Get all members to determine next owner
        const members = await squadRepo.listMembers(authContext, squadId);
        const otherMembers = members.filter(m => m.userId !== callerProfileId);

        if (otherMembers.length > 0) {
          // Transfer ownership to the oldest member (first in list, ordered by joined_at ASC)
          const nextOwner = otherMembers[0];
          await squadRepo.transferOwnership(squadId, nextOwner.userId);
        }

        // Remove caller
        await squadRepo.removeMember(squadId, callerProfileId);

        if (otherMembers.length === 0) {
          // No members left, soft-delete
          await squadRepo.softDeleteSquad(squadId);
        }
      } else {
        // Regular member just leaves
        await squadRepo.removeMember(squadId, callerProfileId);
      }

      return { success: true };
    },
  };
}
