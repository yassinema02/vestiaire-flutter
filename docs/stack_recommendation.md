# 📊 Vestiaire 2.0 — Tech Stack Recommendation
**Analyst:** Mary | **Date:** 2026-03-09 | **For:** Yassine (Solopreneur)

**Priorities applied:** Performance → Scalability → Cost → Native iOS Feel → Flexibility → DX

---

## 📱 Frontend: **Flutter**

### Why Not the Other Options?

| Option | Verdict | Key Reason |
|--------|---------|------------|
| **SwiftUI (Native)** | ❌ Not recommended for solo | iOS-only; Android requires a full second codebase |
| **React Native (bare, New Architecture)** | ⚠️ Possible but a half-measure | Fabric + JSI removes the bridge but you're still fighting JS GC pauses |
| **React Native + Expo** | ❌ Core problems remain | Expo-managed, App Store policy risk, JS runtime overhead |
| **Flutter** | ✅ **Recommended** | See below |

### Why Flutter Wins for Your Constraints

```
Performance priority #1 → Flutter compiles to ARM machine code (AOT).
                           No JS runtime. No bridge. No GC pauses.
                           Consistently 60/120fps on iOS with Impeller renderer.

Scalability #2 → Single Dart codebase = iOS + Android simultaneously.
                  No split team needed. One release pipeline.

Cost #3 → One codebase, one build, one maintenance burden.
           RevenueCat has first-class Flutter SDK. Same AI pipeline.

Native iOS feel #4 → Cupertino widget library mirrors native iOS components.
                      Custom painters can match exactly what UIKit provides.

Solo dev #5 → Flutter's hot reload + excellent tooling = fastest iteration
               for a single developer. Dart is easy to pick up in 2-4 weeks.
```

> [!IMPORTANT]
> Flutter pairs **natively** with the Google ecosystem (GCP, Firebase, Vertex AI/Gemini).
> Google maintains first-party Dart/Flutter SDKs for all GCP services.
> This is not a coincidence — it's a strategic advantage for your stack.

---

## 🏗️ Backend: **GCP Hybrid Stack**

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (iOS / Android)                │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS
          ┌─────────────▼──────────────┐
          │    Firebase Auth            │  Authentication layer
          │    (Apple, Google, Email)   │  Native Keychain on iOS
          └─────────────┬──────────────┘
                        │ JWT
          ┌─────────────▼──────────────┐
          │    Cloud Run (API Server)   │  Stateless API layer
          │    Node.js / FastAPI        │  Persistent container, no cold starts
          │    (multi-tenant, RLS via   │  Auto-scales 0→N
          │     middleware)             │
          └──────┬──────────┬──────────┘
                 │          │
    ┌────────────▼──┐  ┌────▼──────────────┐
    │  Cloud SQL    │  │  Cloud Storage     │  CDN-backed image storage
    │  PostgreSQL   │  │  (wardrobe images) │  Signed URLs
    └───────────────┘  └────────────────────┘
          │
    ┌─────▼──────────────┐
    │  Vertex AI / Gemini │  Unified AI pipeline
    │  (Flash 2.0)        │  Vision, outfits, background removal
    └─────────────────────┘
          │
    ┌─────▼──────────────┐
    │  Firebase Cloud     │  Push notifications
    │  Messaging (FCM)    │  Native APNs delivery on iOS
    └─────────────────────┘
```

### Service Breakdown

| Layer | Technology | Why This Choice |
|-------|-----------|-----------------|
| **Auth** | Firebase Auth | Battle-tested, Apple Sign-In native, 10M MAU free tier |
| **API Server** | Cloud Run (Node.js or FastAPI) | Persistent warm containers, no cold starts, full control |
| **Database** | Cloud SQL for PostgreSQL 16 | Direct connection pooling via Cloud SQL Proxy, standard SQL |
| **Storage** | Cloud Storage | Multi-regional CDN, signed URLs, cheaper at scale |
| **AI** | Vertex AI → Gemini 2.0 Flash | Vision analysis, outfit generation, **and background removal** — single pipeline |
| **Push** | Firebase Cloud Messaging | Native APNs/FCM, reliable delivery, free |

### Cloud Run API Design (Multi-Tenant)

```
Multi-tenancy strategy: Header-based (X-User-ID validated from Firebase JWT)
Auth middleware → validates Firebase token → injects user_id into every query
All DB queries scoped WHERE user_id = $authenticated_uid
Rate limiting via Cloud Armor or middleware (free/premium tiers)
```

---

## 🤖 AI Pipeline: **Unified Gemini Approach**

> [!TIP]
> All AI features flow through a single provider — Gemini 2.0 Flash via Vertex AI.
> This eliminates external API dependencies (no remove.bg), simplifies error handling,
> and reduces costs significantly.

### AI Features — All via Gemini

| Feature | How Gemini Handles It |
|---------|-----------------------|
| **Background Removal** | Image editing prompt: "Remove background, return clothing on transparent/white" — replaces remove.bg API |
| **Clothing Analysis** | Vision analysis: extracts category, color, pattern, material, style, season, occasions |
| **Outfit Generation** | Text + context prompt: wardrobe items + weather + calendar → outfit suggestions |
| **Event Classification** | Calendar event text → classify type (Work, Social, Formal, Casual) + formality score |
| **Gap Analysis** | Wardrobe analysis prompt: identify missing categories, colors, versatility gaps |
| **Shopping Analysis** | Product image/URL → compatibility scoring against existing wardrobe |
| **Resale Listing** | Generate Vinted/Depop-optimized listing text from item metadata |

### Cost Advantage

| Approach | Cost per 1K images |
|----------|-------------------|
| remove.bg API | **$90–$230** |
| Gemini 2.0 Flash (image edit) | **~$0.50–$2.00** |

That's a **~99% cost reduction** on background removal alone.

---

## 🔍 Why Not Convex?

Convex was evaluated as an alternative database/backend layer. Here's the analysis:

| Aspect | Convex | Cloud SQL (PostgreSQL) |
|--------|--------|----------------------|
| **Data model** | Document-based | Relational (SQL) |
| **Real-time** | ✅ Built-in, excellent | Requires additional setup |
| **Flutter/Dart SDK** | ⚠️ No official SDK (JS/TS-first) | ✅ Excellent via `postgres` or `drift` |
| **Vendor lock-in** | ⚠️ High — proprietary query language | Low — standard PostgreSQL, portable |
| **Data portability** | Difficult to export, no SQL | Full SQL export, migrate anywhere |
| **Maturity** | Newer, growing fast | Battle-tested, massive ecosystem |

**Verdict: ❌ Not recommended for Vestiaire** — No first-class Flutter SDK, high vendor lock-in, and the data model is inherently relational (wardrobes → items → outfits → outfit_items → calendar_entries). PostgreSQL is the natural fit.

---

## 💰 Cost Projections (Greenfield)

| Scale | Estimated Monthly Cost | Breakdown |
|-------|----------------------|-----------|
| **1K MAU** | ~£20–35/mo | Cloud SQL micro (~£6) + Cloud Run (~£5–15) + Storage (~£2) + Firebase (free) |
| **10K MAU** | ~£80–150/mo | Cloud SQL small (~£25) + Cloud Run (~£40–80) + Storage (~£10) + Vertex AI (~£15) |
| **100K MAU** | ~£400–800/mo | Cloud SQL medium (~£100) + Cloud Run (~£200–400) + Storage (~£50) + Vertex AI (~£100) |

> [!TIP]
> Cloud Run charges only for actual request time — idle = £0.
> Firebase Auth is free up to 10K MAU/month.
> Cloud SQL `db-f1-micro` handles 1K MAU comfortably at ~£6/mo.

---

## 🧰 Final Stack Summary

| Layer | Technology | Rationale |
|-------|-----------|-----------| 
| **Mobile** | Flutter (Dart) | AOT compiled, 60/120fps, iOS + Android, GCP-native |
| **Auth** | Firebase Auth | Apple/Google/Email, free to 10K MAU, Flutter SDK |
| **API Server** | Cloud Run (Node.js 22 or Python/FastAPI) | No cold starts on min-instances=1, scales to 0 at rest |
| **Database** | Cloud SQL for PostgreSQL 16 | Direct connection, standard SQL, automated backups |
| **Storage** | Cloud Storage | CDN-backed, signed URLs, GDPR EU residency |
| **AI (All Features)** | Vertex AI → Gemini 2.0 Flash | Clothing analysis, outfit gen, background removal, gap analysis — unified pipeline |
| **Push Notifications** | Firebase Cloud Messaging | APNs on iOS, FCM on Android, free |
| **Billing** | RevenueCat (Flutter SDK) | First-class Flutter support |
| **Error Monitoring** | Sentry (Flutter SDK) | First-class Flutter support |
| **Weather** | Open-Meteo | Free, no API key needed |
| **CI/CD** | GitHub Actions + Cloud Build | Automated Flutter builds + GCP deployments |

---

## ⚠️ Key Risks

> [!WARNING]
> **Dart/Flutter learning curve:** If you're coming from JS/React Native, expect 2-4 weeks
> to feel productive. The widget model is different but very logical once it clicks.

> [!CAUTION]
> **Build timeline:** 77 stories across 13 epics is substantial. Prioritize an MVP scope
> (Epics 1-4: Auth, Wardrobe, Weather, Outfit Generation) for initial launch, then layer
> on social, analytics, and advanced features post-launch.

> [!NOTE]
> **Firebase Auth profiles:** Firebase Auth doesn't give you a `profiles` table
> automatically. Your Cloud Run API handles this — on first login, create a profile
> row in Cloud SQL. This is straightforward but must be explicitly implemented.
