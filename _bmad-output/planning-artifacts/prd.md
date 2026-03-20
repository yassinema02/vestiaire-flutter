---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
inputDocuments: ['docs/functional-requirements.md', 'docs/stack_recommendation.md']
workflowType: 'prd'
classification:
  projectType: mobile-app-saas
  domain: consumer-fashion-tech
  complexity: medium-high
  projectContext: greenfield
---

# Product Requirements Document — Vestiaire

**Author:** Yassine
**Date:** 2026-03-09

---

## Executive Summary

Vestiaire is an AI-powered wardrobe management platform that reduces clothing waste and decision fatigue. Users digitize their wardrobe, receive context-aware outfit suggestions (based on weather, calendar events, and personal style), and engage with sustainable fashion analytics — all through a single mobile app.

The product targets fashion-conscious individuals aged 18–35 in the UK and France. It monetizes via a freemium subscription model at £4.99/month, with AI usage limits gating free-tier access.

The tech stack is Flutter (frontend), Cloud Run + Cloud SQL + Firebase Auth (backend), and Gemini 2.0 Flash (unified AI pipeline for clothing analysis, background removal, outfit generation, and all AI features).

### What Makes This Special

**Unified AI intelligence across the entire wardrobe lifecycle.** Most wardrobe apps are digital closets — static photo storage. Vestiaire uses a single AI pipeline (Gemini 2.0 Flash) to understand clothing at a deep level (category, color, material, pattern, season, occasion), then leverages that understanding across every feature: outfit generation considers weather + calendar + wear history, shopping analysis scores items against the existing wardrobe, sustainability metrics track real behavioral impact, and social features let users share and "steal" each other's looks.

**The core insight:** Wardrobe data becomes exponentially more valuable when connected to context (weather, events, wear patterns) and analyzed by a unified AI that understands both the clothing AND the user's lifestyle.

## Project Classification

| Attribute | Value |
|-----------|-------|
| **Project Type** | Mobile App (SaaS) |
| **Domain** | Consumer Fashion Tech |
| **Complexity** | Medium-High (AI integration, social features, subscription billing, calendar/weather context) |
| **Project Context** | Greenfield — built from scratch |
| **Primary Platform** | iOS 16+ |
| **Secondary Platform** | Android (single codebase via Flutter) |

---

## Success Criteria

### User Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| Onboarding completion rate | ≥ 60% of signups complete profile + add ≥ 5 items | Analytics event tracking |
| Daily outfit suggestion engagement | ≥ 40% of DAU view the daily suggestion | App analytics |
| Wear logging consistency | ≥ 30% of MAU log ≥ 3 outfits/week | Database query on wear_logs |
| AI categorization accuracy (user-accepted) | ≥ 85% of AI-assigned metadata accepted without edit | Tracking edits post-AI-scan |
| Net Promoter Score (NPS) | ≥ 40 within 6 months of launch | In-app survey |

### Business Success

| Metric | Target | Timeline |
|--------|--------|----------|
| Monthly Active Users (MAU) | 1,000 | Month 3 post-launch |
| MAU growth | 10,000 | Month 12 |
| Free → Premium conversion rate | ≥ 5% | Month 6+ |
| Monthly recurring revenue (MRR) | £2,500+ | Month 12 (500 premium users) |
| Infrastructure cost per MAU | < £0.06 at 1K MAU, < £0.015 at 10K MAU | Ongoing |
| App Store rating | ≥ 4.5 stars | Month 6+ |
| Day-7 retention rate | ≥ 30% | Month 3+ |
| Day-30 retention rate | ≥ 15% | Month 6+ |

### Technical Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| App cold start to interactive | < 3 seconds | Performance monitoring (Sentry) |
| AI outfit generation (end-to-end) | < 6 seconds | Server-side latency tracking |
| Image upload + background removal + categorization | < 5 seconds | Server-side latency tracking |
| API 95th percentile response time | < 500ms (non-AI endpoints) | Cloud Run metrics |
| Crash-free sessions | ≥ 99.5% | Sentry crash monitoring |
| System uptime | ≥ 99.5% | Cloud Monitoring |

### Measurable Outcomes

- **Closet Safari challenge completion:** ≥ 20% of new users complete the 20-items-in-7-days challenge
- **Wardrobe digitization depth:** Average user digitizes ≥ 25 items within 30 days
- **Sustainability engagement:** ≥ 30% of premium users check their sustainability score monthly

---

## Product Scope

### MVP — Minimum Viable Product

**Epics 1–4: Core wardrobe + AI outfit engine**

| Feature Area | What's Included |
|-------------|----------------|
| **Auth & Onboarding** | Email, Apple Sign-In, Google OAuth. Profile setup, "First 5 Items" challenge |
| **Wardrobe Management** | Camera/gallery capture, AI background removal (Gemini), AI categorization, manual edit, gallery grid with filters, item detail view |
| **Weather Context** | Location permission, Open-Meteo integration, weather widget on Home, 5-day forecast |
| **AI Outfit Generation** | Daily outfit suggestion with "Why this outfit?" explanation, swipe UI, manual outfit building, wear logging, usage limits (free: 3/day) |
| **Subscription** | Free/Premium tiers, RevenueCat billing integration |

**MVP success gate:** User can digitize wardrobe items, receive AI outfit suggestions based on weather, and log what they wear.

### Growth Features (Post-MVP)

**Epics 5–9: Analytics, gamification, social, shopping**

| Feature Area | What's Included |
|-------------|----------------|
| **Wardrobe Analytics** | Cost-per-wear, neglected items, top-worn leaderboard, category distribution |
| **Gamification** | Style points, levels, streaks, badges, profile stats |
| **Resale & Circular Fashion** | AI-generated Vinted/Depop listings, resale tracking, donation logging |
| **Shopping Assistant** | Screenshot/URL product analysis, compatibility scoring, wardrobe match display |
| **Social (Style Squads)** | Private groups, OOTD posts, reactions, comments, "Steal This Look" |

### Vision (Future)

**Epics 10–13 + future:**

| Feature Area | What's Included |
|-------------|----------------|
| **AI Wardrobe Extraction** | Bulk import up to 50 photos, multi-item detection per photo |
| **Advanced Analytics 2.0** | Brand analytics, sustainability score with CO2 savings, gap analysis, seasonal reports, wear heatmap, wardrobe health score |
| **Calendar Integration** | Apple/Google Calendar sync, event classification, outfit scheduling, travel mode packing |
| **Circular Resale Triggers** | Smart resale suggestions, monthly prompts, Spring Clean declutter mode |
| **Future V3+** | Instagram wardrobe import, multi-language support, web dashboard, friend outfit challenges |

---

## User Journeys

### Journey 1: Sarah — The Morning Outfit Decision (Primary User, Happy Path)

**Sarah**, 26, London-based marketing coordinator. Her wardrobe is full but she wears the same 15 items on rotation. She's running late and stressed about what to wear.

**Opening:** Sarah wakes up at 7:15 AM. Opens Vestiaire. The Home screen shows it's 12°C with rain expected. Her Google Calendar shows a "Client Lunch at The Ivy" at 12:30 PM classified as "Formal" with formality score 8/10.

**Rising Action:** The AI has generated a daily outfit suggestion: navy blazer + white silk blouse + charcoal trousers + black leather heels. The "Why this outfit?" card explains: *"Formal enough for The Ivy (formality 8/10), rain-resistant materials, and you haven't worn the blazer in 3 weeks."* Sarah swipes through 2 alternatives, saves the first one.

**Climax:** That evening, the 8 PM reminder nudges her to log the outfit. She taps "Log Today's Outfit," selects the saved outfit, and sees her streak hit 12 days. The blazer's cost-per-wear drops from £22 to £18.

**Resolution:** Over 3 months, Sarah's wardrobe utilization goes from 18% to 62%. She discovers 8 "neglected" items she'd forgotten about and sells 3 on Vinted using AI-generated listings.

**Requirements revealed:** FR-OUT-01 through FR-OUT-11, FR-CTX-01 through FR-CTX-13, FR-LOG-01 through FR-LOG-07, FR-ANA-01 through FR-ANA-06

---

### Journey 2: Marcus — Building a Digital Wardrobe from Scratch (New User, Onboarding)

**Marcus**, 22, university student in Manchester. Interested in fashion but budget-conscious. Downloaded Vestiaire after seeing a TikTok about cost-per-wear tracking.

**Opening:** Marcus signs up with Apple Sign-In. The onboarding flow asks for his name and style preferences (casual/streetwear). He's presented with the "Closet Safari" challenge: upload 20 items in 7 days to unlock 1 month free Premium.

**Rising Action:** He photographs his first 5 items — a hoodie, two t-shirts, jeans, and trainers. The AI removes backgrounds, categorizes each item (category, color, pattern, material), and he only needs to correct one color ("navy" → "midnight blue"). After 10 items, he tries the bulk upload feature, selecting 15 more photos from his camera roll. The AI detects 18 clothing items from those photos, flags 2 duplicates, and presents them for review.

**Climax:** Day 6: he hits 23 items. The app celebrates with confetti and unlocks Premium for 30 days. He immediately checks his sustainability score (42/100 — "Room to grow!") and sees his most-worn item (a £15 Primark hoodie) has a cost-per-wear of £0.50. His £120 Nike jacket? £40 per wear. Eye-opening.

**Resolution:** Marcus becomes an active wear-logger. After his free trial, he converts to Premium because the shopping assistant saved him from a £80 jacket that scored 32/100 compatibility ("You already own 3 similar dark jackets").

**Requirements revealed:** FR-AUTH-01 through FR-AUTH-10, FR-ONB-01 through FR-ONB-05, FR-WRD-01 through FR-WRD-15, FR-EXT-01 through FR-EXT-10, FR-SHP-01 through FR-SHP-12

---

### Journey 3: Amira — The Style Squad Social Experience (Social User)

**Amira**, 28, fashion buyer in Paris. She and her 4 closest friends are obsessed with each other's outfits. She creates a Style Squad called "Les Parisiennes."

**Opening:** Amira creates the squad, adds a description, and shares the invite code via iMessage. Within a day, all 4 friends join.

**Rising Action:** Each morning, squad members post their OOTD — a photo with tagged wardrobe items and a short caption. Amira sees her friend Léa's outfit: a vintage Sézane blouse with wide-leg trousers. She taps "Steal This Look" — the AI scans Léa's outfit and finds similar items in Amira's wardrobe: "You have a similar cream blouse (85% match) and navy wide-leg trousers (72% match)."

**Climax:** The squad develops a morning ritual. Reactions (🔥) fly. Comments like "Where is that bag from?!" spark conversations. Amira's engagement streak hits 30 days — she unlocks the "Streak Legend" badge.

**Resolution:** The social pressure (positive) drives daily wear logging. All 5 squad members have wardrobe utilization above 70%. Amira discovers she can replicate most of Léa's looks with items she already owns.

**Requirements revealed:** FR-SOC-01 through FR-SOC-13, FR-NTF-01 through FR-NTF-05, FR-GAM-01 through FR-GAM-06

---

### Journey 4: Yassine — The Solo Operator (Admin/Operations)

**Yassine**, the solo developer and operator. Needs to monitor system health, manage costs, and respond to user issues.

**Opening:** Monday morning — Yassine checks the Cloud Run dashboard. API latency is healthy at p95 = 320ms. Vertex AI costs for the week: £12 across 4,200 Gemini calls. Cloud SQL CPU sits at 8%.

**Rising Action:** A user reports that background removal failed on a photo. Yassine checks the `ai_usage_log` table — the Gemini call returned a 429 (rate limited). He adjusts the retry logic in the Cloud Run API to add exponential backoff.

**Climax:** Monthly cost review: £28 total for 800 MAU. Well under the £60 target. The GCP billing alert he set at £50 hasn't triggered. Firebase Auth shows 812 registered users with a 68% monthly return rate.

**Resolution:** Yassine pushes a new feature (seasonal reports) via Cloud Build → Cloud Run. Zero downtime deployment. He verifies the rollout in Sentry — no new errors in the first hour.

**Requirements revealed:** NFR-OBS-01 through NFR-OBS-03, NFR-SCL-01 through NFR-SCL-06, NFR-REL-01 through NFR-REL-04

---

### Journey Requirements Summary

| Journey | Primary Capabilities Revealed |
|---------|------------------------------|
| Sarah (Outfit Decision) | Weather integration, calendar context, AI outfit generation, wear logging, analytics |
| Marcus (New User) | Authentication, onboarding, wardrobe scanning, AI categorization, bulk import, gamification |
| Amira (Social) | Style Squads, OOTD posting, reactions/comments, "Steal This Look," social notifications |
| Yassine (Operations) | Cost monitoring, error investigation, deployment, AI usage tracking |

---

## Domain Requirements

### Consumer SaaS — Fashion Tech

| Requirement | Implementation |
|-------------|---------------|
| **GDPR compliance** | EU data residency (GCP europe-west1/west2), right to access/erasure/rectification, privacy policy |
| **App Store compliance** | Privacy nutrition labels, terms of service, age rating 4+ |
| **Payment compliance** | Apple In-App Purchase via RevenueCat (Apple requires IAP for digital subscriptions) |
| **Image privacy** | All wardrobe photos stored in private buckets with signed URLs (1-hour TTL) |
| **Account deletion** | Full cascading delete: auth record + profile + items + outfits + images + all related data |
| **Data minimization** | Only collect data necessary for app functionality; no third-party tracking |
| **Content moderation** | Social OOTD posts — future consideration for reporting/blocking mechanisms |

### Domain Complexity: Medium-High

- **AI integration complexity:** Single provider (Gemini) but multiple use cases (vision, text generation, image editing)
- **Real-time context:** Weather API polling + calendar sync + time-of-day awareness
- **Social features:** Group management, real-time feed, reactions, comments
- **Subscription management:** IAP integration, usage metering, trial management
- **Multi-platform:** iOS + Android from single Flutter codebase

---

## Innovation Analysis

### Competitive Landscape

| Competitor | What They Do | Vestiaire Differentiator |
|-----------|-------------|------------------------|
| **Cladwell** | Basic outfit suggestions from digitized wardrobe | No weather/calendar context, no social features, no AI-powered analysis |
| **Acloset** | Digital closet + basic outfit creation | Manual outfit creation only, no AI, no sustainability metrics |
| **Stylebook** | iOS wardrobe app with manual categorization | No AI categorization, no context-aware suggestions, no social |
| **Whering** | AI wardrobe + outfit suggestions | Limited AI pipeline, no unified Gemini approach, no shopping assistant |
| **Smart Closet** | Cross-platform closet organizer | Basic features, no AI depth, no gamification, no social squads |

### Key Differentiators

1. **Unified AI pipeline** — Single Gemini model handles background removal, categorization, outfit generation, shopping analysis, and listing generation. Competitors use fragmented API stacks.
2. **Context-aware intelligence** — Weather + calendar + wear history + wardrobe data feed into every AI decision. Not just "what matches" but "what's right for today."
3. **Closed-loop sustainability** — Track not just what you own, but how you wear it, what you sell, what you donate, and the environmental impact. Competitors offer static closet management.
4. **Social styling (Style Squads)** — Private group OOTD sharing with "Steal This Look" is unique. Turns personal wardrobe management into a social experience.
5. **Shopping intelligence** — Before-you-buy analysis with compatibility scoring is a defensible moat that gets stronger with more wardrobe data.

---

## Project-Type Requirements

### Mobile App (iOS + Android via Flutter)

| Requirement | Specification |
|-------------|---------------|
| **Minimum iOS version** | iOS 16+ |
| **Android support** | Android 10+ (API 29+) |
| **Orientation** | Portrait only for MVP |
| **Offline support** | Wardrobe browsing via cached data; AI features require network |
| **Camera access** | Required for wardrobe item capture and OOTD photos |
| **Location access** | Required for weather (foreground only) |
| **Calendar access** | Optional — for event-based outfit suggestions |
| **Push notifications** | Firebase Cloud Messaging (APNs on iOS, FCM on Android) |
| **Secure storage** | flutter_secure_storage for tokens and sensitive data |
| **Deep linking** | Squad invite codes via universal links |
| **App size target** | < 50 MB initial download |
| **Accessibility** | WCAG AA compliance for core user flows |

### SaaS Subscription

| Requirement | Specification |
|-------------|---------------|
| **Billing provider** | RevenueCat (manages App Store + Play Store subscriptions) |
| **Free tier** | Core features with usage limits (3 AI suggestions/day, 3 shopping scans/day, 2 resale listings/month) |
| **Premium tier** | £4.99/month — unlimited AI, all analytics, squad creation, unlimited shopping scans |
| **Trial** | 30-day free Premium via "Closet Safari" challenge completion |
| **Server-side enforcement** | All usage limits checked via Cloud Run API (not client-side) |

---

## Functional Requirements

> [!NOTE]
> Full functional requirements (149 FRs across 23 feature areas) are documented in
> [functional-requirements.md](file:///Users/yassine/vestiaire2.0/docs/functional-requirements.md).
> This section provides the prioritized summary by feature area.

### Priority Breakdown

| Priority | Count | Description |
|----------|-------|-------------|
| **P0** | 42 | Must-have for MVP launch |
| **P1** | 74 | Growth features, post-MVP |
| **P2** | 33 | Vision/future features |

### P0 Requirements by Feature Area

| Feature Area | Key P0 Requirements |
|-------------|-------------------|
| **Authentication** | Email/Apple/Google sign-in, secure session storage, token refresh, account deletion (GDPR) |
| **Wardrobe Management** | Camera/gallery capture, image compression, cloud storage, AI background removal (Gemini), AI categorization, manual edit, gallery grid, item detail, delete |
| **Weather Context** | Location permission, Open-Meteo integration, weather widget, context object for AI |
| **AI Outfit Generation** | Gemini-powered suggestions (weather + calendar + wardrobe + wear history), swipe UI, manual outfit building, usage limits |
| **Wear Logging** | Log daily outfits, select items or outfit, atomic wear count increment |
| **Analytics** | Total items, wardrobe value, average cost-per-wear, category distribution |
| **Subscription** | Free/Premium tier enforcement, server-side usage limits |
| **Push Notifications** | FCM permission request, push token storage |
| **Data Integrity** | RLS on all tables, server-side atomic RPCs, UUID primary keys, FK cascades |

### Full FR Reference

All 149 functional requirements with IDs (FR-AUTH-01 through FR-PSH-06) are maintained in the [Functional Requirements Document](file:///Users/yassine/vestiaire2.0/docs/functional-requirements.md), organized by feature area with priority levels and detailed specifications.

---

## Non-Functional Requirements

### Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-PERF-01 | Image upload + background removal + categorization | < 5 seconds |
| NFR-PERF-02 | AI outfit generation (end-to-end) | < 6 seconds |
| NFR-PERF-03 | Screenshot product analysis | < 5 seconds |
| NFR-PERF-04 | URL scraping and analysis | < 8 seconds |
| NFR-PERF-05 | Bulk photo extraction (20 photos) | < 2 minutes |
| NFR-PERF-06 | OOTD feed load time | < 2 seconds |
| NFR-PERF-07 | Wardrobe gallery initial render | < 1 second |
| NFR-PERF-08 | App cold start to interactive | < 3 seconds |
| NFR-PERF-09 | Compatibility scoring algorithm | Scales to 500+ item wardrobes |

### Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-REL-01 | System uptime | ≥ 99.5% |
| NFR-REL-02 | Database backup frequency | Daily automated (Cloud SQL) |
| NFR-REL-03 | AI service degradation | Graceful fallback (cached data or manual input) |
| NFR-REL-04 | Offline capability | Wardrobe browsing via cached data |

### Security

| ID | Requirement |
|----|-------------|
| NFR-SEC-01 | All API keys (Gemini, Vertex AI) stored server-side only |
| NFR-SEC-02 | All tables enforce RLS scoped to authenticated user |
| NFR-SEC-03 | Session tokens stored in iOS Keychain via flutter_secure_storage |
| NFR-SEC-04 | Wardrobe images served via signed URLs with 1-hour TTL |
| NFR-SEC-05 | AI endpoints enforce rate limiting (free: 3/day, premium: 50/day) with 429 responses |
| NFR-SEC-06 | All sensitive operations use atomic server-side RPCs |

### Scalability

| Scale | Target MAU | Infrastructure Budget |
|-------|------------|----------------------|
| Launch | 1,000 MAU | < £60/month |
| Growth | 10,000 MAU | < £300/month |
| Scale | 100,000 MAU | < £2,000/month |

### Compliance

| Requirement | Detail |
|-------------|--------|
| GDPR data residency | GCP europe-west1 or europe-west2 |
| Right to access (DSAR) | JSON export via Cloud Run API |
| Right to erasure | Cascading delete of all user data |
| App Store privacy labels | Accurately reflect data collection |
| Age rating | 4+ (no objectionable content) |

### Observability

| Requirement | Detail |
|-------------|--------|
| Client-side error monitoring | Sentry (Flutter SDK) |
| AI cost tracking | Per-user logging in `ai_usage_log` (model, tokens, latency, cost) |
| Server-side logging | Cloud Run logs via Cloud Logging |

---

## Tech Stack Reference

Full stack recommendation with architecture diagrams, cost projections, and technology justifications is maintained in [stack_recommendation.md](file:///Users/yassine/vestiaire2.0/docs/stack_recommendation.md).

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart) — AOT compiled, 60/120fps |
| Auth | Firebase Auth — Apple/Google/Email |
| API Server | Cloud Run (Node.js 22 or FastAPI) |
| Database | Cloud SQL for PostgreSQL 16 |
| Storage | Cloud Storage — CDN-backed, signed URLs |
| AI (All Features) | Vertex AI → Gemini 2.0 Flash |
| Push | Firebase Cloud Messaging |
| Billing | RevenueCat (Flutter SDK) |
| Error Monitoring | Sentry (Flutter SDK) |
| Weather | Open-Meteo (free) |
| CI/CD | GitHub Actions + Cloud Build |

---

## Data Model Reference

22 PostgreSQL tables with RLS, UUID primary keys, JSONB for flexible metadata, TEXT[] arrays for multi-value fields. Full schema documented in [functional-requirements.md §7](file:///Users/yassine/vestiaire2.0/docs/functional-requirements.md).

Key tables: `profiles`, `items`, `outfits`, `outfit_items`, `wear_logs`, `wear_log_items`, `user_stats`, `badges`, `user_badges`, `resale_listings`, `resale_history`, `usage_limits`, `style_squads`, `squad_memberships`, `ootd_posts`, `ootd_comments`, `ootd_reactions`, `shopping_scans`, `shopping_wishlists`, `calendar_events`, `calendar_outfits`, `wardrobe_extraction_jobs`, `donation_log`, `ai_usage_log`.

---

## Document Traceability

```
PRD (this document)
 ├── Executive Summary → Vision & differentiator
 ├── Success Criteria → Measurable outcomes for UX, business, technical
 ├── Product Scope → MVP / Growth / Vision phasing
 ├── User Journeys → 4 narrative journeys covering primary, onboarding, social, operations
 ├── Domain Requirements → GDPR, App Store, payment compliance
 ├── Innovation Analysis → Competitive landscape & differentiators
 ├── Project-Type Requirements → Mobile + SaaS specifics
 ├── Functional Requirements → 149 FRs (→ functional-requirements.md)
 └── Non-Functional Requirements → 38 NFRs (performance, reliability, security, compliance, scalability, accessibility/platform, observability)

Downstream:
 PRD → UX Design (user journeys → interaction flows)
 PRD → Architecture (FRs → system capabilities, NFRs → architecture decisions)
 PRD → Epics & Stories (FRs → user stories, scope → sprint sequencing)
```

---

**Document Status:** Complete
**Version:** 1.0
**Generated:** 2026-03-09
**Source:** Functional Requirements Document, Stack Recommendation, Architecture, and product analysis
