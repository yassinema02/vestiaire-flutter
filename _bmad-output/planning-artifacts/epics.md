---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories']
inputDocuments: ['_bmad-output/planning-artifacts/prd.md', 'docs/stack_recommendation.md', 'docs/functional-requirements.md', '_bmad-output/planning-artifacts/ux-design-specification.md']
---

# Vestiaire - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Vestiaire, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-AUTH-01: Users shall register via email and password with email verification
FR-AUTH-02: Users shall sign in via Apple Sign-In (iOS native)
FR-AUTH-03: Users shall sign in via Google OAuth
FR-AUTH-04: Users shall be able to reset their password via email link
FR-AUTH-05: The system shall persist authenticated sessions securely using device keychain (flutter_secure_storage)
FR-AUTH-06: Users shall be able to sign out, clearing all session data from the device
FR-AUTH-07: The system shall automatically refresh expired access tokens using stored refresh tokens
FR-AUTH-08: Users shall be able to update their display name and profile photo
FR-AUTH-09: Users shall be able to delete their account and all associated data (GDPR right to erasure)
FR-AUTH-10: The system shall create a `profiles` record automatically upon user registration via Cloud Run API (on first login → create profile row in Cloud SQL)
FR-ONB-01: New users shall be guided through a profile setup flow (name, style preferences, photo)
FR-ONB-02: The system shall present a "First 5 Items" challenge encouraging users to add 5 wardrobe items
FR-ONB-03: The system shall present a "Closet Safari" 7-day challenge: upload 20 items to unlock 1 month Premium free
FR-ONB-04: Completing the Closet Safari challenge shall automatically grant a 30-day Premium trial
FR-ONB-05: Users shall be able to skip onboarding and access the app directly
FR-WRD-01: Users shall add wardrobe items by capturing a photo via camera or selecting from gallery
FR-WRD-02: The system shall compress uploaded images to ≤ 512px width at 85% JPEG quality before upload
FR-WRD-03: Uploaded images shall be stored in a private cloud storage bucket scoped to the user's ID
FR-WRD-04: The system shall automatically remove image backgrounds via Gemini 2.0 Flash image editing (server-side via Cloud Run)
FR-WRD-05: The system shall auto-categorize items using Gemini 2.0 Flash vision analysis, extracting: category, color, secondary colors, pattern, material, style, season suitability, and occasion tags
FR-WRD-06: AI categorization results shall be validated against a fixed taxonomy (valid categories, colors, patterns) with fallback to safe defaults
FR-WRD-07: Users shall be able to manually edit all AI-assigned metadata for any item
FR-WRD-08: Users shall enter optional metadata: item name, brand, purchase price, purchase date, currency
FR-WRD-09: Users shall view their wardrobe in a scrollable gallery grid
FR-WRD-10: The wardrobe gallery shall support filtering by: category, color, season, occasion, brand, neglect status, resale status
FR-WRD-11: Users shall tap an item to view its detail screen showing: image, all metadata, wear count, cost-per-wear, last worn date, wear history
FR-WRD-12: Users shall be able to delete items from their wardrobe
FR-WRD-13: Users shall be able to favorite items for quick access
FR-WRD-14: The system shall track `neglect_status` for items not worn in a configurable number of days (default: 180)
FR-WRD-15: The system shall display a "Neglected" badge on items exceeding the neglect threshold
FR-EXT-01: Users shall bulk-upload up to 50 photos from their gallery for AI extraction
FR-EXT-02: The system shall detect multiple clothing items within a single photo (up to 5 items per photo)
FR-EXT-03: Each detected item shall be auto-categorized with category, color, style, material, and pattern
FR-EXT-04: Background removal shall be applied to each extracted item
FR-EXT-05: Users shall review all extracted items in a confirmation screen before adding to wardrobe
FR-EXT-06: Each extracted item shall have Keep/Remove toggles and editable metadata
FR-EXT-07: The system shall display extraction progress with status updates and estimated time remaining
FR-EXT-08: Extraction jobs shall be tracked in a `wardrobe_extraction_jobs` table with status progression
FR-EXT-09: Items created via extraction shall be tagged with `creation_method = 'ai_extraction'` and linked to the source photo
FR-EXT-10: The system shall detect potential duplicate items during extraction and warn the user
FR-CTX-01: The system shall request location permission and display current weather on the Home screen
FR-CTX-02: Weather data shall be fetched from Open-Meteo API (free, no API key)
FR-CTX-03: The weather widget shall show: temperature, "feels like", condition icon, and location name
FR-CTX-04: Weather data shall be cached for 30 minutes with local persistence (shared_preferences or Hive)
FR-CTX-05: The system shall display a 5-day weather forecast
FR-CTX-06: The system shall map weather conditions to clothing recommendations (e.g., rain → waterproof outerwear)
FR-CTX-07: Users shall connect their device Calendar to the app with permission explanation (device_calendar plugin)
FR-CTX-08: Users shall select which calendars to sync (work, personal, etc.)
FR-CTX-09: The system shall fetch and store events for today and the next 7 days in `calendar_events`
FR-CTX-10: The system shall classify calendar events by type using keyword detection and AI fallback: Work, Social, Active, Formal, Casual
FR-CTX-11: Each classified event shall receive a formality score (1-10)
FR-CTX-12: Users shall be able to re-classify events if the AI classification is incorrect
FR-CTX-13: The system shall compile a context object (weather + events + date + day-of-week) for AI outfit generation
FR-OUT-01: The system shall generate outfit suggestions using Gemini AI, considering: wardrobe items, weather, calendar events, user preferences, and wear history
FR-OUT-02: Generated outfits shall be stored in the `outfits` table with linked items in `outfit_items`
FR-OUT-03: The Home screen shall display the primary daily outfit suggestion with a "Why this outfit?" explanation
FR-OUT-04: Users shall swipe through multiple outfit suggestions (swipe right to save, left to skip)
FR-OUT-05: Users shall be able to manually build outfits by selecting items from categorized lists
FR-OUT-06: Users shall view their outfit history with filters: AI-generated vs manual, occasion, season, date range
FR-OUT-07: Users shall favorite outfits for quick access
FR-OUT-08: Users shall be able to delete outfits from their history
FR-OUT-09: Free users shall be limited to 3 AI outfit generations per day
FR-OUT-10: Premium users shall have unlimited AI outfit generations
FR-OUT-11: The system shall avoid suggesting recently worn items unless the wardrobe is small
FR-EVT-01: The Home screen shall display upcoming events with classified type and formality
FR-EVT-02: The system shall generate event-specific outfit suggestions considering formality, time of day, and weather
FR-EVT-03: Users shall schedule outfits for future days via a "Plan Week" 7-day calendar view
FR-EVT-04: Each day in the planner shall show events and weather preview
FR-EVT-05: Scheduled outfits shall be stored in `calendar_outfits` with event association
FR-EVT-06: Users shall edit or remove scheduled outfits
FR-EVT-07: The system shall send evening reminders before formal events with preparation tips (e.g., "Don't forget to iron your shirt")
FR-EVT-08: Event reminders shall be configurable: timing, event types, snooze/dismiss
FR-TRV-01: The system shall detect multi-day trip events from the calendar
FR-TRV-02: The system shall generate packing suggestions based on trip duration, destination weather, and planned events
FR-TRV-03: Users shall view a checklist interface to mark items as packed
FR-TRV-04: Users shall export the packing list to a notes or reminder app
FR-TRV-05: A travel banner shall appear on the Home screen when an upcoming trip is detected
FR-LOG-01: Users shall log outfits worn today via a "Log Today's Outfit" flow on the Home screen
FR-LOG-02: Logging shall support selecting individual items or a previously saved outfit
FR-LOG-03: Multiple wear logs per day shall be supported
FR-LOG-04: Each wear log shall record: date, items worn, and optional photo
FR-LOG-05: Wear count on each item shall be incremented atomically via database RPC to prevent race conditions
FR-LOG-06: The system shall send an evening reminder notification (default 8 PM, user-configurable) to log the day's outfit
FR-LOG-07: Wear logs shall be viewable in a monthly calendar view with daily activity indicators
FR-ANA-01: The analytics dashboard shall display: total items, total wardrobe value, average cost-per-wear, and category distribution
FR-ANA-02: Cost-per-wear (CPW) shall be calculated as purchase_price / wear_count, color-coded: green (< £5), yellow (£5–20), red (> £20)
FR-ANA-03: The system shall identify neglected items (not worn in 60+ days, configurable) and display them in a dedicated section
FR-ANA-04: The system shall display a "Top 10 Most Worn Items" leaderboard with time period filters
FR-ANA-05: The system shall display a wear frequency bar chart and category distribution pie chart
FR-ANA-06: The system shall provide AI-generated wardrobe insights (summary text)
FR-BRD-01: The analytics dashboard shall include a "Brand Value" section showing: brand name, average CPW, total spent, and total wears, ranked by best value
FR-BRD-02: Brand analytics shall be filterable by category (e.g., "Best value sneakers brand")
FR-BRD-03: Brands shall only appear with a minimum of 3 items
FR-SUS-01: The system shall calculate a sustainability score (0–100) based on 5 weighted factors: avg wear count (30%), % wardrobe worn in 90 days (25%), avg CPW (20%), resale activity (15%), new purchases avoided (10%)
FR-SUS-02: The system shall estimate CO2 savings from re-wearing vs buying new
FR-SUS-03: The sustainability score shall be displayed with color gradient and leaf icon
FR-SUS-04: Users shall see a percentile comparison: "Top X% of Vestiaire users"
FR-SUS-05: An "Eco Warrior" badge shall unlock at sustainability score ≥ 80
FR-GAP-01: The system shall analyze the wardrobe for missing item types by category, formality, color range, and weather coverage
FR-GAP-02: Each detected gap shall be rated: Critical, Important, or Optional
FR-GAP-03: Gap suggestions shall include specific item recommendations (e.g., "Consider adding a beige trench coat")
FR-GAP-04: Users shall be able to dismiss individual gaps
FR-GAP-05: AI-enriched gap analysis shall use Gemini for personalized recommendations beyond basic rule detection
FR-GAP-06: Gap results shall be cached locally and refresh when wardrobe changes
FR-SEA-01: The system shall generate seasonal wardrobe reports (Spring, Summer, Fall, Winter)
FR-SEA-02: Each report shall show: item count per season, most worn items, neglected items, and seasonal readiness score (1–10)
FR-SEA-03: Reports shall include historical comparison (e.g., "This winter you wore 12% more items than last")
FR-SEA-04: Seasonal transition alerts shall notify users 2 weeks before a new season
FR-HMP-01: The system shall display a calendar heatmap showing daily wear activity with color intensity proportional to items worn
FR-HMP-02: The heatmap shall support view modes: Month, Quarter, Year
FR-HMP-03: Users shall tap a day to see a detail overlay with outfits worn that day
FR-HMP-04: The heatmap shall display streak tracking and streak statistics
FR-HLT-01: The system shall calculate a wardrobe health score (0–100) based on 3 weighted factors: % items worn in 90 days (50%), % items with < £5 CPW (30%), size vs utilization ratio (20%)
FR-HLT-02: The health score shall be color-coded: Green (80–100), Yellow (50–79), Red (< 50)
FR-HLT-03: The score shall include recommendations (e.g., "Declutter 8 items to improve health")
FR-HLT-04: A deterministic user comparison shall show percentile ranking
FR-HLT-05: A "Spring Clean" guided declutter mode shall walk users through neglected items with keep/sell/donate options
FR-GAM-01: Users shall earn style points for actions: upload item (+10), log outfit (+5), streak day (+3), first log of day (+2)
FR-GAM-02: The system shall track 6 user levels based on wardrobe item count thresholds: Closet Rookie (0), Style Starter (10), Fashion Explorer (25), Wardrobe Pro (50), Style Expert (100), Style Master (200)
FR-GAM-03: The system shall track consecutive-day streaks for outfit logging, with 1 streak freeze per week
FR-GAM-04: The system shall award badges for achievements, including: First Step, Closet Complete, Week Warrior, Streak Legend (30 days), Early Bird, Rewear Champion (50 re-wears), Circular Seller (1+ listing), Circular Champion (10+ sold), Generous Giver (20+ donated), Monochrome Master, Rainbow Warrior, OG Member, Weather Warrior, Style Guru, Eco Warrior
FR-GAM-05: The profile screen shall display: current level, XP progress bar, current streak, total points, badge collection grid, and recent activity feed
FR-GAM-06: Badges and levels shall be stored server-side with RLS-protected tables (`user_badges`, `user_stats`)
FR-SHP-01: Users shall analyze potential purchases by uploading a screenshot from gallery or camera
FR-SHP-02: Users shall analyze potential purchases by pasting a product URL
FR-SHP-03: URL scraping shall extract product data using Open Graph meta tags and schema.org JSON-LD markup, with fallback to screenshot analysis
FR-SHP-04: The system shall extract structured product data: name, category, color, secondary colors, style, material, pattern, season, formality score (1–10), brand, price
FR-SHP-05: Users shall confirm or edit AI-extracted product data before scoring
FR-SHP-06: The system shall calculate a compatibility score (0–100) based on: color harmony (30%), style consistency (25%), gap filling (20%), versatility (15%), formality match (10%)
FR-SHP-07: The compatibility score shall be displayed with a 5-tier rating system: Perfect Match (90–100), Great Choice (75–89), Good Fit (60–74), Might Work (40–59), Careful (0–39), each with distinct color and icon
FR-SHP-08: The system shall display top matching items from the user's wardrobe, grouped by category, with match reasons
FR-SHP-09: The system shall generate 3 AI-powered insights per scan: style feedback, wardrobe gap assessment, and value proposition
FR-SHP-10: Users shall save scanned products to a shopping wishlist with score, matches, and insights
FR-SHP-11: Scanned products shall be stored in `shopping_scans` for history and re-analysis
FR-SHP-12: The system shall display an empty wardrobe CTA when no items exist for scoring
FR-SOC-01: Users shall create Style Squads (private groups) with a name, optional description, and unique invite code
FR-SOC-02: Users shall invite others to squads via invite code, SMS, or username search
FR-SOC-03: Squad size shall be limited to 20 members
FR-SOC-04: Users shall belong to multiple squads simultaneously
FR-SOC-05: Squad admins shall be able to remove members
FR-SOC-06: Users shall post OOTD (Outfit of the Day) photos to selected squads with optional caption (max 150 chars) and tagged wardrobe items
FR-SOC-07: The Social tab shall display a chronological feed of OOTD posts from all joined squads
FR-SOC-08: Users shall filter the feed by specific squad
FR-SOC-09: Users shall react to posts with a fire emoji (🔥) toggle with reaction count display
FR-SOC-10: Users shall comment on posts (text only, max 200 chars) with notification to post author
FR-SOC-11: Post authors shall delete any comment on their post; users shall delete their own comments
FR-SOC-12: Users shall use "Steal This Look" on any OOTD post to find similar items in their own wardrobe, with AI-powered matching and fallback
FR-SOC-13: "Steal This Look" results shall be color-coded by match quality and saveable as a new outfit
FR-NTF-01: Users shall receive push notifications when a squad member posts an OOTD
FR-NTF-02: Notification settings shall support: All posts, Only morning posts, Off
FR-NTF-03: Quiet hours shall be respected (default: 10 PM – 7 AM) with configurable daily notification limit
FR-NTF-04: Users shall receive an optional daily posting reminder (default 9 AM, user-configurable)
FR-NTF-05: The posting reminder shall be skipped if the user has already posted today
FR-RSL-01: The system shall identify resale candidates based on: not worn in 90+ days, high CPW, and low wear count relative to age
FR-RSL-02: The system shall generate AI-powered resale listings optimized for Vinted/Depop, including: title, description, category, condition estimate, with CPW and sustainability data
FR-RSL-03: Users shall copy listing text to clipboard or share via system share sheet
FR-RSL-04: Items shall track `resale_status` with CHECK constraint: 'listed', 'sold', 'donated', or NULL
FR-RSL-05: The system shall send monthly resale prompt notifications for neglected items with estimated sale price
FR-RSL-06: Users shall dismiss resale prompts per-item ("I'll keep it") or globally via settings
FR-RSL-07: Users shall view resale history on their profile showing items listed, sold, and total earnings
FR-RSL-08: An earnings chart shall display monthly earnings over time
FR-RSL-09: Selling 10+ items shall unlock the "Circular Champion" badge
FR-RSL-10: Resale status changes (listed → sold) shall sync back to the `items` table
FR-DON-01: Users shall mark items as "Donated" from the item detail screen
FR-DON-02: Donations shall be logged in `donation_log` with: item reference, charity/organization, date, estimated value
FR-DON-03: Users shall view donation history on their profile
FR-DON-04: Donating 20+ items shall unlock the "Generous Giver" badge
FR-DON-05: The Spring Clean guided declutter flow shall log donations automatically
FR-PSH-01: The system shall request push notification permission via Firebase Cloud Messaging (FCM)
FR-PSH-02: Push tokens shall be stored in the `profiles` table
FR-PSH-03: Evening wear-log reminders shall be sent at user-configurable time (default 8 PM)
FR-PSH-04: Morning outfit suggestion notifications shall include weather preview
FR-PSH-05: Event-based outfit reminders shall fire the evening before formal events
FR-PSH-06: All notification types shall be independently toggleable in settings

### NonFunctional Requirements

NFR-PERF-01: Image upload and background removal
NFR-PERF-02: AI outfit generation (end-to-end)
NFR-PERF-03: Screenshot product analysis
NFR-PERF-04: URL scraping and analysis
NFR-PERF-05: Bulk photo extraction (20 photos)
NFR-PERF-06: OOTD feed load time
NFR-PERF-07: Wardrobe gallery initial render
NFR-PERF-08: App cold start to interactive
NFR-PERF-09: Compatibility scoring algorithm
NFR-REL-01: System uptime
NFR-REL-02: Database backup frequency
NFR-REL-03: AI service degradation
NFR-REL-04: Offline capability
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
NFR-SCL-01: Concurrent users at launch
NFR-SCL-02: Growth phase
NFR-SCL-03: Scale phase
NFR-SCL-04: Infrastructure cost at 1K MAU
NFR-SCL-05: Infrastructure cost at 10K MAU
NFR-SCL-06: Infrastructure cost at 100K MAU
NFR-ACC-01: Target: WCAG AA compliance for core user flows
NFR-ACC-02: Primary platform: iOS 16+
NFR-ACC-03: Secondary platform: Android (via Flutter — single codebase)
NFR-ACC-04: App orientation: Portrait only
NFR-ACC-05: Light mode UI (dark mode deferred)
NFR-OBS-01: The system shall capture and report client-side errors via an error monitoring service (Sentry)
NFR-OBS-02: AI API costs and usage shall be logged per-user in `ai_usage_log` with model, tokens, latency, and cost
NFR-OBS-03: Server-side logs shall be available via the backend dashboard

### Additional Requirements

- [Architecture] Frontend must use Flutter, backend must use Cloud Run + Cloud SQL + Firebase.
- [Architecture - STARTER TEMPLATE / EPIC 1] Authentication via Firebase Auth requires the backend to explicitly create a `profiles` row in Cloud SQL on first login.
- [Architecture] All AI features must route through Vertex AI / Gemini 2.0 Flash to save costs and avoid external APIs.
- [Architecture] Subscriptions must be managed via RevenueCat.
- [Architecture] All database tables must enforce Row-Level Security (RLS) scoped to `auth.uid()`.
- [UX] Mobile app is locked to portrait orientation; tablet app can rotate.
- [UX] Must achieve WCAG AA compliance (gradient scrims for contrast, 44x44px touch targets).
- [UX] Must implement specific UI patterns: Swipe cards for outfits, Tag Cloud for metadata editing.
- [UX] Must implement Optimistic UI for interactions like wear logging.

### FR Coverage Map

### FR Coverage Map

FR-AUTH-01: Epic 1 - Foundation & Authentication
FR-AUTH-02: Epic 1 - Foundation & Authentication
FR-AUTH-03: Epic 1 - Foundation & Authentication
FR-AUTH-04: Epic 1 - Foundation & Authentication
FR-AUTH-05: Epic 1 - Foundation & Authentication
FR-AUTH-06: Epic 1 - Foundation & Authentication
FR-AUTH-07: Epic 1 - Foundation & Authentication
FR-AUTH-08: Epic 1 - Foundation & Authentication
FR-AUTH-09: Epic 1 - Foundation & Authentication
FR-AUTH-10: Epic 1 - Foundation & Authentication
FR-ONB-01: Epic 1 - Foundation & Authentication
FR-ONB-02: Epic 1 - Foundation & Authentication
FR-ONB-03: Epic 6 - Gamification System
FR-ONB-04: Epic 6 - Gamification System
FR-ONB-05: Epic 1 - Foundation & Authentication
FR-WRD-01: Epic 2 - Digital Wardrobe Core
FR-WRD-02: Epic 2 - Digital Wardrobe Core
FR-WRD-03: Epic 2 - Digital Wardrobe Core
FR-WRD-04: Epic 2 - Digital Wardrobe Core
FR-WRD-05: Epic 2 - Digital Wardrobe Core
FR-WRD-06: Epic 2 - Digital Wardrobe Core
FR-WRD-07: Epic 2 - Digital Wardrobe Core
FR-WRD-08: Epic 2 - Digital Wardrobe Core
FR-WRD-09: Epic 2 - Digital Wardrobe Core
FR-WRD-10: Epic 2 - Digital Wardrobe Core
FR-WRD-11: Epic 2 - Digital Wardrobe Core
FR-WRD-12: Epic 2 - Digital Wardrobe Core
FR-WRD-13: Epic 2 - Digital Wardrobe Core
FR-WRD-14: Epic 2 - Digital Wardrobe Core
FR-WRD-15: Epic 2 - Digital Wardrobe Core
FR-EXT-01: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-02: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-03: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-04: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-05: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-06: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-07: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-08: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-09: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-EXT-10: Epic 10 - AI Wardrobe Extraction (Bulk Import)
FR-CTX-01: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-02: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-03: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-04: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-05: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-06: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-07: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-08: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-09: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-10: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-11: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-12: Epic 3 - Context Integration (Weather & Calendar)
FR-CTX-13: Epic 3 - Context Integration (Weather & Calendar)
FR-OUT-01: Epic 4 - AI Outfit Engine
FR-OUT-02: Epic 4 - AI Outfit Engine
FR-OUT-03: Epic 4 - AI Outfit Engine
FR-OUT-04: Epic 4 - AI Outfit Engine
FR-OUT-05: Epic 4 - AI Outfit Engine
FR-OUT-06: Epic 4 - AI Outfit Engine
FR-OUT-07: Epic 4 - AI Outfit Engine
FR-OUT-08: Epic 4 - AI Outfit Engine
FR-OUT-09: Epic 4 - AI Outfit Engine
FR-OUT-10: Epic 4 - AI Outfit Engine
FR-OUT-11: Epic 4 - AI Outfit Engine
FR-EVT-01: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-02: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-03: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-04: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-05: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-06: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-07: Epic 12 - Calendar Integration & Outfit Planning
FR-EVT-08: Epic 12 - Calendar Integration & Outfit Planning
FR-TRV-01: Epic 12 - Calendar Integration & Outfit Planning
FR-TRV-02: Epic 12 - Calendar Integration & Outfit Planning
FR-TRV-03: Epic 12 - Calendar Integration & Outfit Planning
FR-TRV-04: Epic 12 - Calendar Integration & Outfit Planning
FR-TRV-05: Epic 12 - Calendar Integration & Outfit Planning
FR-LOG-01: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-02: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-03: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-04: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-05: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-06: Epic 5 - Wardrobe Analytics & Wear Logging
FR-LOG-07: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-01: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-02: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-03: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-04: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-05: Epic 5 - Wardrobe Analytics & Wear Logging
FR-ANA-06: Epic 5 - Wardrobe Analytics & Wear Logging
FR-BRD-01: Epic 11 - Advanced Analytics 2.0
FR-BRD-02: Epic 11 - Advanced Analytics 2.0
FR-BRD-03: Epic 11 - Advanced Analytics 2.0
FR-SUS-01: Epic 11 - Advanced Analytics 2.0
FR-SUS-02: Epic 11 - Advanced Analytics 2.0
FR-SUS-03: Epic 11 - Advanced Analytics 2.0
FR-SUS-04: Epic 11 - Advanced Analytics 2.0
FR-SUS-05: Epic 6 - Gamification System
FR-GAP-01: Epic 11 - Advanced Analytics 2.0
FR-GAP-02: Epic 11 - Advanced Analytics 2.0
FR-GAP-03: Epic 11 - Advanced Analytics 2.0
FR-GAP-04: Epic 11 - Advanced Analytics 2.0
FR-GAP-05: Epic 11 - Advanced Analytics 2.0
FR-GAP-06: Epic 11 - Advanced Analytics 2.0
FR-SEA-01: Epic 11 - Advanced Analytics 2.0
FR-SEA-02: Epic 11 - Advanced Analytics 2.0
FR-SEA-03: Epic 11 - Advanced Analytics 2.0
FR-SEA-04: Epic 11 - Advanced Analytics 2.0
FR-HMP-01: Epic 11 - Advanced Analytics 2.0
FR-HMP-02: Epic 11 - Advanced Analytics 2.0
FR-HMP-03: Epic 11 - Advanced Analytics 2.0
FR-HMP-04: Epic 11 - Advanced Analytics 2.0
FR-HLT-01: Epic 13 - Circular Resale Triggers
FR-HLT-02: Epic 13 - Circular Resale Triggers
FR-HLT-03: Epic 13 - Circular Resale Triggers
FR-HLT-04: Epic 13 - Circular Resale Triggers
FR-HLT-05: Epic 13 - Circular Resale Triggers
FR-GAM-01: Epic 6 - Gamification System
FR-GAM-02: Epic 6 - Gamification System
FR-GAM-03: Epic 6 - Gamification System
FR-GAM-04: Epic 6 - Gamification System
FR-GAM-05: Epic 6 - Gamification System
FR-GAM-06: Epic 6 - Gamification System
FR-SHP-01: Epic 8 - Shopping Assistant
FR-SHP-02: Epic 8 - Shopping Assistant
FR-SHP-03: Epic 8 - Shopping Assistant
FR-SHP-04: Epic 8 - Shopping Assistant
FR-SHP-05: Epic 8 - Shopping Assistant
FR-SHP-06: Epic 8 - Shopping Assistant
FR-SHP-07: Epic 8 - Shopping Assistant
FR-SHP-08: Epic 8 - Shopping Assistant
FR-SHP-09: Epic 8 - Shopping Assistant
FR-SHP-10: Epic 8 - Shopping Assistant
FR-SHP-11: Epic 8 - Shopping Assistant
FR-SHP-12: Epic 8 - Shopping Assistant
FR-SOC-01: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-02: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-03: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-04: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-05: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-06: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-07: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-08: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-09: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-10: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-11: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-12: Epic 9 - Social OOTD Feed (Style Squads)
FR-SOC-13: Epic 9 - Social OOTD Feed (Style Squads)
FR-NTF-01: Epic 9 - Social OOTD Feed (Style Squads)
FR-NTF-02: Epic 9 - Social OOTD Feed (Style Squads)
FR-NTF-03: Epic 9 - Social OOTD Feed (Style Squads)
FR-NTF-04: Epic 9 - Social OOTD Feed (Style Squads)
FR-NTF-05: Epic 9 - Social OOTD Feed (Style Squads)
FR-RSL-01: Epic 13 - Circular Resale Triggers
FR-RSL-02: Epic 7 - Resale Integration & Subscription
FR-RSL-03: Epic 7 - Resale Integration & Subscription
FR-RSL-04: Epic 7 - Resale Integration & Subscription
FR-RSL-05: Epic 13 - Circular Resale Triggers
FR-RSL-06: Epic 13 - Circular Resale Triggers
FR-RSL-07: Epic 7 - Resale Integration & Subscription
FR-RSL-08: Epic 7 - Resale Integration & Subscription
FR-RSL-09: Epic 6 - Gamification System
FR-RSL-10: Epic 7 - Resale Integration & Subscription
FR-DON-01: Epic 13 - Circular Resale Triggers
FR-DON-02: Epic 13 - Circular Resale Triggers
FR-DON-03: Epic 13 - Circular Resale Triggers
FR-DON-04: Epic 6 - Gamification System
FR-DON-05: Epic 13 - Circular Resale Triggers
FR-PSH-01: Epic 1 - Foundation & Authentication
FR-PSH-02: Epic 1 - Foundation & Authentication
FR-PSH-03: Epic 5 - Wardrobe Analytics & Wear Logging
FR-PSH-04: Epic 4 - AI Outfit Engine
FR-PSH-05: Epic 12 - Calendar Integration & Outfit Planning
FR-PSH-06: Epic 1 - Foundation & Authentication

## Epic List

### Epic 1: Foundation & 
Authentication
Users can register, securely log in, and begin their personalized Vestiaire journey with basic onboarding.
**FRs covered:** FR-AUTH-01, FR-AUTH-02, FR-AUTH-03, FR-AUTH-04, FR-AUTH-05, FR-AUTH-06, FR-AUTH-07, FR-AUTH-08, FR-AUTH-09, FR-AUTH-10, FR-ONB-01, FR-ONB-02, FR-ONB-05, FR-PSH-01, FR-PSH-02, FR-PSH-06

### Epic 2: Digital Wardrobe Core
Users can digitize their clothing items using AI background removal and categorization, and manage their personal digital closet.
**FRs covered:** FR-WRD-01, FR-WRD-02, FR-WRD-03, FR-WRD-04, FR-WRD-05, FR-WRD-06, FR-WRD-07, FR-WRD-08, FR-WRD-09, FR-WRD-10, FR-WRD-11, FR-WRD-12, FR-WRD-13, FR-WRD-14, FR-WRD-15

### Epic 3: Context Integration (Weather & Calendar)
Users can see real-time weather and sync their calendars so the app understands their daily context.
**FRs covered:** FR-CTX-01, FR-CTX-02, FR-CTX-03, FR-CTX-04, FR-CTX-05, FR-CTX-06, FR-CTX-07, FR-CTX-08, FR-CTX-09, FR-CTX-10, FR-CTX-11, FR-CTX-12, FR-CTX-13

### Epic 4: AI Outfit Engine
Users receive daily smart outfit suggestions tailored to their wardrobe, weather, and schedule, and can log what they wear.
**FRs covered:** FR-OUT-01, FR-OUT-02, FR-OUT-03, FR-OUT-04, FR-OUT-05, FR-OUT-06, FR-OUT-07, FR-OUT-08, FR-OUT-09, FR-OUT-10, FR-OUT-11, FR-PSH-04

### Epic 5: Wardrobe Analytics & Wear Logging
Users can view how much they wear their clothes, track cost-per-wear, and identify neglected items.
**FRs covered:** FR-LOG-01, FR-LOG-02, FR-LOG-03, FR-LOG-04, FR-LOG-05, FR-LOG-06, FR-LOG-07, FR-ANA-01, FR-ANA-02, FR-ANA-03, FR-ANA-04, FR-ANA-05, FR-ANA-06, FR-PSH-03

### Epic 6: Gamification System
Users earn points, badges, and build streaks to reinforce the habit of sustainable wardrobe management.
**FRs covered:** FR-ONB-03, FR-ONB-04, FR-SUS-05, FR-GAM-01, FR-GAM-02, FR-GAM-03, FR-GAM-04, FR-GAM-05, FR-GAM-06, FR-RSL-09, FR-DON-04

### Epic 7: Resale Integration & Subscription
Users can manage their premium subscription and generate AI-powered resale listings to sell unwanted items.
**FRs covered:** FR-RSL-02, FR-RSL-03, FR-RSL-04, FR-RSL-07, FR-RSL-08, FR-RSL-10

### Epic 8: Shopping Assistant
Users can check if a potential new purchase matches their existing wardrobe before buying, reducing shopping mistakes.
**FRs covered:** FR-SHP-01, FR-SHP-02, FR-SHP-03, FR-SHP-04, FR-SHP-05, FR-SHP-06, FR-SHP-07, FR-SHP-08, FR-SHP-09, FR-SHP-10, FR-SHP-11, FR-SHP-12

### Epic 9: Social OOTD Feed (Style Squads)
Users can create private groups with friends to share daily outfits, react, and get inspiration from each other.
**FRs covered:** FR-SOC-01, FR-SOC-02, FR-SOC-03, FR-SOC-04, FR-SOC-05, FR-SOC-06, FR-SOC-07, FR-SOC-08, FR-SOC-09, FR-SOC-10, FR-SOC-11, FR-SOC-12, FR-SOC-13, FR-NTF-01, FR-NTF-02, FR-NTF-03, FR-NTF-04, FR-NTF-05

### Epic 10: AI Wardrobe Extraction (Bulk Import)
Users can quickly digitize dozens of items from existing photos to overcome the cold-start problem of building a digital closet.
**FRs covered:** FR-EXT-01, FR-EXT-02, FR-EXT-03, FR-EXT-04, FR-EXT-05, FR-EXT-06, FR-EXT-07, FR-EXT-08, FR-EXT-09, FR-EXT-10

### Epic 11: Advanced Analytics 2.0
Users receive deep insights into brand value, sustainability impact (CO2), wardrobe gaps, and seasonal readiness.
**FRs covered:** FR-BRD-01, FR-BRD-02, FR-BRD-03, FR-SUS-01, FR-SUS-02, FR-SUS-03, FR-SUS-04, FR-GAP-01, FR-GAP-02, FR-GAP-03, FR-GAP-04, FR-GAP-05, FR-GAP-06, FR-SEA-01, FR-SEA-02, FR-SEA-03, FR-SEA-04, FR-HMP-01, FR-HMP-02, FR-HMP-03, FR-HMP-04

### Epic 12: Calendar Integration & Outfit Planning
Users can schedule outfits for specific future events and receive automated packing lists for multi-day trips.
**FRs covered:** FR-EVT-01, FR-EVT-02, FR-EVT-03, FR-EVT-04, FR-EVT-05, FR-EVT-06, FR-EVT-07, FR-EVT-08, FR-TRV-01, FR-TRV-02, FR-TRV-03, FR-TRV-04, FR-TRV-05, FR-PSH-05

### Epic 13: Circular Resale Triggers
Users receive proactive nudges to sell or donate neglected items to improve their overall wardrobe health score.
**FRs covered:** FR-HLT-01, FR-HLT-02, FR-HLT-03, FR-HLT-04, FR-HLT-05, FR-RSL-01, FR-RSL-05, FR-RSL-06, FR-DON-01, FR-DON-02, FR-DON-03, FR-DON-05


## Epic 1: Foundation & Authentication

Users can register, securely log in, and begin their personalized Vestiaire journey with basic onboarding.

### Story 1.1: Greenfield Project Bootstrap

As a Team,
I want the Flutter app, Cloud Run API, database migrations, and CI foundations scaffolded consistently,
So that every subsequent feature story can be implemented on a stable baseline.

**Acceptance Criteria:**

**Given** the repository is cloned into a new development environment
**When** the bootstrap instructions are followed
**Then** the Flutter mobile app and Cloud Run API both install and start successfully with example environment variables
**And** the initial CI pipelines validate mobile and API builds on pull requests
**And** the first database migration and policy scaffolding can be applied in a fresh environment
**And** (Greenfield Setup Requirement)

### Story 1.2: Authentication Data Foundation

As a New User,
I want my account record provisioned securely the first time I authenticate,
So that all of my app data can be stored and isolated correctly from the start.

**Acceptance Criteria:**

**Given** the GCP environment is configured
**When** a user authenticates via Firebase Auth for the first time
**Then** the Cloud Run API automatically creates a corresponding row in the `profiles` table in Cloud SQL
**And** the `profiles` table enforces Row-Level Security (RLS) ensuring users can only read/write their own profile data
**And** duplicate provisioning attempts are handled idempotently
**And** (FR-AUTH-10)

### Story 1.3: User Registration & Native Sign-In

As a New User,
I want to register for a new account using Email, Apple, or Google,
So that I can securely access my personal digital wardrobe.

**Acceptance Criteria:**

**Given** I am on the launch screen
**When** I register with email and password
**Then** the system sends an email verification link before granting full app access
**And** when I tap to sign in with Apple or Google, the native authentication sheet completes the sign-in flow successfully
**And** my Firebase session token is securely stored in the iOS Keychain (via `flutter_secure_storage`)
**And** the signed-in session resolves to a persisted profile record in Cloud SQL
**And** (FR-AUTH-01, FR-AUTH-02, FR-AUTH-03, FR-AUTH-05)

### Story 1.4: Password Reset, Session Refresh, and Sign Out

As a User,
I want to recover access to my account, stay signed in reliably, and sign out cleanly,
So that my account experience is secure and low-friction.

**Acceptance Criteria:**

**Given** I am on the authentication flow
**When** I tap "Forgot password"
**Then** the system sends me an email reset link
**And** when my access token expires during normal app use, the app refreshes the session transparently using the stored refresh token
**And** when I choose to sign out, all local session data is cleared from the device and protected screens are no longer accessible
**And** (FR-AUTH-04, FR-AUTH-06, FR-AUTH-07)

### Story 1.5: Onboarding Profile Setup & First 5 Items

As a User,
I want to complete or skip a lightweight onboarding flow after sign-in,
So that I can personalize the app quickly without being blocked from using it.

**Acceptance Criteria:**

**Given** I have authenticated successfully for the first time
**When** I enter onboarding
**Then** I can provide my name, style preferences, and profile photo
**And** the system presents a "First 5 Items" challenge encouraging me to digitize my initial wardrobe
**And** I can skip onboarding and still reach the main application shell
**And** profile changes are immediately reflected in the UI and persisted to the `profiles` table
**And** (FR-AUTH-08, FR-ONB-01, FR-ONB-02, FR-ONB-05)

### Story 1.6: Push Notification Permissions & Preferences

As a User,
I want to control notification permission and notification categories during setup and later in settings,
So that the app can notify me when useful without spamming me.

**Acceptance Criteria:**

**Given** I am completing the initial profile setup or editing notification settings later
**When** I reach the notifications step
**Then** the system requests FCM push notification permissions
**And** if granted, the FCM push token is securely saved to my profile record in the database
**And** I can independently toggle supported notification types in settings
**And** (FR-PSH-01, FR-PSH-02, FR-PSH-06)

### Story 1.7: Account Deletion (GDPR)

As a User,
I want to completely delete my account and all associated data,
So that I have full control over my privacy and data footprint.

**Acceptance Criteria:**

**Given** I am on the Profile Settings screen
**When** I tap "Delete Account" and confirm my decision
**Then** my Firebase Auth record is deleted
**And** my `profiles` row in Cloud SQL is deleted, triggering a cascading delete of all my wardrobe data and images
**And** I am returned to the launch screen
**And** (FR-AUTH-09)

## Epic 2: Digital Wardrobe Core

Users can digitize their clothing items using AI background removal and categorization, and manage their personal digital closet.

### Story 2.1: Upload Item Photo (Camera & Gallery)

As a User,
I want to take a photo of a clothing item or upload one from my gallery,
So that I can begin digitizing my wardrobe.

**Acceptance Criteria:**

**Given** I am on the Wardrobe screen
**When** I tap the "Add Item" button
**Then** I am prompted to choose between Camera or Photo Gallery
**And** any photo selected is compressed to ≤ 512px width at 85% JPEG quality before upload to preserve bandwidth
**And** (FR-WRD-01, FR-WRD-02)

### Story 2.2: AI Background Removal & Upload

As a User,
I want the background of my clothing photo to be automatically removed,
So that my digital wardrobe looks clean and consistent.

**Acceptance Criteria:**

**Given** I have selected a photo to upload
**When** the image is processed by the server
**Then** the image is stored in a private GCP bucket
**And** the Gemini 2.0 Flash API is called to perform background removal
**And** the cleaned image with a transparent/white background is returned and saved
**And** (FR-WRD-03, FR-WRD-04)

### Story 2.3: AI Item Categorization & Tagging

As a User,
I want the AI to automatically identify and tag my clothing item,
So that I don't have to manually enter all the details.

**Acceptance Criteria:**

**Given** my clothing image has been processed
**When** the Gemini vision analysis completes
**Then** the item is auto-categorized into the fixed taxonomy (category, color, secondary colors, pattern, material, style, season, occasion)
**And** the AI results fall back to safe defaults if detection fails
**And** (FR-WRD-05, FR-WRD-06)

### Story 2.4: Manual Metadata Editing & Creation

As a User,
I want to review and edit the AI-generated tags and add custom details,
So that my item records are perfectly accurate.

**Acceptance Criteria:**

**Given** the AI has categorized my new item
**When** the "Review Item" Tag Cloud UI is presented
**Then** I can edit any AI-assigned tags
**And** I can enter optional metadata (item name, brand, purchase price, purchase date)
**And** saving creates the item in the `items` table
**And** (FR-WRD-07, FR-WRD-08)

### Story 2.5: Wardrobe Grid & Filtering

As a User,
I want to browse my wardrobe in a grid and filter by various attributes,
So that I can easily find specific pieces.

**Acceptance Criteria:**

**Given** I have items in my digital wardrobe
**When** I view the Wardrobe tab
**Then** I see my items in a fast, scrollable gallery grid (cached locally)
**And** I can apply filters (category, color, season, occasion, brand) to narrow the view
**And** (FR-WRD-09, FR-WRD-10)

### Story 2.6: Item Detail View & Management

As a User,
I want to view the full details of an item and manage it,
So that I can see its wear history, favorite it, or delete it if needed.

**Acceptance Criteria:**

**Given** I am browsing the Wardrobe grid
**When** I tap on an item
**Then** I see its detail screen showing the image and all metadata
**And** I can see its wear count, cost-per-wear (CPW), and last worn date
**And** I can toggle its "favorite" status or delete it from my wardrobe
**And** (FR-WRD-11, FR-WRD-12, FR-WRD-13)

### Story 2.7: Neglect Detection & Badging

As a User,
I want to quickly see which items I haven't worn recently,
So that I can decide whether to wear them or declutter them.

**Acceptance Criteria:**

**Given** I have an item that hasn't been worn in over 180 days (configurable)
**When** I view my Wardrobe grid or the item detail screen
**Then** the system calculates its `neglect_status`
**And** a visual "Neglected" badge appears on the item
**And** I can filter my wardrobe specifically for "neglected" items
**And** (FR-WRD-14, FR-WRD-15)

## Epic 3: Context Integration (Weather & Calendar)

Users can see real-time weather and sync their calendars so the app understands their daily context.

### Story 3.1: Location Permission & Weather Widget

As a User,
I want to grant location access and see the current weather on my Home screen,
So that I know what conditions to dress for today.

**Acceptance Criteria:**

**Given** I am on the Home screen
**When** the system requests foreground location permission (if not granted)
**Then** I can grant permission
**And** the localized weather widget appears showing: temperature, "feels like", condition icon, and location name
**And** (FR-CTX-01, FR-CTX-03)

### Story 3.2: Fast Weather Loading & Local Caching

As a User,
I want weather data to load quickly and remain available for a short period without repeated network calls,
So that the home screen feels responsive every time I open it.

**Acceptance Criteria:**

**Given** the user has granted location permission
**When** the app makes a request to Open-Meteo (lat/long)
**Then** the current weather condition and a 5-day forecast are returned
**And** the data is cached locally (via shared_preferences or Hive) for 30 minutes to reduce network calls
**And** (FR-CTX-02, FR-CTX-04, FR-CTX-05)

### Story 3.3: Practical Weather-Aware Outfit Context

As a User,
I want the app to translate weather conditions into practical clothing constraints,
So that outfit suggestions are usable in real life and not just visually coordinated.

**Acceptance Criteria:**

**Given** a specific weather condition (e.g., Rain, Snow, Hot) is detected
**When** compiling the context object for Gemini
**Then** the system includes specific clothing requirement flags (e.g., "requires: waterproof_outerwear", "avoid: suede")
**And** (FR-CTX-06, FR-CTX-13)

### Story 3.4: Calendar Sync Permission & Selection

As a User,
I want to connect my device calendar to Vestiaire,
So that the app knows what events I have planned.

**Acceptance Criteria:**

**Given** I am on the Profile Settings screen or Home screen
**When** I tap to connect my calendar
**Then** the system explains why permission is needed and requests native calendar access (via `device_calendar`)
**And** I can select which specific calendars to sync (e.g., Work but not Personal)
**And** (FR-CTX-07, FR-CTX-08)

### Story 3.5: Calendar Event Fetching & Classification

As a User,
I want my upcoming events fetched and classified automatically,
So that outfit suggestions reflect what I actually have planned.

**Acceptance Criteria:**

**Given** the user has synced their calendar
**When** the system runs its background sync or foreground refresh
**Then** events for today and the next 7 days are fetched and stored in the `calendar_events` table
**And** Gemini is used (or local keyword fallback) to classify the event type (Work, Social, Active, Formal, Casual)
**And** the event receives a computed formality score (1-10)
**And** (FR-CTX-09, FR-CTX-10, FR-CTX-11)

### Story 3.6: Manual Event Classification Override

As a User,
I want to manually correct the AI's classification or formality score for an event,
So that my outfit suggestions are precisely tailored.

**Acceptance Criteria:**

**Given** an event has been synced and classified
**When** I tap on the event details from the Home or Calendar view
**Then** I can edit the Event Type override and Formality Score slider
**And** my overrides are saved to the `calendar_events` table and used for future suggestions
**And** (FR-CTX-12)

## Epic 4: AI Outfit Engine

Users receive daily smart outfit suggestions tailored to their wardrobe, weather, and schedule, and can log what they wear.

### Story 4.1: Daily AI Outfit Generation

As a User,
I want the app to suggest a daily outfit based on my wardrobe, the weather, and my calendar events,
So that I don't have to spend time deciding what to wear each morning.

**Acceptance Criteria:**

**Given** I have at least 3 items in my wardrobe (top, bottom, shoes)
**When** I open the app in the morning (or pull to refresh Home)
**Then** the system calls Gemini to generate an outfit suggestion
**And** the generation considers the context object (weather, calendar events, wear history)
**And** the suggested outfit is displayed prominently on the Home screen
**And** the system explains "Why this outfit?" (e.g., "Formal enough for your 3 PM meeting, light enough for 22°C")
**And** (FR-OUT-01, FR-OUT-03)

### Story 4.2: Outfit Generation Swipe UI

As a User,
I want to quickly review and accept or reject outfit suggestions,
So that I can find a look I like interactively.

**Acceptance Criteria:**

**Given** the AI has generated outfit suggestions
**When** I view the Home screen
**Then** I can swipe right on a suggestion to save it to my outfits list
**And** I can swipe left to reject it and see the next suggestion
**And** saved outfits are persisted to the `outfits` and `outfit_items` tables
**And** (FR-OUT-02, FR-OUT-04)

### Story 4.3: Manual Outfit Building

As a User,
I want to create my own outfits manually by selecting items from my wardrobe,
So that I can save my favorite combinations without relying strictly on AI.

**Acceptance Criteria:**

**Given** I am on the Outfits tab
**When** I tap to create a manual outfit
**Then** I am presented with a categorized selection interface (Tops, Bottoms, Shoes, Options)
**And** I can select items to assemble an outfit
**And** I can save the outfit with an optional name and occasion tag
**And** (FR-OUT-05)

### Story 4.4: Outfit History & Management

As a User,
I want to view, filter, and manage my saved outfits,
So that I can quickly re-wear proven looks.

**Acceptance Criteria:**

**Given** I have saved outfits
**When** I navigate to the Outfits tab
**Then** I see my outfit history
**And** I can filter them by AI-generated vs manual, occasion, season, or date range
**And** I can toggle favorite status for quick access
**And** I can delete any outfit from my history
**And** (FR-OUT-06, FR-OUT-07, FR-OUT-08)

### Story 4.5: AI Usage Limits Enforcement

As a Free User,
I want to be restricted to a daily quota of AI outfit generations,
So that the platform maintains its freemium business model constraints.

**Acceptance Criteria:**

**Given** I am a free-tier user
**When** I request (or the system automatically requests) an AI outfit generation
**Then** the Cloud Run API checks my usage via server-side RPC against the `usage_limits` table
**And** if I have completed 3 generations today, the generation is blocked and a "Premium CTA" is shown
**And** if I am Premium, the generation proceeds without a block
**And** (FR-OUT-09, FR-OUT-10)

### Story 4.6: Recency Bias Mitigation

As a User,
I want the AI to avoid suggesting clothes I've worn too recently,
So that my daily looks remain varied and I don't look like I wear the same thing every day.

**Acceptance Criteria:**

**Given** the AI is generating an outfit
**When** compiling the context object
**Then** the system retrieves items logged as worn in the last 7 days from `wear_logs`
**And** passes an instruction to Gemini to avoid those specific items unless the user's wardrobe is smaller than 10 items
**And** (FR-OUT-11)

### Story 4.7: Morning Outfit Notifications

As a User,
I want to receive a morning outfit suggestion notification with the day's weather context,
So that I can make a fast clothing decision before opening the app.

**Acceptance Criteria:**

**Given** I have enabled morning outfit notifications
**When** my configured morning notification time is reached
**Then** the system sends a push notification containing a weather-aware outfit prompt
**And** the preview includes the day's weather context
**And** tapping the notification opens the Today experience in the app
**And** (FR-PSH-04)

## Epic 5: Wardrobe Analytics & Wear Logging

Users can view how much they wear their clothes, track cost-per-wear, and identify neglected items.

### Story 5.1: Log Today's Outfit & Wear Counts

As a User,
I want to log what I am wearing today quickly,
So that I can build my wear history and accurately track the value of my wardrobe.

**Acceptance Criteria:**

**Given** I am on the Home screen
**When** I tap "Log Today's Outfit"
**Then** I can select individual items or a previously saved outfit
**And** the action is recorded in `wear_logs` and `wear_log_items` with today's date
**And** the `wear_count` on each selected item in the `items` table is incremented atomically (via DB RPC)
**And** the UI updates optimistically to reflect the logged state
**And** (FR-LOG-01, FR-LOG-02, FR-LOG-03, FR-LOG-04, FR-LOG-05)

### Story 5.2: Wear Logging Evening Reminder

As a User,
I want to be reminded in the evening to log my outfit,
So that I don't forget to maintain my wear streak.

**Acceptance Criteria:**

**Given** I have push notifications enabled
**When** the time reaches 8:00 PM (or my custom time)
**Then** the system sends a push notification reminding me to log my outfit
**And** clicking the notification takes me directly to the "Log Today's Outfit" flow
**And** the notification is configurable or toggleable in Settings
**And** (FR-LOG-06, FR-PSH-03)

### Story 5.3: Monthly Wear Calendar View

As a User,
I want to see a calendar view of my logging activity,
So that I can visually track my consistency and history over the month.

**Acceptance Criteria:**

**Given** I have logged outfits across several days
**When** I view the Logging Calendar tab
**Then** I see a month view with indicators on days I have logged an outfit
**And** tapping a day shows the specific items/outfit worn
**And** I can navigate backward and forward through months
**And** (FR-LOG-07)

### Story 5.4: Basic Wardrobe Value Analytics

As a User,
I want to see the total value of my wardrobe and average Cost-Per-Wear,
So that I understand my fashion spending efficiency.

**Acceptance Criteria:**

**Given** I have items with purchase prices and wear counts
**When** I navigate to the Analytics dashboard
**Then** I see the total number of items and the total sum purchase value
**And** the system calculates the overall Average Cost-Per-Wear (Total Value / Total Wears)
**And** individual item CPW is color-coded: green (< £5), yellow (£5-20), red (> £20)
**And** (FR-ANA-01, FR-ANA-02)

### Story 5.5: Top Worn & Neglected Items Analytics

As a User,
I want to see my most worn items and items I haven't worn in a long time,
So that I can identify my staples and clear out dead weight.

**Acceptance Criteria:**

**Given** I have a history of wear logs
**When** I view the Analytics dashboard
**Then** I can see a "Top 10 Most Worn Items" leaderboard with relative time filters (30, 90, All Time)
**And** I can see a dedicated section for "Neglected Items" (not worn in 60+ days)
**And** (FR-ANA-03, FR-ANA-04)

### Story 5.6: Category Distribution Charts

As a User,
I want to visualize how my wardrobe is distributed across categories,
So that I can see if I own too many jackets relative to tops.

**Acceptance Criteria:**

**Given** my wardrobe items are categorized
**When** I scroll down the Analytics dashboard
**Then** I see a pie chart or bar chart displaying the distribution of items by category
**And** the chart calculates percentages dynamically based on my item data
**And** a secondary chart shows Wear Frequency distribution over the week
**And** (FR-ANA-05)

### Story 5.7: AI-Generated Analytics Summary

As a Premium User,
I want a simple, human-readable summary of my wardrobe analytics,
So that I can grasp the key takeaways without analyzing the raw numbers myself.

**Acceptance Criteria:**

**Given** I am a Premium user viewing the Analytics dashboard
**When** the dashboard has calculated all underlying metrics
**Then** the system calls Gemini to generate a short, encouraging summary of my wardrobe health
**And** the text highlights a key positive habit and one constructive suggestion
**And** (FR-ANA-06)

## Epic 6: Gamification System

Users earn points, badges, and build streaks to reinforce the habit of sustainable wardrobe management.

### Story 6.1: Style Points Rewards

As a User,
I want to earn points for sustainable wardrobe actions,
So that progress feels immediate and motivating.

**Acceptance Criteria:**

**Given** a user performs a point-granting action (upload item, log outfit, etc.)
**When** the action completes successfully
**Then** the corresponding points (+10, +5, +3, +2) are atomically added to the user's `user_stats` profile server-side
**And** the UI animates the points gained (Flutter + Rive pattern)
**And** (FR-GAM-01)

### Story 6.2: User Progression Levels

As a User,
I want to see my "Style Level" increase as my wardrobe grows,
So that I feel a sense of progression from Rookie to Master.

**Acceptance Criteria:**

**Given** I have added my 10th wardrobe item
**When** the system recalculates my level
**Then** my level upgrades from "Closet Rookie" to "Style Starter"
**And** a celebratory modal explains what I unlocked
**And** my profile displays my current level and an XP bar to the next tier
**And** (FR-GAM-02, FR-GAM-05)

### Story 6.3: Streak Tracking & Freezes

As a User,
I want to track how many consecutive days I've logged an outfit,
So that I build a daily habit of engaging with my wardrobe.

**Acceptance Criteria:**

**Given** I log an outfit today
**When** the system evaluates my `wear_logs`
**Then** my `current_streak` in `user_stats` increments by 1
**And** if I miss a day but have a "streak freeze" available (1/week), my streak doesn't reset
**And** my profile displays my current streak prominently
**And** (FR-GAM-03)

### Story 6.4: Badge Achievement System

As a User,
I want to earn specific badges for reaching milestones,
So that I can showcase my sustainable fashion journey.

**Acceptance Criteria:**

**Given** I meet the criteria for a specific badge (e.g., "Streak Legend" for 30 days)
**When** the background job or atomic RPC evaluates my stats
**Then** the badge is added to my `user_badges` table
**And** the badge illuminates in my Profile "Badge Collection Grid"
**And** badge rules cover streak, sustainability, resale, and donation milestones including Eco Warrior, Circular Champion, and Generous Giver
**And** (FR-GAM-04, FR-GAM-06, FR-SUS-05, FR-RSL-09, FR-DON-04)

### Story 6.5: Challenge Rewards (Premium Trial)

As a New User,
I want to unlock a free month of Premium by completing the Closet Safari challenge,
So that I am incentivized to digitize my first 20 items quickly.

**Acceptance Criteria:**

**Given** I have accepted the "Closet Safari" challenge
**When** I upload my 20th item within 7 days of signup
**Then** the system automatically grants me a 30-day Premium trial via RevenueCat integration
**And** I receive a congratulatory notification and UX celebration
**And** (FR-ONB-03, FR-ONB-04)

## Epic 7: Resale Integration & Subscription

Users can manage their premium subscription and generate AI-powered resale listings to sell unwanted items.

### Story 7.1: Premium Subscription Purchase

As a Free User,
I want to upgrade to Premium using my device's native payment system,
So that I can access unlimited AI features and advanced analytics.

**Acceptance Criteria:**

**Given** I am on the paywall screen
**When** I select the £4.99/month Premium tier
**Then** RevenueCat processes the in-app purchase (IAP) through the App Store/Play Store
**And** my access level is immediately updated server-side without requiring an app restart
**And** (Project-Type SaaS Requirement)

### Story 7.2: Premium Feature Access Enforcement

As a Free or Premium User,
I want the app to consistently grant or block premium-only features based on my entitlement state,
So that billing behavior is predictable and trustworthy.

**Acceptance Criteria:**

**Given** a user is on the Free tier
**When** they attempt to access an Advanced Analytic or exceed an AI limit
**Then** the backend API blocks the request and returns a 403 or specific error code
**And** the client displays the Paywall
**And** changes to subscription status naturally sync via RevenueCat webhooks
**And** (NFR-SEC-06)

### Story 7.3: AI Resale Listing Generation

As a User,
I want the AI to write a Vinted/Depop-optimized listing for an item I want to sell,
So that I save time on copywriting and improve my chances of a sale.

**Acceptance Criteria:**

**Given** I am on the detail screen for a specific wardrobe item
**When** I tap "Generate Resale Listing"
**Then** Gemini analyzes the item's metadata, original image, and (if applicable) CPW data
**And** returns a structured listing: Catchy Title, Detailed Description, Condition Estimate, and targeted hashtags
**And** free users are limited to 2 generations per month
**And** (FR-RSL-02)

### Story 7.4: Resale Status & History Tracking

As a User,
I want to track the lifecycle of items I am selling, from listed to sold,
So that I can see how much money I've recouped from my wardrobe.

**Acceptance Criteria:**

**Given** I have an item marked for resale
**When** I change its `resale_status` from 'listed' to 'sold'
**Then** it is moved to `resale_history` with the sale date and amount
**And** the linked item record is updated to keep the `items` table in sync with the resale lifecycle
**And** my Profile updates to show total items sold and total earnings over time
**And** I can copy the generated listing text to my clipboard securely
**And** (FR-RSL-03, FR-RSL-04, FR-RSL-07, FR-RSL-08, FR-RSL-10)

## Epic 8: Shopping Assistant

Users can check if a potential new purchase matches their existing wardrobe before buying, reducing shopping mistakes.

### Story 8.1: Product URL Scraping

As a User,
I want to paste a link to a clothing item I'm considering buying,
So that the app can extract its details automatically.

**Acceptance Criteria:**

**Given** I am on the Shopping Assistant tab
**When** I paste a valid URL (e.g., from Zara, ASOS)
**Then** the backend scrapes the URL for Open Graph meta tags or JSON-LD schema
**And** it extracts the product image, name, brand, and price within 8 seconds
**And** (FR-SHP-02, FR-SHP-03, FR-SHP-04, NFR-PERF-04)

### Story 8.2: Product Screenshot Upload

As a User,
I want to upload a screenshot of an item I found on Instagram or a shopping app,
So that the app can extract its details when a URL isn't available.

**Acceptance Criteria:**

**Given** I am on the Shopping Assistant tab
**When** I upload a screenshot containing a piece of clothing
**Then** Gemini Vision analyzes the image and extracts the product color, category, style, and (if visible) brand/price within 5 seconds
**And** (FR-SHP-01, FR-SHP-04, NFR-PERF-03)

### Story 8.3: Review Extracted Product Data

As a User,
I want to review and edit the details the app extracted from my link or screenshot,
So that the compatibility score is based accurately on what the item actually is.

**Acceptance Criteria:**

**Given** product details have been extracted
**When** I am on the validation step
**Then** I can correct the category, colors, price, and formality score before proceeding to analysis
**And** (FR-SHP-05)

### Story 8.4: Purchase Compatibility Scoring

As a User,
I want a potential purchase scored against my wardrobe,
So that I can tell whether it is a smart buy before spending money.

**Acceptance Criteria:**

**Given** a validated potential purchase and a populated wardrobe
**When** the compatibility score is requested
**Then** Gemini analyzes the match based on: color harmony, style consistency, wardrobe gaps, versatility, and formality
**And** generates a score (0-100) mapped to a 5-tier rating system (Perfect Match down to Careful)
**And** the algorithm completes the scoring even if the user has 500+ items
**And** (FR-SHP-06, FR-SHP-07, NFR-PERF-09)

### Story 8.5: Shopping Match & Insight Display

As a User,
I want to see exactly *why* an item scored the way it did and what I can wear it with,
So that I make an informed purchase decision.

**Acceptance Criteria:**

**Given** the compatibility scoring is complete
**When** the results screen loads
**Then** I see the top matching items from my own wardrobe grouped by category
**And** I see 3 AI-generated insights (style feedback, gap assessment, value proposition)
**And** I can save the full scan to a "Shopping Wishlist"
**And** if my wardrobe is totally empty, I am prompted to add items first
**And** (FR-SHP-08, FR-SHP-09, FR-SHP-10, FR-SHP-11, FR-SHP-12)

## Epic 9: Social OOTD Feed (Style Squads)

Users can create private groups with friends to share daily outfits, react, and get inspiration from each other.

### Story 9.1: Squad Creation & Management

As a User,
I want to create a private Style Squad and invite my friends,
So that we have a secure, intimate space to share our outfits.

**Acceptance Criteria:**

**Given** I am on the Social tab
**When** I tap "Create Squad"
**Then** I can name the squad and optionally describe it
**And** the system generates a unique invite code/link
**And** the `style_squad` and my `squad_memberships` (as Admin) are created server-side
**And** I can remove members if I am the admin, up to a maximum of 20 members
**And** (FR-SOC-01, FR-SOC-02, FR-SOC-03, FR-SOC-04, FR-SOC-05)

### Story 9.2: OOTD Post Creation

As a User,
I want to post a photo of my Outfit of the Day to my squads and tag the items I'm wearing,
So that my friends can see my look and know what pieces I used.

**Acceptance Criteria:**

**Given** I belong to at least one Style Squad
**When** I create an OOTD post
**Then** I can upload a photo (camera/gallery)
**And** I can write a short caption (max 150 chars)
**And** I can tag items from my Wardrobe that are visible in the photo
**And** I can select which specific squads (one or multiple) the post is shared to
**And** the post is saved to `ootd_posts`
**And** (FR-SOC-06)

### Story 9.3: Social Feed & Filtering

As a User,
I want to scroll through a feed of my friends' outfits,
So that I can see their daily styles.

**Acceptance Criteria:**

**Given** I belong to squads with active posts
**When** I open the Social tab
**Then** I see a chronological feed of OOTD posts from all my joined squads
**And** I can tap a dropdown to filter the feed to a specific squad only
**And** the feed loads quickly (< 2 seconds) using pagination
**And** (FR-SOC-07, FR-SOC-08, NFR-PERF-06)

### Story 9.4: Reactions & Comments

As a User,
I want to react to and comment on my friends' posts,
So that we can hype each other up and discuss our clothes.

**Acceptance Criteria:**

**Given** I am viewing an OOTD post in the feed
**When** I tap the Fire icon (🔥)
**Then** my reaction is toggled and securely saved to `ootd_reactions`
**And** when I type a comment (max 200 chars), it is saved to `ootd_comments`
**And** the post author receives a notification
**And** authors can delete any comment on their post, and users can delete their own
**And** (FR-SOC-09, FR-SOC-10, FR-SOC-11)

### Story 9.5: "Steal This Look" Matcher

As a User,
I want to tap a button on a friend's post to find similar items in my own wardrobe,
So that I can recreate their outfit without buying new clothes.

**Acceptance Criteria:**

**Given** I am viewing an OOTD post containing tagged items
**When** I tap "Steal This Look"
**Then** the system uses Gemini to map the friend's tagged items against my own wardrobe
**And** I see a list of my closest matching items, color-coded by match quality
**And** I can save the resulting combination as a new outfit in my own profile
**And** (FR-SOC-12, FR-SOC-13)

### Story 9.6: Social Notification Preferences

As a User,
I want to control how and when I receive notifications about my squads,
So that I am engaged but not annoyed.

**Acceptance Criteria:**

**Given** I am in Profile Settings -> Notifications
**When** I configure my social alerts
**Then** I can choose: All posts, Only morning posts, or Off
**And** quiet hours (10 PM - 7 AM) are respected by the backend FCM payload
**And** I receive a daily posting reminder (e.g., 9 AM) only if I haven't already posted today
**And** (FR-NTF-01, FR-NTF-02, FR-NTF-03, FR-NTF-04, FR-NTF-05)

## Epic 10: AI Wardrobe Extraction (Bulk Import)

Users can quickly digitize dozens of items from existing photos to overcome the cold-start problem of building a digital closet.

### Story 10.1: Bulk Photo Gallery Selection

As a User,
I want to select multiple photos at once from my camera roll,
So that I can batch process images containing my clothes.

**Acceptance Criteria:**

**Given** I am on the Wardrobe tab
**When** I tap "Bulk Import"
**Then** I can select up to 50 photos from my native device gallery
**And** the UI shows the selection count
**And** (FR-EXT-01)

### Story 10.2: Bulk Extraction Processing

As a User,
I want bulk photo uploads processed reliably in the background,
So that I can import many wardrobe items without the app hanging or timing out.

**Acceptance Criteria:**

**Given** the user has submitted a bulk upload
**When** the photos reach the Cloud Run backend
**Then** a background extraction job is tracked in `wardrobe_extraction_jobs`
**And** Gemini Vision detects up to 5 individual clothing items within each single photo
**And** Gemini categorizes and removes the background for each distinct item detected
**And** the entire 20-photo job completes in under 2 minutes
**And** (FR-EXT-02, FR-EXT-03, FR-EXT-04, FR-EXT-08, NFR-PERF-05)

### Story 10.3: Extraction Progress & Review Flow

As a User,
I want to see the progress of my bulk import and review the results before adding them,
So that I can delete mistakes or duplicates before they clutter my wardrobe.

**Acceptance Criteria:**

**Given** a bulk extraction job is running or completed
**When** I view the extraction status
**Then** I see progress updates and estimated time remaining
**And** once finished, I see a confirmation screen listing all extracted individual items
**And** I can quickly toggle Keep/Remove on each item
**And** the system warns me if an extracted item closely matches an item I already own (duplicate detection)
**And** kept items are saved with `creation_method = 'ai_extraction'` linking back to the source photo
**And** (FR-EXT-05, FR-EXT-06, FR-EXT-07, FR-EXT-09, FR-EXT-10)

## Epic 11: Advanced Analytics 2.0

Users receive deep insights into brand value, sustainability impact (CO2), wardrobe gaps, and seasonal readiness.

### Story 11.1: Brand Value Analytics

As a Premium User,
I want to see which clothing brands offer me the best cost-per-wear,
So that I know where to invest my shopping budget in the future.

**Acceptance Criteria:**

**Given** I have logged wear data for branded items
**When** I view the Advanced Analytics dashboard
**Then** I see a "Brand Value" section ranking brands by lowest average CPW
**And** the view displays total spent and total wears per brand
**And** only brands with 3+ items are included
**And** I can filter this brand ranking by garment category
**And** (FR-BRD-01, FR-BRD-02, FR-BRD-03)

### Story 11.2: Sustainability Scoring & CO2 Savings

As a User,
I want to see my environmental impact quantified based on my wearing habits,
So that I understand my contribution to sustainable fashion.

**Acceptance Criteria:**

**Given** the system has my wardrobe and wear data
**When** I view the Sustainability card
**Then** a sophisticated score (0-100) is calculated based on 5 weighted factors (utilization, CPW, resale, etc.)
**And** an estimated CO2 savings metric is displayed based on "re-wearing vs buying new" benchmarks
**And** the UI dynamically colors the score and shows a percentile comparison against other Vestiaire users
**And** (FR-SUS-01, FR-SUS-02, FR-SUS-03, FR-SUS-04)

### Story 11.3: Wardrobe Gap Analysis

As a User,
I want the app to identify what my wardrobe is missing,
So that I receive useful, personalized shopping guidance instead of generic suggestions.

**Acceptance Criteria:**

**Given** a user has a populated digital wardrobe
**When** the Gap Analysis runs
**Then** it identifies missing items based on category balances, formality spectrums, color ranges, and weather coverage
**And** it uses Gemini to generate specific item recommendations (e.g., "Consider a beige trench coat for rainy work days")
**And** gaps are rated Critical, Important, or Optional
**And** the user can dismiss specific gap recommendations
**And** (FR-GAP-01, FR-GAP-02, FR-GAP-03, FR-GAP-04, FR-GAP-05, FR-GAP-06)

### Story 11.4: Seasonal Reports & Heatmaps

As a User,
I want detailed reports on how my wearing habits change with the seasons and across the year,
So that I can better prepare for seasonal transitions.

**Acceptance Criteria:**

**Given** I have long-term wear data
**When** a new season approaches (or I view the heatmap)
**Then** a Seasonal Report generates showing most worn items, neglected items, and historical comparison for that season
**And** an alert notifies me 2 weeks before a seasonal transition
**And** I can view a calendar heatmap (Month/Quarter/Year) showing my logging activity intensity, with daily drill-down
**And** (FR-SEA-01, FR-SEA-02, FR-SEA-03, FR-SEA-04, FR-HMP-01, FR-HMP-02, FR-HMP-03, FR-HMP-04)

## Epic 12: Calendar Integration & Outfit Planning

Users can schedule outfits for specific future events and receive automated packing lists for multi-day trips.

### Story 12.1: Event Display & Suggestions

As a User,
I want to see my upcoming calendar events directly on the Home screen and receive tailored event suggestions,
So that I know what to wear for the specific occasion, not just the weather.

**Acceptance Criteria:**

**Given** I have a synced calendar with upcoming events
**When** I view the Home screen
**Then** my upcoming events for the day are displayed with their classified type and formality
**And** the AI daily outfit suggestion factors in these event requirements (e.g., suggesting a blazer for a "Formal" meeting)
**And** I can tap an event to see alternate "Event Specific" outfit suggestions
**And** (FR-EVT-01, FR-EVT-02)

### Story 12.2: Outfit Scheduling (Plan Week)

As a Planner User,
I want to schedule my outfits for the upcoming week in a calendar view,
So that my mornings are completely stress-free.

**Acceptance Criteria:**

**Given** I am on the Outfits or Calendar tab
**When** I tap "Plan Week"
**Then** I see a 7-day calendar view displaying the weather preview and events for each day
**And** I can assign a saved outfit or generate a new one for any future day
**And** scheduled outfits are stored in `calendar_outfits` linked to the specific date/event
**And** I can edit or remove a scheduled outfit at any time
**And** (FR-EVT-03, FR-EVT-04, FR-EVT-05, FR-EVT-06)

### Story 12.3: Formal Event Reminders

As a User,
I want to receive an evening reminder before a high-formality event,
So that I have time to prep (iron, dry clean) my outfit the night before.

**Acceptance Criteria:**

**Given** I have a calendar event classified as highly formal tomorrow morning
**When** the time reaches 8:00 PM (or custom evening time)
**Then** the system sends a push notification reminding me about the event and my selected outfit
**And** the notification includes AI-generated prep tips (e.g., "Don't forget to iron your linen shirt")
**And** I can configure or disable these reminders in Settings
**And** (FR-EVT-07, FR-EVT-08, FR-PSH-05)

### Story 12.4: Travel Mode: Multi-Day Trip Packing

As a Traveler,
I want the app to detect my upcoming trips and generate a smart packing list,
So that I only pack what I need and avoid overpacking.

**Acceptance Criteria:**

**Given** my calendar sync detects a multi-day event in a different location
**When** the trip approaches (e.g., 3 days out)
**Then** a "Travel Mode" banner appears on the Home screen
**And** the system generates a packing list based on trip duration, destination weather, and planned events
**And** I can view the list as a checklist to mark items as packed
**And** I can export the list to my device's Notes or Reminders app
**And** (FR-TRV-01, FR-TRV-02, FR-TRV-03, FR-TRV-04, FR-TRV-05)

## Epic 13: Circular Resale Triggers

Users receive proactive nudges to sell or donate neglected items to improve their overall wardrobe health score.

### Story 13.1: Wardrobe Health Score

As a User,
I want a unified "Health Score" for my wardrobe to understand how efficiently I'm using what I own,
So that I am motivated to declutter or wear more of my clothes.

**Acceptance Criteria:**

**Given** the system has calculated my wear logs and wardrobe size
**When** I view the Wardrobe or Analytics tab
**Then** I see my Wardrobe Health Score (0-100)
**And** it heavily weights % of items worn in 90 days vs total size and CPW
**And** the UI colors it Green/Yellow/Red
**And** it includes a specific recommendation to improve (e.g., "Declutter 8 items to reach Green status")
**And** (FR-HLT-01, FR-HLT-02, FR-HLT-03, FR-HLT-04)

### Story 13.2: Monthly Resale Prompts

As a User,
I want the app to gently nudge me to sell items I haven't worn in a long time,
So that I don't hoard unworn clothes.

**Acceptance Criteria:**

**Given** I have items with `neglect_status` active (not worn in 180+ days)
**When** the monthly background job evaluates my wardrobe
**Then** I receive an in-app prompt highlighting 1-3 neglected items
**And** the prompt estimates a potential Vinted/Depop sale price for each
**And** I can dismiss the prompt per-item ("I'll keep it") or globally via settings
**And** accepting the prompt takes me to the Resale Listing Generator
**And** (FR-RSL-01, FR-RSL-05, FR-RSL-06)

### Story 13.3: Spring Clean Declutter Flow & Donations

As a User,
I want a guided process to review all my unworn clothes and decide what to keep, sell, or donate,
So that doing a wardrobe clean-out is structured and easy.

**Acceptance Criteria:**

**Given** I initiate the "Spring Clean" mode
**When** the UI presents my neglected items one by one
**Then** I can swipe/tap to choose: Keep, Sell, or Donate
**And** items marked Donate are logged to `donation_log` with estimated value, date, and charity details
**And** items marked Sell are moved to my Resale queue
**And** I earn the "Generous Giver" badge upon hitting 20 cumulative donated items
**And** I can view my donation history on my profile
**And** (FR-HLT-05, FR-DON-01, FR-DON-02, FR-DON-03, FR-DON-05)
