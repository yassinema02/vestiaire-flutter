---
stepsCompleted:
  - manual-recovery
workflowType: architecture
project_name: bmad
user_name: Yassine
date: 2026-03-09
inputDocuments:
  - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md
  - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md
  - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md
  - /Users/yassine/vestiaire2.0/docs/functional-requirements.md
  - /Users/yassine/vestiaire2.0/docs/stack_recommendation.md
---

# Architecture Decision Document

## Executive Summary

Vestiaire is a mobile-first Flutter application backed by Cloud Run, Cloud SQL, Cloud Storage, Firebase Auth, Firebase Cloud Messaging, RevenueCat, and Vertex AI / Gemini 2.0 Flash. The architecture is designed around one principle: user-facing features should compose on top of a small number of stable platform capabilities rather than each feature inventing its own implementation path.

The primary implementation domains are:

- mobile client experience and local state
- authenticated API and business rules
- relational data and transactional integrity
- AI orchestration through a single provider
- async jobs, notifications, and analytics

## Project Context Analysis

### Requirements Overview

**Functional scope**

- 174 functional requirements across authentication, onboarding, wardrobe management, bulk extraction, weather/calendar context, outfit generation, analytics, gamification, shopping, social, resale, donations, and notifications.
- 13 epics define the product roadmap from MVP through growth features.
- The critical MVP path is authentication, wardrobe capture, context gathering, outfit generation, wear logging, and subscription-aware usage limits.

**Non-functional scope**

- performance targets include sub-3s cold start, sub-6s outfit generation, and sub-5s image processing
- security requires server-side secret handling, RLS, signed image URLs, rate limiting, and atomic RPC-backed mutations
- compliance requires EU residency, DSAR export, deletion, privacy policy/terms, and app-store disclosure accuracy
- reliability requires offline wardrobe browsing, daily backups, graceful AI degradation, and observability via Sentry and backend logging

**Scale and complexity**

- product domain: consumer mobile SaaS with AI-heavy workflows
- complexity level: medium-high
- major complexity drivers: multimodal AI, weather/calendar context, relational social data, premium gating, and async processing

### Cross-Cutting Concerns

- authentication and tenant scoping
- AI orchestration and fallback behavior
- media upload and secure delivery
- notification scheduling and preference enforcement
- analytics, gamification, and derived-stat recalculation
- accessibility and mobile performance

## Architectural Principles

- User-value first: implementation is organized around product capabilities, not technical silos.
- Server authority for sensitive rules: subscription gating, usage counters, badge grants, resale state changes, and deletion flows are enforced server-side.
- Single AI provider: all AI workloads route through Vertex AI / Gemini 2.0 Flash.
- Progressive enhancement: offline browsing, optimistic UI, and cached context improve UX without weakening source-of-truth guarantees.
- Explicit boundaries: mobile client, API layer, database, storage, and async integrations own different responsibilities.
- MVP scope discipline: light mode only, portrait-only mobile UX, and no home-screen widget in MVP.

## System Context

```text
Flutter Mobile App
  -> Firebase Auth for identity
  -> Cloud Run API for all business operations and AI orchestration
  -> Cloud SQL PostgreSQL for relational data
  -> Cloud Storage for private wardrobe and social images
  -> Vertex AI / Gemini for vision, generation, and structured analysis
  -> Firebase Cloud Messaging for push delivery
  -> RevenueCat for subscription state
  -> Sentry + Cloud Logging for observability
```

## Core Architectural Decisions

### Mobile Client

- Framework: Flutter.
- Target platforms: iOS 16+ primary, Android 10+ secondary.
- UX scope: portrait-only on mobile in MVP; tablet layout optimization may scale grid density but does not introduce rotation-specific behavior in MVP.
- Theming: light mode only for MVP. Dark mode is deferred.
- Navigation: canonical MVP shell is `Home`, `Wardrobe`, `Add`, `Outfits`, `Profile`. Social can be introduced post-MVP by replacing the dedicated `Add` tab with a floating action and adding a `Squads` destination when social becomes active.
- Component strategy: feature-facing wrapper widgets such as `VestiaireCard`, `VestiairePrimaryButton`, `OutfitSwipeCard`, `ContextHeader`, and `TagCloudEditor`.
- Accessibility: `Semantics`, 44x44 touch targets, text scaling support to 200%, gradient scrims over image text, and VoiceOver/TalkBack validation on core loops.

### State Management and Client Data

- Remote source of truth lives on the API and database.
- Client state is split into:
  - authenticated app/session state
  - feature state per domain module
  - short-lived view state for gestures and form flows
- Cached local data supports:
  - wardrobe browsing
  - recent weather context
  - recently used outfits and analytics snapshots
- Optimistic UI is allowed for wear logging, badge/streak feedback, reactions, and save actions, but must reconcile with server results.

### Authentication and Authorization

- Identity provider: Firebase Auth with email, Apple, and Google sign-in.
- Session tokens are stored via `flutter_secure_storage`.
- Cloud Run validates Firebase JWTs on every authenticated request.
- The API injects authenticated `user_id` into downstream operations.
- Authorization model:
  - user-owned resources are protected by Row-Level Security in PostgreSQL
  - squad membership and role checks gate social operations
  - premium capability checks happen server-side using subscription state + usage counter data

### API Architecture

- API style: JSON REST over HTTPS.
- Cloud Run acts as the only public business API.
- Responsibilities of the API layer:
  - request validation
  - auth/session enforcement
  - orchestration of AI calls
  - signed URL generation
  - transactional business logic
  - notification triggers
  - DSAR/account deletion workflows
- Error handling standard:
  - validation errors: `400`
  - unauthorized: `401`
  - forbidden/gating: `403`
  - rate limits: `429`
  - retryable upstream/AI failures: `5xx` with user-safe fallback messaging

### Data Architecture

- Primary database: Cloud SQL for PostgreSQL 16.
- Data model style: normalized relational schema with UUID primary keys, JSONB for structured AI output, and arrays where multi-value taxonomy fields are appropriate.
- Important tables:
  - `profiles`
  - `items`
  - `outfits`, `outfit_items`
  - `wear_logs`, `wear_log_items`
  - `usage_limits`
  - `user_stats`, `badges`, `user_badges`
  - `calendar_events`, `calendar_outfits`
  - `style_squads`, `squad_memberships`, `ootd_posts`, `ootd_comments`, `ootd_reactions`
  - `shopping_scans`, `shopping_wishlists`
  - `resale_listings`, `resale_history`, `donation_log`
  - `wardrobe_extraction_jobs`
  - `ai_usage_log`
- Database rules:
  - RLS on all user-facing tables
  - foreign-key cascades for deletion
  - atomic RPCs for wear counts, badge grants, premium trial grants, and usage-limit increments
  - check constraints for enumerations like `resale_status`

### Media and Storage

- Images are uploaded from the client to Cloud Storage through authenticated server-issued upload flow or signed URL orchestration.
- Stored media remains private.
- Delivery uses signed URLs with bounded TTL.
- Derived media artifacts include:
  - cleaned wardrobe item images
  - social post media
  - optional intermediate extraction outputs

### AI Orchestration

- AI provider: Vertex AI / Gemini 2.0 Flash.
- Supported AI workloads:
  - background removal
  - clothing metadata extraction
  - outfit generation
  - calendar event classification
  - shopping analysis
  - gap analysis
  - resale listing generation
- AI calls are brokered only by Cloud Run.
- Guardrails:
  - taxonomy validation on structured outputs
  - safe defaults when AI confidence is low
  - retry/backoff for upstream throttling
  - per-user logging of tokens, latency, and cost

### Notifications and Async Work

- Delivery: Firebase Cloud Messaging.
- Async use cases:
  - wear-log reminders
  - morning outfit notifications
  - formal event reminders
  - social notifications
  - monthly resale prompts
  - bulk extraction job progression
- Preference enforcement occurs server-side so disabled notifications are never sent.
- Quiet hours and notification-type toggles are modeled as profile or settings data and enforced before fanout.

### Subscription and Premium Gating

- Billing provider: RevenueCat.
- RevenueCat acts as subscription state source; Cloud Run persists an internal entitlement view for fast authorization checks.
- Gated features include outfit generation quotas, shopping scans, resale listing generation, advanced analytics, and premium trial unlocks.
- Client UI may show paywalls, but entitlement enforcement remains server-side.

### Observability and Reliability

- Client errors: Sentry Flutter SDK.
- Server telemetry: Cloud Logging and Cloud Monitoring.
- AI usage/cost telemetry: `ai_usage_log`.
- Reliability patterns:
  - idempotent server mutations where practical
  - graceful fallbacks for AI failures
  - daily automated backups
  - cached local wardrobe browsing

## Implementation Patterns and Boundaries

### Mobile App Boundary

- Owns presentation, gestures, local caching, optimistic updates, and accessibility semantics.
- Does not own billing truth, usage counters, or sensitive entitlement logic.

### API Boundary

- Owns validation, orchestration, authorization, AI calls, notification initiation, and transactional mutations.
- Does not expose provider secrets or direct database credentials to the client.

### Database Boundary

- Owns canonical relational state and transactional consistency.
- Does not embed feature-specific presentation logic.

### AI Boundary

- Owns inference and structured content generation only.
- Does not make final authorization or persistence decisions.

## Project Structure

```text
vestiaire/
├── README.md
├── .env.example
├── .github/
│   └── workflows/
│       ├── mobile-ci.yml
│       └── api-ci.yml
├── apps/
│   ├── mobile/
│   │   ├── lib/
│   │   │   ├── app/
│   │   │   ├── core/
│   │   │   │   ├── auth/
│   │   │   │   ├── config/
│   │   │   │   ├── navigation/
│   │   │   │   ├── networking/
│   │   │   │   ├── persistence/
│   │   │   │   ├── theme/
│   │   │   │   └── widgets/
│   │   │   ├── features/
│   │   │   │   ├── onboarding/
│   │   │   │   ├── wardrobe/
│   │   │   │   ├── outfits/
│   │   │   │   ├── analytics/
│   │   │   │   ├── shopping/
│   │   │   │   ├── squads/
│   │   │   │   ├── resale/
│   │   │   │   └── profile/
│   │   │   └── main.dart
│   │   └── test/
│   └── api/
│       ├── src/
│       │   ├── config/
│       │   ├── middleware/
│       │   ├── modules/
│       │   │   ├── auth/
│       │   │   ├── profiles/
│       │   │   ├── wardrobe/
│       │   │   ├── outfits/
│       │   │   ├── analytics/
│       │   │   ├── shopping/
│       │   │   ├── squads/
│       │   │   ├── resale/
│       │   │   ├── notifications/
│       │   │   └── ai/
│       │   ├── db/
│       │   ├── jobs/
│       │   └── main.ts
│       └── test/
├── packages/
│   ├── shared-types/
│   ├── ui-contracts/
│   └── lint-config/
├── infra/
│   ├── cloud-run/
│   ├── sql/
│   │   ├── migrations/
│   │   ├── policies/
│   │   └── functions/
│   └── monitoring/
└── docs/
```

## Epic-to-Component Mapping

- Epic 1 Foundation & Authentication -> `mobile/core/auth`, `api/modules/auth`, `api/modules/profiles`, `infra/sql/policies`
- Epic 2 Digital Wardrobe Core -> `mobile/features/wardrobe`, `api/modules/wardrobe`, `api/modules/ai`
- Epic 3 Context Integration -> `mobile/features/home`, `api/modules/weather`, `api/modules/calendar`, `api/modules/ai`
- Epic 4 AI Outfit Engine -> `mobile/features/outfits`, `api/modules/outfits`, `api/modules/ai`
- Epic 5 Analytics & Wear Logging -> `mobile/features/analytics`, `api/modules/analytics`, `infra/sql/functions`
- Epic 6 Gamification -> `mobile/features/profile`, `api/modules/analytics`, `api/modules/badges`
- Epic 7 Subscription & Resale -> `mobile/features/profile`, `mobile/features/resale`, `api/modules/billing`, `api/modules/resale`
- Epic 8 Shopping Assistant -> `mobile/features/shopping`, `api/modules/shopping`, `api/modules/ai`
- Epic 9 Social OOTD -> `mobile/features/squads`, `api/modules/squads`, `api/modules/notifications`
- Epic 10 Wardrobe Extraction -> `mobile/features/wardrobe`, `api/modules/ai`, `api/jobs/extraction`
- Epic 11 Advanced Analytics -> `mobile/features/analytics`, `api/modules/analytics`, `api/modules/ai`
- Epic 12 Calendar Planning & Travel -> `mobile/features/outfits`, `api/modules/calendar`, `api/modules/notifications`
- Epic 13 Circular Resale Triggers -> `mobile/features/resale`, `api/modules/resale`, `api/modules/notifications`

## Deferred Decisions

- dark mode support
- home-screen widget support
- tablet rotation-specific UX
- web or desktop surfaces
- additional AI providers

## Readiness Notes

- This document is intended to be the canonical architecture reference for implementation planning.
- If the stack changes, update this file first and then reconcile PRD, UX, and epics.
- Any future story creation or implementation planning should trace back to this architecture document for boundaries and source-of-truth decisions.
