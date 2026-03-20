# Vestiaire — Functional Requirements Document

**Version:** 1.0
**Date:** 2026-03-08
**Status:** Complete
**Scope:** All implemented and specified features (V1 + V2)

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [User Roles & Personas](#2-user-roles--personas)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [Epic & Feature Map](#5-epic--feature-map)
6. [Detailed Feature Specifications](#6-detailed-feature-specifications)
7. [Data Model Summary](#7-data-model-summary)
8. [Integration Points](#8-integration-points)
9. [Subscription & Monetization](#9-subscription--monetization)
10. [Compliance & Privacy](#10-compliance--privacy)

---

## 1. Product Overview

**Vestiaire** is an iOS-first mobile application that combines AI-powered wardrobe management, outfit generation, social styling, and sustainable fashion intelligence into a single consumer SaaS product.

**Core value proposition:** Reduce clothing waste and decision fatigue by giving users a smart, context-aware digital wardrobe that suggests outfits, analyzes shopping decisions, and encourages sustainable consumption.

**Target users:** Fashion-conscious individuals aged 18–35, primarily in the UK and France.

**Business model:** Freemium — free tier with usage limits, premium tier at £4.99/month.

---

## 2. User Roles & Personas

| Role | Description |
|------|-------------|
| **Free User** | Basic access: wardrobe management, 3 AI suggestions/day, 2 resale listings/month |
| **Premium User** | Unlimited AI suggestions, advanced analytics, sustainability score, priority features |
| **Squad Admin** | Creator/manager of a Style Squad (social group); can invite/remove members |
| **Squad Member** | Participant in one or more Style Squads; can post, react, comment |

---

## 3. Functional Requirements

### 3.1 Authentication & Account Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-AUTH-01 | Users shall register via email and password with email verification | P0 |
| FR-AUTH-02 | Users shall sign in via Apple Sign-In (iOS native) | P0 |
| FR-AUTH-03 | Users shall sign in via Google OAuth | P0 |
| FR-AUTH-04 | Users shall be able to reset their password via email link | P0 |
| FR-AUTH-05 | The system shall persist authenticated sessions securely using device keychain (flutter_secure_storage) | P0 |
| FR-AUTH-06 | Users shall be able to sign out, clearing all session data from the device | P0 |
| FR-AUTH-07 | The system shall automatically refresh expired access tokens using stored refresh tokens | P0 |
| FR-AUTH-08 | Users shall be able to update their display name and profile photo | P1 |
| FR-AUTH-09 | Users shall be able to delete their account and all associated data (GDPR right to erasure) | P0 |
| FR-AUTH-10 | The system shall create a `profiles` record automatically upon user registration via Cloud Run API (on first login → create profile row in Cloud SQL) | P0 |

### 3.2 Onboarding

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ONB-01 | New users shall be guided through a profile setup flow (name, style preferences, photo) | P1 |
| FR-ONB-02 | The system shall present a "First 5 Items" challenge encouraging users to add 5 wardrobe items | P1 |
| FR-ONB-03 | The system shall present a "Closet Safari" 7-day challenge: upload 20 items to unlock 1 month Premium free | P1 |
| FR-ONB-04 | Completing the Closet Safari challenge shall automatically grant a 30-day Premium trial | P1 |
| FR-ONB-05 | Users shall be able to skip onboarding and access the app directly | P1 |

### 3.3 Wardrobe Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-WRD-01 | Users shall add wardrobe items by capturing a photo via camera or selecting from gallery | P0 |
| FR-WRD-02 | The system shall compress uploaded images to ≤ 512px width at 85% JPEG quality before upload | P0 |
| FR-WRD-03 | Uploaded images shall be stored in a private cloud storage bucket scoped to the user's ID | P0 |
| FR-WRD-04 | The system shall automatically remove image backgrounds via Gemini 2.0 Flash image editing (server-side via Cloud Run) | P0 |
| FR-WRD-05 | The system shall auto-categorize items using Gemini 2.0 Flash vision analysis, extracting: category, color, secondary colors, pattern, material, style, season suitability, and occasion tags | P0 |
| FR-WRD-06 | AI categorization results shall be validated against a fixed taxonomy (valid categories, colors, patterns) with fallback to safe defaults | P0 |
| FR-WRD-07 | Users shall be able to manually edit all AI-assigned metadata for any item | P0 |
| FR-WRD-08 | Users shall enter optional metadata: item name, brand, purchase price, purchase date, currency | P1 |
| FR-WRD-09 | Users shall view their wardrobe in a scrollable gallery grid | P0 |
| FR-WRD-10 | The wardrobe gallery shall support filtering by: category, color, season, occasion, brand, neglect status, resale status | P0 |
| FR-WRD-11 | Users shall tap an item to view its detail screen showing: image, all metadata, wear count, cost-per-wear, last worn date, wear history | P0 |
| FR-WRD-12 | Users shall be able to delete items from their wardrobe | P0 |
| FR-WRD-13 | Users shall be able to favorite items for quick access | P1 |
| FR-WRD-14 | The system shall track `neglect_status` for items not worn in a configurable number of days (default: 180) | P1 |
| FR-WRD-15 | The system shall display a "Neglected" badge on items exceeding the neglect threshold | P1 |

### 3.4 AI Wardrobe Extraction (Bulk Import)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-EXT-01 | Users shall bulk-upload up to 50 photos from their gallery for AI extraction | P1 |
| FR-EXT-02 | The system shall detect multiple clothing items within a single photo (up to 5 items per photo) | P1 |
| FR-EXT-03 | Each detected item shall be auto-categorized with category, color, style, material, and pattern | P1 |
| FR-EXT-04 | Background removal shall be applied to each extracted item | P1 |
| FR-EXT-05 | Users shall review all extracted items in a confirmation screen before adding to wardrobe | P1 |
| FR-EXT-06 | Each extracted item shall have Keep/Remove toggles and editable metadata | P1 |
| FR-EXT-07 | The system shall display extraction progress with status updates and estimated time remaining | P1 |
| FR-EXT-08 | Extraction jobs shall be tracked in a `wardrobe_extraction_jobs` table with status progression | P1 |
| FR-EXT-09 | Items created via extraction shall be tagged with `creation_method = 'ai_extraction'` and linked to the source photo | P1 |
| FR-EXT-10 | The system shall detect potential duplicate items during extraction and warn the user | P2 |

### 3.5 Context Integration (Weather & Calendar)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-CTX-01 | The system shall request location permission and display current weather on the Home screen | P0 |
| FR-CTX-02 | Weather data shall be fetched from Open-Meteo API (free, no API key) | P0 |
| FR-CTX-03 | The weather widget shall show: temperature, "feels like", condition icon, and location name | P0 |
| FR-CTX-04 | Weather data shall be cached for 30 minutes with local persistence (shared_preferences or Hive) | P1 |
| FR-CTX-05 | The system shall display a 5-day weather forecast | P1 |
| FR-CTX-06 | The system shall map weather conditions to clothing recommendations (e.g., rain → waterproof outerwear) | P1 |
| FR-CTX-07 | Users shall connect their device Calendar to the app with permission explanation (device_calendar plugin) | P1 |
| FR-CTX-08 | Users shall select which calendars to sync (work, personal, etc.) | P1 |
| FR-CTX-09 | The system shall fetch and store events for today and the next 7 days in `calendar_events` | P1 |
| FR-CTX-10 | The system shall classify calendar events by type using keyword detection and AI fallback: Work, Social, Active, Formal, Casual | P1 |
| FR-CTX-11 | Each classified event shall receive a formality score (1-10) | P1 |
| FR-CTX-12 | Users shall be able to re-classify events if the AI classification is incorrect | P2 |
| FR-CTX-13 | The system shall compile a context object (weather + events + date + day-of-week) for AI outfit generation | P0 |

### 3.6 AI Outfit Generation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-OUT-01 | The system shall generate outfit suggestions using Gemini AI, considering: wardrobe items, weather, calendar events, user preferences, and wear history | P0 |
| FR-OUT-02 | Generated outfits shall be stored in the `outfits` table with linked items in `outfit_items` | P0 |
| FR-OUT-03 | The Home screen shall display the primary daily outfit suggestion with a "Why this outfit?" explanation | P0 |
| FR-OUT-04 | Users shall swipe through multiple outfit suggestions (swipe right to save, left to skip) | P0 |
| FR-OUT-05 | Users shall be able to manually build outfits by selecting items from categorized lists | P0 |
| FR-OUT-06 | Users shall view their outfit history with filters: AI-generated vs manual, occasion, season, date range | P1 |
| FR-OUT-07 | Users shall favorite outfits for quick access | P1 |
| FR-OUT-08 | Users shall be able to delete outfits from their history | P1 |
| FR-OUT-09 | Free users shall be limited to 3 AI outfit generations per day | P0 |
| FR-OUT-10 | Premium users shall have unlimited AI outfit generations | P0 |
| FR-OUT-11 | The system shall avoid suggesting recently worn items unless the wardrobe is small | P1 |

### 3.7 Event-Based Outfit Planning

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-EVT-01 | The Home screen shall display upcoming events with classified type and formality | P1 |
| FR-EVT-02 | The system shall generate event-specific outfit suggestions considering formality, time of day, and weather | P1 |
| FR-EVT-03 | Users shall schedule outfits for future days via a "Plan Week" 7-day calendar view | P1 |
| FR-EVT-04 | Each day in the planner shall show events and weather preview | P1 |
| FR-EVT-05 | Scheduled outfits shall be stored in `calendar_outfits` with event association | P1 |
| FR-EVT-06 | Users shall edit or remove scheduled outfits | P1 |
| FR-EVT-07 | The system shall send evening reminders before formal events with preparation tips (e.g., "Don't forget to iron your shirt") | P2 |
| FR-EVT-08 | Event reminders shall be configurable: timing, event types, snooze/dismiss | P2 |

### 3.8 Travel Mode & Packing

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-TRV-01 | The system shall detect multi-day trip events from the calendar | P2 |
| FR-TRV-02 | The system shall generate packing suggestions based on trip duration, destination weather, and planned events | P2 |
| FR-TRV-03 | Users shall view a checklist interface to mark items as packed | P2 |
| FR-TRV-04 | Users shall export the packing list to a notes or reminder app | P2 |
| FR-TRV-05 | A travel banner shall appear on the Home screen when an upcoming trip is detected | P2 |

### 3.9 Wear Logging & Tracking

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-LOG-01 | Users shall log outfits worn today via a "Log Today's Outfit" flow on the Home screen | P0 |
| FR-LOG-02 | Logging shall support selecting individual items or a previously saved outfit | P0 |
| FR-LOG-03 | Multiple wear logs per day shall be supported | P1 |
| FR-LOG-04 | Each wear log shall record: date, items worn, and optional photo | P0 |
| FR-LOG-05 | Wear count on each item shall be incremented atomically via database RPC to prevent race conditions | P0 |
| FR-LOG-06 | The system shall send an evening reminder notification (default 8 PM, user-configurable) to log the day's outfit | P1 |
| FR-LOG-07 | Wear logs shall be viewable in a monthly calendar view with daily activity indicators | P1 |

### 3.10 Wardrobe Analytics

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-ANA-01 | The analytics dashboard shall display: total items, total wardrobe value, average cost-per-wear, and category distribution | P0 |
| FR-ANA-02 | Cost-per-wear (CPW) shall be calculated as purchase_price / wear_count, color-coded: green (< £5), yellow (£5–20), red (> £20) | P0 |
| FR-ANA-03 | The system shall identify neglected items (not worn in 60+ days, configurable) and display them in a dedicated section | P1 |
| FR-ANA-04 | The system shall display a "Top 10 Most Worn Items" leaderboard with time period filters | P1 |
| FR-ANA-05 | The system shall display a wear frequency bar chart and category distribution pie chart | P1 |
| FR-ANA-06 | The system shall provide AI-generated wardrobe insights (summary text) | P1 |

### 3.11 Brand & Cost Analytics (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-BRD-01 | The analytics dashboard shall include a "Brand Value" section showing: brand name, average CPW, total spent, and total wears, ranked by best value | P1 |
| FR-BRD-02 | Brand analytics shall be filterable by category (e.g., "Best value sneakers brand") | P2 |
| FR-BRD-03 | Brands shall only appear with a minimum of 3 items | P2 |

### 3.12 Sustainability & Environmental Analytics (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-SUS-01 | The system shall calculate a sustainability score (0–100) based on 5 weighted factors: avg wear count (30%), % wardrobe worn in 90 days (25%), avg CPW (20%), resale activity (15%), new purchases avoided (10%) | P1 |
| FR-SUS-02 | The system shall estimate CO2 savings from re-wearing vs buying new | P1 |
| FR-SUS-03 | The sustainability score shall be displayed with color gradient and leaf icon | P1 |
| FR-SUS-04 | Users shall see a percentile comparison: "Top X% of Vestiaire users" | P2 |
| FR-SUS-05 | An "Eco Warrior" badge shall unlock at sustainability score ≥ 80 | P1 |

### 3.13 Wardrobe Gap Analysis (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-GAP-01 | The system shall analyze the wardrobe for missing item types by category, formality, color range, and weather coverage | P1 |
| FR-GAP-02 | Each detected gap shall be rated: Critical, Important, or Optional | P1 |
| FR-GAP-03 | Gap suggestions shall include specific item recommendations (e.g., "Consider adding a beige trench coat") | P1 |
| FR-GAP-04 | Users shall be able to dismiss individual gaps | P2 |
| FR-GAP-05 | AI-enriched gap analysis shall use Gemini for personalized recommendations beyond basic rule detection | P2 |
| FR-GAP-06 | Gap results shall be cached locally and refresh when wardrobe changes | P2 |

### 3.14 Seasonal Reports (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-SEA-01 | The system shall generate seasonal wardrobe reports (Spring, Summer, Fall, Winter) | P2 |
| FR-SEA-02 | Each report shall show: item count per season, most worn items, neglected items, and seasonal readiness score (1–10) | P2 |
| FR-SEA-03 | Reports shall include historical comparison (e.g., "This winter you wore 12% more items than last") | P2 |
| FR-SEA-04 | Seasonal transition alerts shall notify users 2 weeks before a new season | P2 |

### 3.15 Wear Frequency Heatmap (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-HMP-01 | The system shall display a calendar heatmap showing daily wear activity with color intensity proportional to items worn | P2 |
| FR-HMP-02 | The heatmap shall support view modes: Month, Quarter, Year | P2 |
| FR-HMP-03 | Users shall tap a day to see a detail overlay with outfits worn that day | P2 |
| FR-HMP-04 | The heatmap shall display streak tracking and streak statistics | P2 |

### 3.16 Wardrobe Health Score (V2)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-HLT-01 | The system shall calculate a wardrobe health score (0–100) based on 3 weighted factors: % items worn in 90 days (50%), % items with < £5 CPW (30%), size vs utilization ratio (20%) | P1 |
| FR-HLT-02 | The health score shall be color-coded: Green (80–100), Yellow (50–79), Red (< 50) | P1 |
| FR-HLT-03 | The score shall include recommendations (e.g., "Declutter 8 items to improve health") | P1 |
| FR-HLT-04 | A deterministic user comparison shall show percentile ranking | P2 |
| FR-HLT-05 | A "Spring Clean" guided declutter mode shall walk users through neglected items with keep/sell/donate options | P2 |

### 3.17 Gamification

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-GAM-01 | Users shall earn style points for actions: upload item (+10), log outfit (+5), streak day (+3), first log of day (+2) | P1 |
| FR-GAM-02 | The system shall track 6 user levels based on wardrobe item count thresholds: Closet Rookie (0), Style Starter (10), Fashion Explorer (25), Wardrobe Pro (50), Style Expert (100), Style Master (200) | P1 |
| FR-GAM-03 | The system shall track consecutive-day streaks for outfit logging, with 1 streak freeze per week | P1 |
| FR-GAM-04 | The system shall award badges for achievements, including: First Step, Closet Complete, Week Warrior, Streak Legend (30 days), Early Bird, Rewear Champion (50 re-wears), Circular Seller (1+ listing), Circular Champion (10+ sold), Generous Giver (20+ donated), Monochrome Master, Rainbow Warrior, OG Member, Weather Warrior, Style Guru, Eco Warrior | P1 |
| FR-GAM-05 | The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed | P1 |
| FR-GAM-06 | Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`) | P0 |

### 3.18 Shopping Assistant

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-SHP-01 | Users shall analyze potential purchases by uploading a screenshot from gallery or camera | P1 |
| FR-SHP-02 | Users shall analyze potential purchases by pasting a product URL | P1 |
| FR-SHP-03 | URL scraping shall extract product data using Open Graph meta tags and schema.org JSON-LD markup, with fallback to screenshot analysis | P1 |
| FR-SHP-04 | The system shall extract structured product data: name, category, color, secondary colors, style, material, pattern, season, formality score (1–10), brand, price | P1 |
| FR-SHP-05 | Users shall confirm or edit AI-extracted product data before scoring | P1 |
| FR-SHP-06 | The system shall calculate a compatibility score (0–100) based on: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%) | P1 |
| FR-SHP-07 | The compatibility score shall be displayed with a 5-tier rating system: Perfect Match (90–100), Great Choice (75–89), Good Fit (60–74), Might Work (40–59), Careful (0–39), each with distinct color and icon | P1 |
| FR-SHP-08 | The system shall display top matching items from the user's wardrobe, grouped by category, with match reasons | P1 |
| FR-SHP-09 | The system shall generate 3 AI-powered insights per scan: style feedback, wardrobe gap assessment, and value proposition | P1 |
| FR-SHP-10 | Users shall save scanned products to a shopping wishlist with score, matches, and insights | P2 |
| FR-SHP-11 | Scanned products shall be stored in `shopping_scans` for history and re-analysis | P1 |
| FR-SHP-12 | The system shall display an empty wardrobe CTA when no items exist for scoring | P2 |

### 3.19 Social — Style Squads & OOTD

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-SOC-01 | Users shall create Style Squads (private groups) with a name, optional description, and unique invite code | P1 |
| FR-SOC-02 | Users shall invite others to squads via invite code, SMS, or username search | P1 |
| FR-SOC-03 | Squad size shall be limited to 20 members | P1 |
| FR-SOC-04 | Users shall belong to multiple squads simultaneously | P1 |
| FR-SOC-05 | Squad admins shall be able to remove members | P1 |
| FR-SOC-06 | Users shall post OOTD (Outfit of the Day) photos to selected squads with optional caption (max 150 chars) and tagged wardrobe items | P1 |
| FR-SOC-07 | The Social tab shall display a chronological feed of OOTD posts from all joined squads | P1 |
| FR-SOC-08 | Users shall filter the feed by specific squad | P2 |
| FR-SOC-09 | Users shall react to posts with a fire emoji (🔥) toggle with reaction count display | P1 |
| FR-SOC-10 | Users shall comment on posts (text only, max 200 chars) with notification to post author | P1 |
| FR-SOC-11 | Post authors shall delete any comment on their post; users shall delete their own comments | P1 |
| FR-SOC-12 | Users shall use "Steal This Look" on any OOTD post to find similar items in their own wardrobe, with AI-powered matching and fallback | P1 |
| FR-SOC-13 | "Steal This Look" results shall be color-coded by match quality and saveable as a new outfit | P2 |

### 3.20 Social Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-NTF-01 | Users shall receive push notifications when a squad member posts an OOTD | P2 |
| FR-NTF-02 | Notification settings shall support: All posts, Only morning posts, Off | P2 |
| FR-NTF-03 | Quiet hours shall be respected (default: 10 PM – 7 AM) with configurable daily notification limit | P2 |
| FR-NTF-04 | Users shall receive an optional daily posting reminder (default 9 AM, user-configurable) | P2 |
| FR-NTF-05 | The posting reminder shall be skipped if the user has already posted today | P2 |

### 3.21 Resale & Circular Fashion

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-RSL-01 | The system shall identify resale candidates based on: not worn in 90+ days, high CPW, and low wear count relative to age | P1 |
| FR-RSL-02 | The system shall generate AI-powered resale listings optimized for Vinted/Depop, including: title, description, category, condition estimate, with CPW and sustainability data | P1 |
| FR-RSL-03 | Users shall copy listing text to clipboard or share via system share sheet | P1 |
| FR-RSL-04 | Items shall track `resale_status` with CHECK constraint: 'listed', 'sold', 'donated', or NULL | P0 |
| FR-RSL-05 | The system shall send monthly resale prompt notifications for neglected items with estimated sale price | P2 |
| FR-RSL-06 | Users shall dismiss resale prompts per-item ("I'll keep it") or globally via settings | P2 |
| FR-RSL-07 | Users shall view resale history on their profile showing items listed, sold, and total earnings | P1 |
| FR-RSL-08 | An earnings chart shall display monthly earnings over time | P2 |
| FR-RSL-09 | Selling 10+ items shall unlock the "Circular Champion" badge | P1 |
| FR-RSL-10 | Resale status changes (listed → sold) shall sync back to the `items` table | P1 |

### 3.22 Donation Tracking

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-DON-01 | Users shall mark items as "Donated" from the item detail screen | P2 |
| FR-DON-02 | Donations shall be logged in `donation_log` with: item reference, charity/organization, date, estimated value | P2 |
| FR-DON-03 | Users shall view donation history on their profile | P2 |
| FR-DON-04 | Donating 20+ items shall unlock the "Generous Giver" badge | P2 |
| FR-DON-05 | The Spring Clean guided declutter flow shall log donations automatically | P2 |

### 3.23 Push Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-PSH-01 | The system shall request push notification permission via Firebase Cloud Messaging (FCM) | P0 |
| FR-PSH-02 | Push tokens shall be stored in the `profiles` table | P0 |
| FR-PSH-03 | Evening wear-log reminders shall be sent at user-configurable time (default 8 PM) | P1 |
| FR-PSH-04 | Morning outfit suggestion notifications shall include weather preview | P2 |
| FR-PSH-05 | Event-based outfit reminders shall fire the evening before formal events | P2 |
| FR-PSH-06 | All notification types shall be independently toggleable in settings | P1 |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-PERF-01 | Image upload and background removal | < 5 seconds |
| NFR-PERF-02 | AI outfit generation (end-to-end) | < 6 seconds |
| NFR-PERF-03 | Screenshot product analysis | < 5 seconds |
| NFR-PERF-04 | URL scraping and analysis | < 8 seconds |
| NFR-PERF-05 | Bulk photo extraction (20 photos) | < 2 minutes |
| NFR-PERF-06 | OOTD feed load time | < 2 seconds |
| NFR-PERF-07 | Wardrobe gallery initial render | < 1 second |
| NFR-PERF-08 | App cold start to interactive | < 3 seconds |
| NFR-PERF-09 | Compatibility scoring algorithm | Must scale to 500+ item wardrobes |

### 4.2 Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-REL-01 | System uptime | ≥ 99.5% |
| NFR-REL-02 | Database backup frequency | Daily automated |
| NFR-REL-03 | AI service degradation | Graceful fallback (show cached data or manual input) |
| NFR-REL-04 | Offline capability | Wardrobe browsing available offline via cached data |

### 4.3 Security

| ID | Requirement |
|----|-------------|
| NFR-SEC-01 | All API keys (Gemini, Vertex AI) shall be stored server-side only, never exposed to the client |
| NFR-SEC-02 | All database tables shall enforce Row-Level Security (RLS) scoped to `auth.uid()` |
| NFR-SEC-03 | Session tokens shall be stored in iOS Keychain via flutter_secure_storage |
| NFR-SEC-04 | Wardrobe images shall be served via signed URLs with 1-hour TTL from private storage buckets |
| NFR-SEC-05 | AI endpoints shall enforce rate limiting (free: 3/day, premium: 50/day) with 429 responses |
| NFR-SEC-06 | All sensitive operations (usage limits, subscription grants, wear count increments) shall use atomic server-side RPC |

### 4.4 Compliance

| ID | Requirement |
|----|-------------|
| NFR-CMP-01 | All user data shall be stored in EU data centers (GDPR data residency) |
| NFR-CMP-02 | Users shall be able to export all their data in machine-readable format (DSAR) |
| NFR-CMP-03 | Users shall be able to delete their account and all associated data with cascading deletion |
| NFR-CMP-04 | The app shall display a privacy policy and terms of service |
| NFR-CMP-05 | App Store privacy labels shall accurately reflect data collection practices |

### 4.5 Scalability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-SCL-01 | Concurrent users at launch | 1,000 MAU |
| NFR-SCL-02 | Growth phase | 10,000 MAU |
| NFR-SCL-03 | Scale phase | 100,000 MAU |
| NFR-SCL-04 | Infrastructure cost at 1K MAU | < £60/month |
| NFR-SCL-05 | Infrastructure cost at 10K MAU | < £300/month |
| NFR-SCL-06 | Infrastructure cost at 100K MAU | < £2,000/month |

### 4.6 Accessibility & Platform

| ID | Requirement |
|----|-------------|
| NFR-ACC-01 | Target: WCAG AA compliance for core user flows |
| NFR-ACC-02 | Primary platform: iOS 16+ |
| NFR-ACC-03 | Secondary platform: Android (via Flutter — single codebase) |
| NFR-ACC-04 | App orientation: Portrait only |
| NFR-ACC-05 | Light mode UI (dark mode deferred) |

### 4.7 Observability

| ID | Requirement |
|----|-------------|
| NFR-OBS-01 | The system shall capture and report client-side errors via an error monitoring service (Sentry) |
| NFR-OBS-02 | AI API costs and usage shall be logged per-user in `ai_usage_log` with model, tokens, latency, and cost |
| NFR-OBS-03 | Server-side logs shall be available via the backend dashboard |

---

## 5. Epic & Feature Map

| Epic | Title | Stories | Status |
|------|-------|---------|--------|
| **1** | Foundation & Authentication | 1.1–1.6 | Implemented |
| **2** | Digital Wardrobe Core | 2.1–2.7 | Implemented |
| **3** | Context Integration (Weather & Calendar) | 3.1–3.5 | Implemented |
| **4** | AI Outfit Engine | 4.1–4.7 | Implemented (4.7 push notification rolled back — Expo Go limitation) |
| **5** | Wardrobe Analytics | 5.1–5.7 | Implemented |
| **6** | Gamification System | 6.1–6.7 | Implemented |
| **7** | Resale Integration & Premium | 7.1–7.7 | Implemented (billing simulated — RevenueCat not yet integrated) |
| **8** | Shopping Assistant | 8.1–8.8 | Implemented |
| **9** | Social OOTD Feed | 9.1–9.7 | Implemented (push notifications stubbed) |
| **10** | AI Wardrobe Extraction | 10.1–10.7 | Implemented (10.7 Instagram import deferred to V3) |
| **11** | Advanced Analytics 2.0 | 11.1–11.5 | Implemented |
| **12** | Calendar Integration & Outfit Planning | 12.1–12.6 | Implemented |
| **13** | Circular Resale Triggers | 13.1–13.6 | Implemented |

**Total stories:** 77 across 13 epics

---

## 6. Detailed Feature Specifications

### 6.1 Home Screen

The Home screen is the primary entry point and aggregates context from multiple features:

| Element | Description |
|---------|-------------|
| Weather widget | Current conditions + temperature + location |
| Daily outfit suggestion | AI-generated outfit with "Why this outfit?" explanation |
| Quick actions | "Log Today's Outfit", "Add Item", "Check Before You Buy" |
| Upcoming events | Next calendar event with classified type and suggested outfit |
| Travel banner | Displayed when an upcoming multi-day trip is detected |
| Resale prompt banner | Shown for neglected items with estimated sale price |
| Streak counter | Current consecutive-day logging streak |

### 6.2 Tab Navigation Structure

| Tab | Screen | Purpose |
|-----|--------|---------|
| Home | Home dashboard | Daily outfit, weather, events, quick actions |
| Wardrobe | Gallery grid | Browse, filter, manage clothing items |
| Add (+) | Camera/upload | Add new wardrobe item |
| Outfits | Outfit history | View saved outfits, favorites, AI-generated vs manual |
| Profile | User profile | Stats, badges, settings, resale history, donation history |

**MVP navigation note:** Social / Style Squads is a growth feature and does not occupy a primary tab in the MVP shell. When social becomes active post-MVP, the navigation may evolve by replacing the dedicated `Add (+)` tab with a floating action button and promoting `Squads` to a primary destination.

### 6.3 AI Pipeline Flow

```
Photo Capture → Image Compression (on-device, 512px, 85% JPEG)
    → Upload to Cloud Storage (wardrobe-images/{user_id}/)
    → Background Removal (server-side via Gemini 2.0 Flash image editing)
    → AI Vision Analysis (server-side via Gemini 2.0 Flash)
    → Structured JSON Output (category, color, pattern, material, style, season, occasions)
    → User Confirmation/Edit
    → Store in Database (Cloud SQL items table)
    → Available for Outfit Generation
```

### 6.4 Subscription Tiers

| Feature | Free Tier | Premium (£4.99/mo) |
|---------|-----------|---------------------|
| Wardrobe items | Unlimited | Unlimited |
| AI outfit suggestions | 3/day | Unlimited |
| Resale listings | 2/month | Unlimited |
| Sustainability score | Basic | Full with CO2 savings |
| Advanced analytics | Limited | Full |
| Style Squads | Join only | Create + join |
| Shopping assistant | 3 scans/day | Unlimited |
| Priority support | No | Yes |
| Early access features | No | Yes |

---

## 7. Data Model Summary

### 7.1 Database Tables (22 tables, PostgreSQL)

| Table | Purpose | Key Relationships |
|-------|---------|-------------------|
| `profiles` | User profiles (extends auth.users) | 1:1 with auth.users |
| `items` | Wardrobe clothing items | belongs to profile |
| `outfits` | Saved outfit combinations | belongs to profile |
| `outfit_items` | M:N join: outfits ↔ items | FK to outfits, items |
| `wear_logs` | Daily wear log entries | belongs to profile |
| `wear_log_items` | M:N join: wear_logs ↔ items | FK to wear_logs, items |
| `user_stats` | Gamification stats (points, streak, level) | 1:1 with profile |
| `badges` | Badge definitions (system table) | — |
| `user_badges` | M:N join: users ↔ earned badges | FK to profiles, badges |
| `resale_listings` | AI-generated resale listing text | FK to items |
| `resale_history` | Sold item records with price | FK to items |
| `usage_limits` | Per-user daily/monthly feature usage counters | 1:1 with profile |
| `style_squads` | Social group definitions | created_by → profile |
| `squad_memberships` | M:N join: profiles ↔ squads | FK to profiles, squads |
| `ootd_posts` | OOTD social posts | FK to profile, squad |
| `ootd_comments` | Comments on OOTD posts | FK to post, profile |
| `ootd_reactions` | Reactions (🔥) on posts | FK to post, profile |
| `shopping_scans` | Shopping assistant scan results | belongs to profile |
| `shopping_wishlists` | Saved shopping scan products | FK to shopping_scans |
| `calendar_events` | Synced and classified calendar events | belongs to profile |
| `calendar_outfits` | Scheduled outfits for calendar days | FK to outfits, events |
| `wardrobe_extraction_jobs` | Bulk extraction job tracking | belongs to profile |
| `donation_log` | Donation records | FK to items |
| `ai_usage_log` | AI API call tracking (cost, tokens, latency) | belongs to profile |

### 7.2 Key Database Features

- **Row-Level Security (RLS):** All user-facing tables enforce `auth.uid() = user_id`
- **UUID primary keys** on all tables
- **JSONB columns** for flexible metadata (AI analysis results, event details)
- **TEXT[] arrays** for multi-value fields (seasons, occasions, colors)
- **Database triggers:** auto-create profile on signup, auto-update timestamps, engagement counters
- **RPC functions:** atomic wear count increment, usage limit check-and-increment, premium trial grant
- **CHECK constraints:** `resale_status` enum validation
- **Foreign key cascades:** cascading deletes for user data cleanup (GDPR)
- **Composite unique constraints:** prevent duplicate reactions, duplicate squad memberships

---

## 8. Integration Points

| Integration | Purpose | Method | API Key Location |
|-------------|---------|--------|-----------------|
| **Firebase Auth** | Authentication (email, Apple, Google) | Firebase Flutter SDK | N/A (managed) |
| **Cloud SQL PostgreSQL** | Primary database | Direct connection via Cloud SQL Proxy | Service account |
| **Cloud Storage** | Image storage (wardrobe photos) | GCP SDK / signed URLs | Service account |
| **Cloud Run** | API server (AI proxy, business logic) | HTTPS REST/gRPC | Server-side secrets |
| **Vertex AI / Gemini 2.0 Flash** | Clothing analysis, outfit generation, background removal, event classification, gap analysis | Via Cloud Run API | Server-side (Vertex AI credentials) |
| **Open-Meteo API** | Weather data (current + forecast) | Direct HTTP (free, no key) | N/A |
| **Device Calendar** | Calendar event sync | device_calendar Flutter plugin | N/A (on-device) |
| **Firebase Cloud Messaging** | Push notification delivery (APNs/FCM) | FCM Flutter SDK | Firebase project config |
| **Apple In-App Purchase** | Premium subscription billing | RevenueCat Flutter SDK | App Store Connect |

---

## 9. Subscription & Monetization

### 9.1 Revenue Model

- **Free tier:** Core wardrobe features with daily usage limits on AI features
- **Premium tier:** £4.99/month via Apple In-App Purchase
- **Target:** Positive unit economics at 10,000 MAU

### 9.2 Usage Limits (enforced server-side via RPC)

| Feature | Free | Premium |
|---------|------|---------|
| AI outfit suggestions | 3/day | Unlimited |
| Resale listings | 2/month | Unlimited |
| Shopping scans | 3/day | Unlimited |
| Bulk extraction photos | 10/batch | 50/batch |

### 9.3 Premium Trial

- 30-day free trial awarded upon completing "Closet Safari" challenge (20 items uploaded in 7 days)
- Trial tracked via `user_stats.trial_expires_at` synced with `profiles.premium_until`
- Trial grant is atomic via Cloud Run API endpoint

### 9.4 Billing Implementation

- **Planned:** RevenueCat Flutter SDK integration for App Store subscription management
- **Requirement:** Must be implemented before App Store launch

---

## 10. Compliance & Privacy

### 10.1 GDPR Requirements

| Requirement | Implementation |
|-------------|----------------|
| **Lawful basis** | Consent (account creation) + legitimate interest (analytics) |
| **Data residency** | All data stored in EU region (GCP europe-west1 or europe-west2) |
| **Right to access (DSAR)** | Export all user data as JSON via Cloud Run API endpoint |
| **Right to erasure** | Cascading delete of all user data, storage objects, and auth record |
| **Right to rectification** | Users can edit all personal data and item metadata |
| **Data minimization** | Only collect data necessary for app functionality |
| **Privacy policy** | Accessible in-app and on web |

### 10.2 Data Classification

| Data Type | Classification | Storage | Retention |
|-----------|---------------|---------|-----------|
| Email, name | PII | Firebase Auth + Cloud SQL profiles | Until account deletion |
| Wardrobe photos | Personal data | Cloud Storage (private bucket) | Until account deletion |
| Wear logs | Usage data | Cloud SQL PostgreSQL | Until account deletion |
| AI analysis results | Derived data | Cloud SQL PostgreSQL | Until item deletion |
| Push tokens | Device identifier | Cloud SQL profiles table | Until logout/deletion |
| Calendar events | Synced data | Cloud SQL PostgreSQL | 30-day rolling window |

### 10.3 App Store Compliance

| Requirement | Status |
|-------------|--------|
| Privacy nutrition labels | Must be configured in App Store Connect |
| App Tracking Transparency | Not required (no third-party tracking) |
| Terms of Service | Must be created before launch |
| Age rating | 4+ (no objectionable content) |
| Export compliance | No encryption beyond HTTPS |

---

## Appendix A: Requirement Traceability Matrix

| Requirement ID Range | Feature Area | Epic(s) |
|---------------------|--------------|---------|
| FR-AUTH-01 to FR-AUTH-10 | Authentication | Epic 1 |
| FR-ONB-01 to FR-ONB-05 | Onboarding | Epics 1, 6 |
| FR-WRD-01 to FR-WRD-15 | Wardrobe Management | Epic 2 |
| FR-EXT-01 to FR-EXT-10 | AI Extraction | Epic 10 |
| FR-CTX-01 to FR-CTX-13 | Context (Weather/Calendar) | Epics 3, 12 |
| FR-OUT-01 to FR-OUT-11 | Outfit Generation | Epic 4 |
| FR-EVT-01 to FR-EVT-08 | Event Planning | Epic 12 |
| FR-TRV-01 to FR-TRV-05 | Travel Mode | Epic 12 |
| FR-LOG-01 to FR-LOG-07 | Wear Logging | Epic 5 |
| FR-ANA-01 to FR-ANA-06 | Core Analytics | Epic 5 |
| FR-BRD-01 to FR-BRD-03 | Brand Analytics | Epic 11 |
| FR-SUS-01 to FR-SUS-05 | Sustainability | Epics 6, 11 |
| FR-GAP-01 to FR-GAP-06 | Gap Analysis | Epic 11 |
| FR-SEA-01 to FR-SEA-04 | Seasonal Reports | Epic 11 |
| FR-HMP-01 to FR-HMP-04 | Wear Heatmap | Epic 11 |
| FR-HLT-01 to FR-HLT-05 | Wardrobe Health | Epic 13 |
| FR-GAM-01 to FR-GAM-06 | Gamification | Epic 6 |
| FR-SHP-01 to FR-SHP-12 | Shopping Assistant | Epic 8 |
| FR-SOC-01 to FR-SOC-13 | Social / OOTD | Epic 9 |
| FR-NTF-01 to FR-NTF-05 | Social Notifications | Epic 9 |
| FR-RSL-01 to FR-RSL-10 | Resale | Epics 7, 13 |
| FR-DON-01 to FR-DON-05 | Donations | Epic 13 |
| FR-PSH-01 to FR-PSH-06 | Push Notifications | Cross-cutting |
| NFR-PERF-01 to NFR-PERF-09 | Performance | Cross-cutting |
| NFR-REL-01 to NFR-REL-04 | Reliability | Cross-cutting |
| NFR-SEC-01 to NFR-SEC-06 | Security | Cross-cutting |
| NFR-CMP-01 to NFR-CMP-05 | Compliance | Cross-cutting |
| NFR-SCL-01 to NFR-SCL-06 | Scalability | Cross-cutting |
| NFR-ACC-01 to NFR-ACC-05 | Accessibility | Cross-cutting |
| NFR-OBS-01 to NFR-OBS-03 | Observability | Cross-cutting |

---

**Total Functional Requirements:** 149
**Total Non-Functional Requirements:** 27
**Total Requirements:** 176

---

**Document Status:** Complete
**Generated:** 2026-03-08
**Source:** Derived from V1 PRD, V2 PRD, 77 user stories (Epics 1–13), current architecture documentation, and codebase analysis
