# Cloud Recognition Architecture

How Cloudoodle identifies what a cloud "looks like" without spending the rent
on vision-model API calls.

## The problem

For every cloud someone scans, we want to answer "what does this kinda look
like?" plus "where would I add minimum marks to help a human see it?" — and
we want **5 alternative answers per cloud** so different viewers get
different interpretations.

The naive shape of this is "vision model API call per scan." At
$0.003/call × 1M MAU × 10 scans/session × 4 sessions/month ≈ **$120K/month**.
That's a forever-tax we don't want.

## Three-tier recognition

The cost model that actually works is the same one Apple Photos uses for
search: most queries are answered on-device for free, some by a server cache
for nearly free, a small fraction by an expensive backend.

```
┌─────────────────────────────────────────────────────────┐
│ TIER 1: ON-DEVICE EMBEDDING MATCH       cost: $0/call   │
│ Pre-embed the allowlist labels once. On scan, compute a │
│ shape embedding locally, cosine-match against the       │
│ embeddings. Confidence ≥ 0.6 → use this answer.         │
│ Coverage at maturity: ~70-80% of scans                  │
└────────────────────┬────────────────────────────────────┘
                     │ low confidence → escalate
                     ▼
┌─────────────────────────────────────────────────────────┐
│ TIER 2: SERVER-SIDE SIGNATURE CACHE     cost: $0/call   │
│ Locality-sensitive hash of Hu moments → cache key.      │
│ Similar shapes collapse to the same key. 5 stored       │
│ interpretations per key; rotate one per request.        │
│ Coverage at maturity: ~15-25% of scans (cache hits)     │
└────────────────────┬────────────────────────────────────┘
                     │ cache miss
                     ▼
┌─────────────────────────────────────────────────────────┐
│ TIER 3: VISION MODEL                    cost: $0.003    │
│ Send the shape to a vision LM, ask for 5 interpretations│
│ with annotations, validated against allowlist, cached.  │
│ Coverage at maturity: ~5% of scans (genuinely novel)    │
└─────────────────────────────────────────────────────────┘
```

### Cost projections by tier mix

Assumes 1M MAU, 4 sessions/month, 10 scans/session = 40M scans/month.

| Phase | Tier mix | Monthly cost |
|---|---|---|
| Phase 1 (no on-device) | 0% / 80% cache / 20% vision | ~$24K |
| Phase 2 (better caching) | 0% / 90% / 10% | ~$12K |
| Phase 3 (with on-device) | 75% / 22% / 3% | ~$3.6K |

At each phase, the same `CloudRecognitionService` protocol is what the iOS
code calls. The tiering is invisible to callers.

## The 5-interpretations-per-shape trick

When Tier 3 fires, we don't ask "what does this look like?" — we ask:

> Give me five distinct kid-friendly interpretations of what this cloud
> shape resembles, ordered by how strongly the shape suggests each one.
> For each, return the label and where you'd add minimum marks to help
> a human see it.

That single call yields 5 interpretations for the cost of ~1.2 normal calls.
We cache all 5. The next 100 viewers of that same shape rotate through the
5 — each gets a randomly-assigned one of the cached interpretations,
preserving the "5 kids see 5 different things" magic *without* 5× the
API spend.

## Shape signature math

The cache is keyed by a **locality-sensitive shape signature**, not by exact
contour. The idea is that two scans of the same cloud taken 30 seconds apart
from slightly different angles should resolve to the same cache entry.

Hu moments give us 7 numbers that describe a contour invariantly under
translation, rotation, scale, and reflection. We don't use them as a real
vector — we **bucket each one** into discrete bins (log-magnitude binning
because Hu moments span many orders of magnitude). The bucket IDs
concatenated become the cache key:

```
huMoments = [μ₁, μ₂, μ₃, μ₄, μ₅, μ₆, μ₇]
key       = "3:1:7:2:0:5:4"
```

Cache key collisions = approximate shape matches. The bucket count tunes
the trade-off:
- **Few buckets** → high collision rate → cheaper (more cache hits) but
  shapes can collapse together that shouldn't.
- **Many buckets** → fewer collisions → more accurate but lower hit rate.

Start at 8 bins per moment. Tune empirically once we have telemetry on the
hit rate.

## What the iOS pipeline looks like

```
CloudDetector → CloudShape       (single cloud)
CloudClustering → CloudCluster   (1+ shapes grouped if spatially adjacent)
CloudShapeSignature → signature  (Hu moments + bucketed key)
CloudRecognitionService.recognize(cluster) → [Interpretation]
    Tier 1: tries local embedding match first (Phase 3)
    Tier 2: GETs /api/recognize?signature=...
            backend: cache hit?
              yes → return cached
              no  → Tier 3
    Tier 3: backend calls vision model, caches, returns
Pick one interpretation at random.
Animate cloud outline + annotation marks.
```

## Failure modes and their handling

| Failure | Behavior |
|---|---|
| Vision model returns nothing in allowlist | Cache a "no-match" sentinel for that signature (cheap to remember); show the existing "Cool cloud!" fallback. Don't waste another API call on the same shape. |
| Vision model returns content that fails allowlist | Drop the offending interpretations; cache only the safe ones. If 0 safe → no-match sentinel. |
| Cache miss + network fails | Retry once with jitter; on second failure, fall back to a curated set of "common shape" interpretations chosen by simple heuristic (round → "ball", elongated → "snake") so the user never sees a broken state. |
| Rate limit hit | Per-region API call counter in Redis with a daily budget. If we exceed budget for a region, switch that region to the curated fallback for the rest of the day. |
| User scans the same cloud 5×  in a row | Server returns the same 5 cached interpretations; client randomly picks one each time — natural variety, no extra API cost. |

## Privacy implications

The shape signature contains 7 numbers describing the cloud's silhouette
geometry. It contains no PII, no location, no image. The optional outline
sent for novel shapes is a list of 2D normalized points — also non-PII.
The privacy nutrition label answers in `docs/PRIVACY.md` don't change for
this feature; just note in the document that scan reports now include a
shape signature.

## What's wired up where

```
iOS:
  Models/CloudCluster.swift              the cluster + signature types
  Models/Interpretation.swift            interpretation + annotation types
  Services/CloudShapeSignature.swift     Hu moments math
  Services/CloudRecognitionService.swift protocol + tier orchestrator
  Services/CloudClusteringService.swift  group spatially-adjacent shapes
  Services/BackendConfig.swift           +recognizeURL

Backend:
  api/recognize.ts                       POST endpoint, signature → 5 interps
  api/lib/recognition.ts                 cache helpers + types
  api/lib/allowlist.ts                   kid-safe label allowlist
  test/recognition.test.ts               coverage for cache + allowlist
```
