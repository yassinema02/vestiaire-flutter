---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
includedFiles:
  prd:
    - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md
  architecture: []
  epics:
    - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md
  ux:
    - /Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-03-09
**Project:** bmad

## Step 1: Document Discovery

### Inventory

#### PRD Files Found

**Whole Documents:**
- `prd.md` (24,677 bytes, modified 2026-03-09 17:16:41)

**Sharded Documents:**
- None found

#### Architecture Files Found

**Whole Documents:**
- None found

**Sharded Documents:**
- None found

#### Epics & Stories Files Found

**Whole Documents:**
- `epics.md` (74,621 bytes, modified 2026-03-09 18:24:08)

**Sharded Documents:**
- None found

#### UX Design Files Found

**Whole Documents:**
- `ux-design-specification.md` (31,803 bytes, modified 2026-03-09 18:13:39)

**Sharded Documents:**
- None found

### Issues Identified

- Warning: Architecture document not found
- No duplicate whole/sharded document formats detected

### Documents Selected For Assessment

- [prd.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/prd.md)
- [epics.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/epics.md)
- [ux-design-specification.md](/Users/yassine/vestiaire2.0/_bmad-output/planning-artifacts/ux-design-specification.md)

### User Confirmation

- Proceeding without an Architecture document, as confirmed on 2026-03-09

## PRD Analysis

### Functional Requirements

FR-AUTH-01: Users shall register via email and password with email verification [Priority: P0]
FR-AUTH-02: Users shall sign in via Apple Sign-In (iOS native) [Priority: P0]
FR-AUTH-03: Users shall sign in via Google OAuth [Priority: P0]
FR-AUTH-04: Users shall be able to reset their password via email link [Priority: P0]
FR-AUTH-05: The system shall persist authenticated sessions securely using device keychain (flutter_secure_storage) [Priority: P0]
FR-AUTH-06: Users shall be able to sign out, clearing all session data from the device [Priority: P0]
FR-AUTH-07: The system shall automatically refresh expired access tokens using stored refresh tokens [Priority: P0]
FR-AUTH-08: Users shall be able to update their display name and profile photo [Priority: P1]
FR-AUTH-09: Users shall be able to delete their account and all associated data (GDPR right to erasure) [Priority: P0]
FR-AUTH-10: The system shall create a `profiles` record automatically upon user registration via Cloud Run API (on first login -> create profile row in Cloud SQL) [Priority: P0]
FR-ONB-01: New users shall be guided through a profile setup flow (name, style preferences, photo) [Priority: P1]
FR-ONB-02: The system shall present a "First 5 Items" challenge encouraging users to add 5 wardrobe items [Priority: P1]
FR-ONB-03: The system shall present a "Closet Safari" 7-day challenge: upload 20 items to unlock 1 month Premium free [Priority: P1]
FR-ONB-04: Completing the Closet Safari challenge shall automatically grant a 30-day Premium trial [Priority: P1]
FR-ONB-05: Users shall be able to skip onboarding and access the app directly [Priority: P1]
FR-WRD-01: Users shall add wardrobe items by capturing a photo via camera or selecting from gallery [Priority: P0]
FR-WRD-02: The system shall compress uploaded images to <= 512px width at 85% JPEG quality before upload [Priority: P0]
FR-WRD-03: Uploaded images shall be stored in a private cloud storage bucket scoped to the user's ID [Priority: P0]
FR-WRD-04: The system shall automatically remove image backgrounds via Gemini 2.0 Flash image editing (server-side via Cloud Run) [Priority: P0]
FR-WRD-05: The system shall auto-categorize items using Gemini 2.0 Flash vision analysis, extracting: category, color, secondary colors, pattern, material, style, season suitability, and occasion tags [Priority: P0]
FR-WRD-06: AI categorization results shall be validated against a fixed taxonomy (valid categories, colors, patterns) with fallback to safe defaults [Priority: P0]
FR-WRD-07: Users shall be able to manually edit all AI-assigned metadata for any item [Priority: P0]
FR-WRD-08: Users shall enter optional metadata: item name, brand, purchase price, purchase date, currency [Priority: P1]
FR-WRD-09: Users shall view their wardrobe in a scrollable gallery grid [Priority: P0]
FR-WRD-10: The wardrobe gallery shall support filtering by: category, color, season, occasion, brand, neglect status, resale status [Priority: P0]
FR-WRD-11: Users shall tap an item to view its detail screen showing: image, all metadata, wear count, cost-per-wear, last worn date, wear history [Priority: P0]
FR-WRD-12: Users shall be able to delete items from their wardrobe [Priority: P0]
FR-WRD-13: Users shall be able to favorite items for quick access [Priority: P1]
FR-WRD-14: The system shall track `neglect_status` for items not worn in a configurable number of days (default: 180) [Priority: P1]
FR-WRD-15: The system shall display a "Neglected" badge on items exceeding the neglect threshold [Priority: P1]
FR-EXT-01: Users shall bulk-upload up to 50 photos from their gallery for AI extraction [Priority: P1]
FR-EXT-02: The system shall detect multiple clothing items within a single photo (up to 5 items per photo) [Priority: P1]
FR-EXT-03: Each detected item shall be auto-categorized with category, color, style, material, and pattern [Priority: P1]
FR-EXT-04: Background removal shall be applied to each extracted item [Priority: P1]
FR-EXT-05: Users shall review all extracted items in a confirmation screen before adding to wardrobe [Priority: P1]
FR-EXT-06: Each extracted item shall have Keep/Remove toggles and editable metadata [Priority: P1]
FR-EXT-07: The system shall display extraction progress with status updates and estimated time remaining [Priority: P1]
FR-EXT-08: Extraction jobs shall be tracked in a `wardrobe_extraction_jobs` table with status progression [Priority: P1]
FR-EXT-09: Items created via extraction shall be tagged with `creation_method = 'ai_extraction'` and linked to the source photo [Priority: P1]
FR-EXT-10: The system shall detect potential duplicate items during extraction and warn the user [Priority: P2]
FR-CTX-01: The system shall request location permission and display current weather on the Home screen [Priority: P0]
FR-CTX-02: Weather data shall be fetched from Open-Meteo API (free, no API key) [Priority: P0]
FR-CTX-03: The weather widget shall show: temperature, "feels like", condition icon, and location name [Priority: P0]
FR-CTX-04: Weather data shall be cached for 30 minutes with local persistence (shared_preferences or Hive) [Priority: P1]
FR-CTX-05: The system shall display a 5-day weather forecast [Priority: P1]
FR-CTX-06: The system shall map weather conditions to clothing recommendations (e.g., rain -> waterproof outerwear) [Priority: P1]
FR-CTX-07: Users shall connect their device Calendar to the app with permission explanation (device_calendar plugin) [Priority: P1]
FR-CTX-08: Users shall select which calendars to sync (work, personal, etc.) [Priority: P1]
FR-CTX-09: The system shall fetch and store events for today and the next 7 days in `calendar_events` [Priority: P1]
FR-CTX-10: The system shall classify calendar events by type using keyword detection and AI fallback: Work, Social, Active, Formal, Casual [Priority: P1]
FR-CTX-11: Each classified event shall receive a formality score (1-10) [Priority: P1]
FR-CTX-12: Users shall be able to re-classify events if the AI classification is incorrect [Priority: P2]
FR-CTX-13: The system shall compile a context object (weather + events + date + day-of-week) for AI outfit generation [Priority: P0]
FR-OUT-01: The system shall generate outfit suggestions using Gemini AI, considering: wardrobe items, weather, calendar events, user preferences, and wear history [Priority: P0]
FR-OUT-02: Generated outfits shall be stored in the `outfits` table with linked items in `outfit_items` [Priority: P0]
FR-OUT-03: The Home screen shall display the primary daily outfit suggestion with a "Why this outfit?" explanation [Priority: P0]
FR-OUT-04: Users shall swipe through multiple outfit suggestions (swipe right to save, left to skip) [Priority: P0]
FR-OUT-05: Users shall be able to manually build outfits by selecting items from categorized lists [Priority: P0]
FR-OUT-06: Users shall view their outfit history with filters: AI-generated vs manual, occasion, season, date range [Priority: P1]
FR-OUT-07: Users shall favorite outfits for quick access [Priority: P1]
FR-OUT-08: Users shall be able to delete outfits from their history [Priority: P1]
FR-OUT-09: Free users shall be limited to 3 AI outfit generations per day [Priority: P0]
FR-OUT-10: Premium users shall have unlimited AI outfit generations [Priority: P0]
FR-OUT-11: The system shall avoid suggesting recently worn items unless the wardrobe is small [Priority: P1]
FR-EVT-01: The Home screen shall display upcoming events with classified type and formality [Priority: P1]
FR-EVT-02: The system shall generate event-specific outfit suggestions considering formality, time of day, and weather [Priority: P1]
FR-EVT-03: Users shall schedule outfits for future days via a "Plan Week" 7-day calendar view [Priority: P1]
FR-EVT-04: Each day in the planner shall show events and weather preview [Priority: P1]
FR-EVT-05: Scheduled outfits shall be stored in `calendar_outfits` with event association [Priority: P1]
FR-EVT-06: Users shall edit or remove scheduled outfits [Priority: P1]
FR-EVT-07: The system shall send evening reminders before formal events with preparation tips (e.g., "Don't forget to iron your shirt") [Priority: P2]
FR-EVT-08: Event reminders shall be configurable: timing, event types, snooze/dismiss [Priority: P2]
FR-TRV-01: The system shall detect multi-day trip events from the calendar [Priority: P2]
FR-TRV-02: The system shall generate packing suggestions based on trip duration, destination weather, and planned events [Priority: P2]
FR-TRV-03: Users shall view a checklist interface to mark items as packed [Priority: P2]
FR-TRV-04: Users shall export the packing list to a notes or reminder app [Priority: P2]
FR-TRV-05: A travel banner shall appear on the Home screen when an upcoming trip is detected [Priority: P2]
FR-LOG-01: Users shall log outfits worn today via a "Log Today's Outfit" flow on the Home screen [Priority: P0]
FR-LOG-02: Logging shall support selecting individual items or a previously saved outfit [Priority: P0]
FR-LOG-03: Multiple wear logs per day shall be supported [Priority: P1]
FR-LOG-04: Each wear log shall record: date, items worn, and optional photo [Priority: P0]
FR-LOG-05: Wear count on each item shall be incremented atomically via database RPC to prevent race conditions [Priority: P0]
FR-LOG-06: The system shall send an evening reminder notification (default 8 PM, user-configurable) to log the day's outfit [Priority: P1]
FR-LOG-07: Wear logs shall be viewable in a monthly calendar view with daily activity indicators [Priority: P1]
FR-ANA-01: The analytics dashboard shall display: total items, total wardrobe value, average cost-per-wear, and category distribution [Priority: P0]
FR-ANA-02: Cost-per-wear (CPW) shall be calculated as purchase_price / wear_count, color-coded: green (< GBP5), yellow (GBP5-20), red (> GBP20) [Priority: P0]
FR-ANA-03: The system shall identify neglected items (not worn in 60+ days, configurable) and display them in a dedicated section [Priority: P1]
FR-ANA-04: The system shall display a "Top 10 Most Worn Items" leaderboard with time period filters [Priority: P1]
FR-ANA-05: The system shall display a wear frequency bar chart and category distribution pie chart [Priority: P1]
FR-ANA-06: The system shall provide AI-generated wardrobe insights (summary text) [Priority: P1]
FR-BRD-01: The analytics dashboard shall include a "Brand Value" section showing: brand name, average CPW, total spent, and total wears, ranked by best value [Priority: P1]
FR-BRD-02: Brand analytics shall be filterable by category (e.g., "Best value sneakers brand") [Priority: P2]
FR-BRD-03: Brands shall only appear with a minimum of 3 items [Priority: P2]
FR-SUS-01: The system shall calculate a sustainability score (0-100) based on 5 weighted factors: avg wear count (30%), % wardrobe worn in 90 days (25%), avg CPW (20%), resale activity (15%), new purchases avoided (10%) [Priority: P1]
FR-SUS-02: The system shall estimate CO2 savings from re-wearing vs buying new [Priority: P1]
FR-SUS-03: The sustainability score shall be displayed with color gradient and leaf icon [Priority: P1]
FR-SUS-04: Users shall see a percentile comparison: "Top X% of Vestiaire users" [Priority: P2]
FR-SUS-05: An "Eco Warrior" badge shall unlock at sustainability score >= 80 [Priority: P1]
FR-GAP-01: The system shall analyze the wardrobe for missing item types by category, formality, color range, and weather coverage [Priority: P1]
FR-GAP-02: Each detected gap shall be rated: Critical, Important, or Optional [Priority: P1]
FR-GAP-03: Gap suggestions shall include specific item recommendations (e.g., "Consider adding a beige trench coat") [Priority: P1]
FR-GAP-04: Users shall be able to dismiss individual gaps [Priority: P2]
FR-GAP-05: AI-enriched gap analysis shall use Gemini for personalized recommendations beyond basic rule detection [Priority: P2]
FR-GAP-06: Gap results shall be cached locally and refresh when wardrobe changes [Priority: P2]
FR-SEA-01: The system shall generate seasonal wardrobe reports (Spring, Summer, Fall, Winter) [Priority: P2]
FR-SEA-02: Each report shall show: item count per season, most worn items, neglected items, and seasonal readiness score (1-10) [Priority: P2]
FR-SEA-03: Reports shall include historical comparison (e.g., "This winter you wore 12% more items than last") [Priority: P2]
FR-SEA-04: Seasonal transition alerts shall notify users 2 weeks before a new season [Priority: P2]
FR-HMP-01: The system shall display a calendar heatmap showing daily wear activity with color intensity proportional to items worn [Priority: P2]
FR-HMP-02: The heatmap shall support view modes: Month, Quarter, Year [Priority: P2]
FR-HMP-03: Users shall tap a day to see a detail overlay with outfits worn that day [Priority: P2]
FR-HMP-04: The heatmap shall display streak tracking and streak statistics [Priority: P2]
FR-HLT-01: The system shall calculate a wardrobe health score (0-100) based on 3 weighted factors: % items worn in 90 days (50%), % items with < GBP5 CPW (30%), size vs utilization ratio (20%) [Priority: P1]
FR-HLT-02: The health score shall be color-coded: Green (80-100), Yellow (50-79), Red (< 50) [Priority: P1]
FR-HLT-03: The score shall include recommendations (e.g., "Declutter 8 items to improve health") [Priority: P1]
FR-HLT-04: A deterministic user comparison shall show percentile ranking [Priority: P2]
FR-HLT-05: A "Spring Clean" guided declutter mode shall walk users through neglected items with keep/sell/donate options [Priority: P2]
FR-GAM-01: Users shall earn style points for actions: upload item (+10), log outfit (+5), streak day (+3), first log of day (+2) [Priority: P1]
FR-GAM-02: The system shall track 6 user levels based on wardrobe item count thresholds: Closet Rookie (0), Style Starter (10), Fashion Explorer (25), Wardrobe Pro (50), Style Expert (100), Style Master (200) [Priority: P1]
FR-GAM-03: The system shall track consecutive-day streaks for outfit logging, with 1 streak freeze per week [Priority: P1]
FR-GAM-04: The system shall award badges for achievements, including: First Step, Closet Complete, Week Warrior, Streak Legend (30 days), Early Bird, Rewear Champion (50 re-wears), Circular Seller (1+ listing), Circular Champion (10+ sold), Generous Giver (20+ donated), Monochrome Master, Rainbow Warrior, OG Member, Weather Warrior, Style Guru, Eco Warrior [Priority: P1]
FR-GAM-05: The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed [Priority: P1]
FR-GAM-06: Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`) [Priority: P0]
FR-SHP-01: Users shall analyze potential purchases by uploading a screenshot from gallery or camera [Priority: P1]
FR-SHP-02: Users shall analyze potential purchases by pasting a product URL [Priority: P1]
FR-SHP-03: URL scraping shall extract product data using Open Graph meta tags and schema.org JSON-LD markup, with fallback to screenshot analysis [Priority: P1]
FR-SHP-04: The system shall extract structured product data: name, category, color, secondary colors, style, material, pattern, season, formality score (1-10), brand, price [Priority: P1]
FR-SHP-05: Users shall confirm or edit AI-extracted product data before scoring [Priority: P1]
FR-SHP-06: The system shall calculate a compatibility score (0-100) based on: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%) [Priority: P1]
FR-SHP-07: The compatibility score shall be displayed with a 5-tier rating system: Perfect Match (90-100), Great Choice (75-89), Good Fit (60-74), Might Work (40-59), Careful (0-39), each with distinct color and icon [Priority: P1]
FR-SHP-08: The system shall display top matching items from the user's wardrobe, grouped by category, with match reasons [Priority: P1]
FR-SHP-09: The system shall generate 3 AI-powered insights per scan: style feedback, wardrobe gap assessment, and value proposition [Priority: P1]
FR-SHP-10: Users shall save scanned products to a shopping wishlist with score, matches, and insights [Priority: P2]
FR-SHP-11: Scanned products shall be stored in `shopping_scans` for history and re-analysis [Priority: P1]
FR-SHP-12: The system shall display an empty wardrobe CTA when no items exist for scoring [Priority: P2]
FR-SOC-01: Users shall create Style Squads (private groups) with a name, optional description, and unique invite code [Priority: P1]
FR-SOC-02: Users shall invite others to squads via invite code, SMS, or username search [Priority: P1]
FR-SOC-03: Squad size shall be limited to 20 members [Priority: P1]
FR-SOC-04: Users shall belong to multiple squads simultaneously [Priority: P1]
FR-SOC-05: Squad admins shall be able to remove members [Priority: P1]
FR-SOC-06: Users shall post OOTD (Outfit of the Day) photos to selected squads with optional caption (max 150 chars) and tagged wardrobe items [Priority: P1]
FR-SOC-07: The Social tab shall display a chronological feed of OOTD posts from all joined squads [Priority: P1]
FR-SOC-08: Users shall filter the feed by specific squad [Priority: P2]
FR-SOC-09: Users shall react to posts with a fire emoji toggle with reaction count display [Priority: P1]
FR-SOC-10: Users shall comment on posts (text only, max 200 chars) with notification to post author [Priority: P1]
FR-SOC-11: Post authors shall delete any comment on their post; users shall delete their own comments [Priority: P1]
FR-SOC-12: Users shall use "Steal This Look" on any OOTD post to find similar items in their own wardrobe, with AI-powered matching and fallback [Priority: P1]
FR-SOC-13: "Steal This Look" results shall be color-coded by match quality and saveable as a new outfit [Priority: P2]
FR-NTF-01: Users shall receive push notifications when a squad member posts an OOTD [Priority: P2]
FR-NTF-02: Notification settings shall support: All posts, Only morning posts, Off [Priority: P2]
FR-NTF-03: Quiet hours shall be respected (default: 10 PM - 7 AM) with configurable daily notification limit [Priority: P2]
FR-NTF-04: Users shall receive an optional daily posting reminder (default 9 AM, user-configurable) [Priority: P2]
FR-NTF-05: The posting reminder shall be skipped if the user has already posted today [Priority: P2]
FR-RSL-01: The system shall identify resale candidates based on: not worn in 90+ days, high CPW, and low wear count relative to age [Priority: P1]
FR-RSL-02: The system shall generate AI-powered resale listings optimized for Vinted/Depop, including: title, description, category, condition estimate, with CPW and sustainability data [Priority: P1]
FR-RSL-03: Users shall copy listing text to clipboard or share via system share sheet [Priority: P1]
FR-RSL-04: Items shall track `resale_status` with CHECK constraint: 'listed', 'sold', 'donated', or NULL [Priority: P0]
FR-RSL-05: The system shall send monthly resale prompt notifications for neglected items with estimated sale price [Priority: P2]
FR-RSL-06: Users shall dismiss resale prompts per-item ("I'll keep it") or globally via settings [Priority: P2]
FR-RSL-07: Users shall view resale history on their profile showing items listed, sold, and total earnings [Priority: P1]
FR-RSL-08: An earnings chart shall display monthly earnings over time [Priority: P2]
FR-RSL-09: Selling 10+ items shall unlock the "Circular Champion" badge [Priority: P1]
FR-RSL-10: Resale status changes (listed -> sold) shall sync back to the `items` table [Priority: P1]
FR-DON-01: Users shall mark items as "Donated" from the item detail screen [Priority: P2]
FR-DON-02: Donations shall be logged in `donation_log` with: item reference, charity/organization, date, estimated value [Priority: P2]
FR-DON-03: Users shall view donation history on their profile [Priority: P2]
FR-DON-04: Donating 20+ items shall unlock the "Generous Giver" badge [Priority: P2]
FR-DON-05: The Spring Clean guided declutter flow shall log donations automatically [Priority: P2]
FR-PSH-01: The system shall request push notification permission via Firebase Cloud Messaging (FCM) [Priority: P0]
FR-PSH-02: Push tokens shall be stored in the `profiles` table [Priority: P0]
FR-PSH-03: Evening wear-log reminders shall be sent at user-configurable time (default 8 PM) [Priority: P1]
FR-PSH-04: Morning outfit suggestion notifications shall include weather preview [Priority: P2]
FR-PSH-05: Event-based outfit reminders shall fire the evening before formal events [Priority: P2]
FR-PSH-06: All notification types shall be independently toggleable in settings [Priority: P1]

Total FRs: 149

### Non-Functional Requirements

NFR-PERF-01: Image upload and background removal [Target: < 5 seconds]
NFR-PERF-02: AI outfit generation (end-to-end) [Target: < 6 seconds]
NFR-PERF-03: Screenshot product analysis [Target: < 5 seconds]
NFR-PERF-04: URL scraping and analysis [Target: < 8 seconds]
NFR-PERF-05: Bulk photo extraction (20 photos) [Target: < 2 minutes]
NFR-PERF-06: OOTD feed load time [Target: < 2 seconds]
NFR-PERF-07: Wardrobe gallery initial render [Target: < 1 second]
NFR-PERF-08: App cold start to interactive [Target: < 3 seconds]
NFR-PERF-09: Compatibility scoring algorithm [Target: Must scale to 500+ item wardrobes]
NFR-REL-01: System uptime [Target: >= 99.5%]
NFR-REL-02: Database backup frequency [Target: Daily automated]
NFR-REL-03: AI service degradation [Target: Graceful fallback (show cached data or manual input)]
NFR-REL-04: Offline capability [Target: Wardrobe browsing available offline via cached data]
NFR-SEC-01: All API keys (Gemini, Vertex AI) shall be stored server-side only, never exposed to the client
NFR-SEC-02: All database tables shall enforce Row-Level Security (RLS) scoped to `auth.uid()`
NFR-SEC-03: Session tokens shall be stored in iOS Keychain via flutter_secure_storage
NFR-SEC-04: Wardrobe images shall be served via signed URLs with 1-hour TTL from private storage buckets
NFR-SEC-05: AI endpoints shall enforce rate limiting (free: 3/day, premium: 50/day) with 429 responses
NFR-SEC-06: All sensitive operations (usage limits, subscription grants, wear count increments) shall use atomic server-side RPC
NFR-CMP-01: All user data shall be stored in EU data centers (GDPR data residency)
NFR-CMP-02: Users shall be able to export all their data in machine-readable format (DSAR)
NFR-CMP-03: Users shall be able to delete their account and all associated data with cascading deletion
NFR-CMP-04: The app shall display a privacy policy and terms of service
NFR-CMP-05: App Store privacy labels shall accurately reflect data collection practices
NFR-SCL-01: Concurrent users at launch [Target: 1,000 MAU]
NFR-SCL-02: Growth phase [Target: 10,000 MAU]
NFR-SCL-03: Scale phase [Target: 100,000 MAU]
NFR-SCL-04: Infrastructure cost at 1K MAU [Target: < GBP60/month]
NFR-SCL-05: Infrastructure cost at 10K MAU [Target: < GBP300/month]
NFR-SCL-06: Infrastructure cost at 100K MAU [Target: < GBP2,000/month]
NFR-ACC-01: Target: WCAG AA compliance for core user flows
NFR-ACC-02: Primary platform: iOS 16+
NFR-ACC-03: Secondary platform: Android (via Flutter - single codebase)
NFR-ACC-04: App orientation: Portrait only
NFR-ACC-05: Light mode UI (dark mode deferred)
NFR-OBS-01: The system shall capture and report client-side errors via an error monitoring service (Sentry)
NFR-OBS-02: AI API costs and usage shall be logged per-user in `ai_usage_log` with model, tokens, latency, and cost
NFR-OBS-03: Server-side logs shall be available via the backend dashboard

Total NFRs: 38

### Additional Requirements

- Domain and compliance constraints include GDPR data residency, DSAR export, right to erasure, App Store privacy labels, age rating 4+, and Apple IAP billing via RevenueCat.
- Platform constraints include iOS 16+, Android 10+, portrait-only orientation, offline wardrobe browsing, secure token storage, camera access, foreground location access, optional calendar access, FCM/APNs push, and deep-link squad invites.
- Commercial constraints include a freemium model with server-side enforcement of AI suggestion, shopping scan, and resale listing limits.
- Data and integration constraints include Cloud Run API, Cloud SQL PostgreSQL, Cloud Storage signed URLs, Firebase Auth, Vertex AI / Gemini 2.0 Flash, Open-Meteo, device calendar integration, FCM, and RevenueCat.
- The PRD traceability model explicitly maps downstream consumption to UX Design, Architecture, and Epics & Stories.

### PRD Completeness Assessment

- The PRD is strong on product vision, scope phasing, user journeys, success metrics, and cross-cutting constraints.
- The PRD is not fully self-contained for implementation traceability: it summarizes functional scope but delegates the full FR inventory to `docs/functional-requirements.md`, which had to be loaded to extract the complete requirement set.
- Architecture is still missing from the discovered planning artifacts, which reduces readiness for implementation even if PRD coverage is otherwise strong.
- There is a requirements-count inconsistency across artifacts: the PRD states 149 FRs and 27 NFRs, while the referenced detailed requirements document enumerates 149 FRs and 38 NFRs including accessibility/platform requirements.
- This means epic coverage validation can proceed, but any final readiness judgment should treat the PRD set as partially distributed across multiple files rather than a single canonical document.

## Epic Coverage Validation

### Coverage Matrix

| Coverage Layer | Scope Compared | Covered | Missing | Status |
| --- | --- | --- | --- | --- |
| Epic coverage map | PRD FR inventory vs `FR Coverage Map` in `epics.md` | 174 / 174 | 0 | Pass |
| Story traceability | PRD FR inventory vs story acceptance-criteria `And (...)` links in `epics.md` | 161 / 174 | 13 | Gap |

There were no FRs listed in the epics document that were not also present in the PRD requirement set.

### Missing Requirements

| FR Number | PRD Requirement | Epic Coverage | Story Coverage | Status |
| --- | --- | --- | --- | --- |
| FR-AUTH-04 | Users shall be able to reset their password via email link | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-AUTH-06 | Users shall be able to sign out, clearing all session data from the device | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-AUTH-07 | The system shall automatically refresh expired access tokens using stored refresh tokens | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-AUTH-10 | The system shall create a `profiles` record automatically upon user registration via Cloud Run API (on first login -> create profile row in Cloud SQL) | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-DON-04 | Donating 20+ items shall unlock the "Generous Giver" badge | Epic 6 - Gamification System | NOT TRACED TO STORY | Missing |
| FR-ONB-01 | New users shall be guided through a profile setup flow (name, style preferences, photo) | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-ONB-02 | The system shall present a "First 5 Items" challenge encouraging users to add 5 wardrobe items | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-ONB-05 | Users shall be able to skip onboarding and access the app directly | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-PSH-04 | Morning outfit suggestion notifications shall include weather preview | Epic 4 - AI Outfit Engine | NOT TRACED TO STORY | Missing |
| FR-PSH-06 | All notification types shall be independently toggleable in settings | Epic 1 - Foundation & Authentication | NOT TRACED TO STORY | Missing |
| FR-RSL-09 | Selling 10+ items shall unlock the "Circular Champion" badge | Epic 6 - Gamification System | NOT TRACED TO STORY | Missing |
| FR-RSL-10 | Resale status changes (listed -> sold) shall sync back to the `items` table | Epic 7 - Resale Integration & Subscription | NOT TRACED TO STORY | Missing |
| FR-SUS-05 | An "Eco Warrior" badge shall unlock at sustainability score >= 80 | Epic 6 - Gamification System | NOT TRACED TO STORY | Missing |

### Missing FR Coverage

#### Critical Missing FRs

- FR-AUTH-04
  Impact: Password recovery is core account lifecycle functionality and missing traceability in Epic 1 creates implementation ambiguity.
  Recommendation: Add or expand an Epic 1 story for password reset flow and backend handling.
- FR-AUTH-06
  Impact: Sign-out behavior is basic security/session management and currently has no story-level implementation path.
  Recommendation: Add sign-out acceptance criteria to Epic 1 user session management coverage.
- FR-AUTH-07
  Impact: Token refresh is required for stable authenticated sessions and is currently only implied, not traceable.
  Recommendation: Add explicit backend/client session refresh criteria in Epic 1.
- FR-AUTH-10
  Impact: Automatic `profiles` row creation is foundational data integrity behavior and should not rely on implicit interpretation.
  Recommendation: Add this FR explicitly to Story 1.1 acceptance criteria.
- FR-ONB-01
  Impact: Profile setup flow is part of first-run experience but currently lacks a story anchor.
  Recommendation: Add a dedicated onboarding/profile-setup story in Epic 1.
- FR-ONB-02
  Impact: The "First 5 Items" challenge is part of onboarding motivation but has no explicit implementation path.
  Recommendation: Add challenge presentation criteria to the onboarding story in Epic 1.
- FR-ONB-05
  Impact: Skipping onboarding affects funnel behavior and navigation logic but is not story-traced.
  Recommendation: Add skip-path criteria to the onboarding story in Epic 1.
- FR-PSH-04
  Impact: Morning outfit suggestion notifications are in scope but absent from any story, leaving push behavior incomplete.
  Recommendation: Add a dedicated push notification story under Epic 4 or extend the outfit suggestion flow.
- FR-PSH-06
  Impact: Independent notification toggles are a settings requirement and currently have no implementation trace.
  Recommendation: Add notification settings criteria under Epic 1 or a dedicated notification settings story.
- FR-RSL-10
  Impact: Resale status synchronization back to `items` is important for data consistency and analytics integrity.
  Recommendation: Extend Story 7.4 to explicitly cover `items` table sync on resale status changes.

#### High Priority Missing FRs

- FR-DON-04
  Impact: Donation badge logic is claimed in Epic 6 but not tied to any story, weakening gamification completeness.
  Recommendation: Extend Story 6.4 Badge Achievement System to include donation badge trigger criteria.
- FR-RSL-09
  Impact: Circular Champion badge logic is claimed in Epic 6 but not traced to implementation.
  Recommendation: Extend Story 6.4 or add a badge-specific sub-story for resale milestones.
- FR-SUS-05
  Impact: Eco Warrior badge unlock criteria connects sustainability analytics to gamification but is not story-linked.
  Recommendation: Extend Story 6.4 or Story 11.2 to explicitly trace badge unlock behavior.

### Coverage Statistics

- Total PRD FRs: 174
- FRs covered in epic coverage map: 174
- Epic-level coverage percentage: 100%
- FRs explicitly traced to stories: 161
- Story-level traceability percentage: 92.5%

## UX Alignment Assessment

### UX Document Status

Found: `_bmad-output/planning-artifacts/ux-design-specification.md`

### Alignment Issues

- PRD and UX are aligned on the core product loop: daily outfit suggestion, weather + calendar context, swipe-based outfit evaluation, wardrobe digitization, wear logging, social sharing, and shopping analysis.
- UX and available technical design inputs are directionally aligned on Flutter, Firebase Auth, Cloud Run, Cloud SQL, Vertex AI / Gemini, FCM, and RevenueCat. This indicates the recommended stack can support the primary UX flows.
- The strongest UX/PRD mismatch is navigation architecture:
  - PRD detailed feature spec defines tabs for `Home`, `Wardrobe`, `Add (+)`, `Outfits`, and `Profile`.
  - UX navigation pattern defines `Home/Today`, `Wardrobe`, `Squads`, and `Profile`, with Add handled as a floating action and no dedicated `Outfits` tab.
  - Result: top-level information architecture is not yet canonical.
- Dark mode is inconsistent across documents:
  - PRD / detailed requirements specify `NFR-ACC-05: Light mode UI (dark mode deferred)`.
  - UX specification explicitly requires full dark mode support.
  - Result: visual theming scope is contradictory.
- Orientation behavior is inconsistent across documents:
  - PRD says portrait only.
  - UX says portrait on mobile but rotation allowed on tablets.
  - Result: responsive/orientation scope is not fully agreed.
- UX introduces at least one requirement not clearly present in the PRD:
  - iOS Home Screen widget for outfit preview.
  - Result: this should be either added to the product requirements or removed from UX scope.

### Warnings

- No Architecture document was found in the planning artifacts, so formal UX-to-Architecture validation is blocked.
- `docs/stack_recommendation.md` was used as the nearest available technical design proxy; that is sufficient to assess stack plausibility, but not enough to validate component boundaries, state management, API contracts, data flows, or non-functional design decisions in the way a formal architecture artifact would.
- Because architecture is missing, UX elements like wrapper component strategy, optimistic UI behavior, bottom-sheet interaction patterns, accessibility semantics, and notification orchestration are not yet anchored to explicit implementation decisions.
- Before implementation starts, the team should resolve the navigation, theming, and orientation conflicts and produce a formal architecture document that explicitly supports the approved UX interaction model.

## Epic Quality Review

### Best-Practice Compliance Checklist

| Check | Result | Notes |
| --- | --- | --- |
| Epics deliver user value | Mostly Pass | Epic titles and goals are user-facing rather than pure technical layers |
| Epic independence | Pass with caution | Epics generally build in a logical sequence and do not show obvious forward epic dependencies |
| Stories sized for single-dev completion | Partial Fail | Several stories are broad and combine too many concerns |
| No forward dependencies | Pass | No explicit forward story references were found |
| Database created only when needed | Mostly Pass | Stories generally create data structures when first needed rather than all upfront |
| Clear acceptance criteria | Partial Fail | Most stories use Given/When/Then, but many omit failure states and some only partially satisfy referenced FRs |
| Traceability to FRs maintained | Fail | Story-level traceability remains incomplete for 13 FRs from the previous step |
| Greenfield implementation readiness | Fail | No explicit initial project setup / environment / CI-CD story was found |

### Quality Findings By Severity

#### Red Critical Violations

- Story-level FR traceability is incomplete.
  - 13 FRs are claimed at epic level but not traced to any story acceptance criteria.
  - This is a direct violation of the create-epics-and-stories standard that every FR must appear in at least one story.
- Greenfield setup readiness is missing.
  - This is a greenfield project, but there is no explicit story for initial project setup, development environment configuration, or CI/CD/bootstrap readiness.
  - Implementation will start without a canonical setup path.

#### Orange Major Issues

- Nine stories are framed as technical/system stories rather than user-value stories:
  - Story 1.1 `Database Schema & Authentication Setup (Backend)` (`As a Developer`)
  - Story 3.2 `Open-Meteo Integration & Local Caching` (`As a System`)
  - Story 3.3 `Weather Context Mapping` (`As the AI Engine`)
  - Story 3.5 `Event Fetching & AI Classification` (`As a System`)
  - Story 6.1 `Style Points Engine` (`As a System`)
  - Story 7.2 `Premium Status Enforcement` (`As a System`)
  - Story 8.4 `Compatibility Scoring Engine` (`As the AI Engine`)
  - Story 10.2 `Background Multi-Item Extraction Job` (`As a System`)
  - Story 11.3 `Wardrobe Gap Analysis Engine` (`As a System`)
  - These may be legitimate implementation tasks, but they do not meet the stated story-writing standard of clear user value.
- Several stories appear oversized for a single dev-agent completion target:
  - Story 10.2 combines job orchestration, multi-item detection, background removal, categorization, job tracking, and performance SLAs.
  - Story 11.3 combines analytic detection, AI recommendation generation, prioritization logic, and user dismissal behavior.
  - Story 12.4 combines trip detection, travel banner UX, packing list generation, checklist interaction, and export.
- Acceptance criteria often cover the happy path only and omit key error or fallback cases:
  - Story 1.2 does not explicitly cover the email verification path required by FR-AUTH-01.
  - Story 2.2 does not define what happens when AI background removal fails.
  - Story 8.1 does not specify the fallback path when URL scraping fails or returns incomplete metadata.
  - Story 7.1 does not specify cancellation/failure handling for subscription purchase.
- Some traced FRs are only partially represented in acceptance criteria even where the story reference exists.
  - This weakens testability and implementation clarity.

#### Yellow Minor Concerns

- Epic 7 mixes two loosely related value areas: subscription billing and resale tooling.
  - It is still user-facing, but the cohesion is weaker than other epics.
- Duplicate `## Epic List` headings and minor formatting inconsistencies reduce document polish.
- The document mostly follows BDD formatting, but it does not consistently include explicit negative cases, recovery states, or operational constraints inside each story.

### Remediation Guidance

- Add a greenfield setup story at the start of Epic 1 covering project bootstrap, dependency installation, environment configuration, and CI/CD baseline.
- Rewrite the nine technical/system stories into user-outcome stories or split them into user-facing stories plus implementation notes/tasks.
- Split oversized stories into thinner units that remain independently completable.
- Update acceptance criteria to include failure handling, validation rules, and fallback behavior where AI, scraping, billing, sync, or notifications can fail.
- Close the 13 missing story-traceability gaps identified in Step 3 before declaring the epic set implementation-ready.

## Summary and Recommendations

### Overall Readiness Status

NOT READY

### Critical Issues Requiring Immediate Action

- No Architecture document exists in the planning artifacts, which blocks formal implementation validation.
- 13 functional requirements are not traced to any story acceptance criteria, even though they are claimed at epic level.
- The PRD requirement set is distributed across multiple files and contains a requirement-count inconsistency, which weakens the canonical planning baseline.
- UX and PRD are not yet aligned on navigation architecture, dark mode scope, and orientation behavior.
- The epic set is missing explicit greenfield bootstrap / environment / CI-CD setup coverage.

### Recommended Next Steps

1. Create or restore a formal Architecture document in the planning artifacts and make it the canonical technical reference.
2. Resolve the 13 missing FR-to-story traceability gaps and re-check that every referenced FR is fully expressed in acceptance criteria.
3. Reconcile UX vs PRD conflicts for navigation, theming, orientation, and any extra UX scope such as the home-screen widget.
4. Add a greenfield setup story and rewrite the technical/system stories into user-value-oriented stories or explicit implementation tasks under user stories.
5. Tighten acceptance criteria for AI, sync, scraping, and billing flows to include error, fallback, and recovery behavior.

### Final Note

This assessment identified 27 issues or material findings across 4 categories:

- artifact completeness
- requirements traceability
- UX/spec alignment
- epic/story quality

Address the critical issues before proceeding to implementation. The current artifacts are close enough to refine efficiently, but not strong enough to start implementation without introducing avoidable ambiguity and rework.
