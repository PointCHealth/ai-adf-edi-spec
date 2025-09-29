# Healthcare EDI Platform – Azure Budget Plan

## 1. Purpose & Scope
This document provides an initial 12–18 month Azure cost planning baseline for the Healthcare EDI ingestion, routing, and outbound acknowledgment platform described in the architecture and routing specifications. It translates projected transaction and subscriber volumes into capacity, SKU selections, cost drivers, scaling triggers, and optimization levers. It is intended for FinOps, architecture, and leadership stakeholders to validate budget envelopes, tagging strategy, and growth inflection points.

## 2. Business & Volume Inputs (Provided)
| Item | Current / Year 0 | Projection (Jan 1) | Notes |
|------|------------------|--------------------|-------|
| Active EDI Processes | 5–10 | 10–12 | 834, 837/835, plus baseline control/ack (TA1/999) and outbound assembly |
| Weekly Transactions (all inbound files) | ~5,000 | Scale with new partners (est. +15–20% YoY) | ≈260,000 / year |
| Annual Claims (837) | ~250,000 | Could rise with additional payer/provider feeds | Drives storage + routing + ack volume |
| Subscribers / Members | 7,200 | 10,000 | Used for estimating growth of enrollment (834) updates |
| X12 Sets Phase 1 | 834, 837, 835, (TA1, 999, 277CA partial) | Add 271, 277 status, 278 later | Outbound responses increase volume multipliers |
| Average File Size (assumed) | 1–5 MB typical (peaks 50–100 MB) | Similar | Larger 837/835 batch peaks |

## 3. Assumptions & Methodology
Cost model provides Low (optimized), Expected (baseline), and High (peak / contingency) scenarios using published PAYG unit prices (captured 2025-09-29). Where enterprise agreement or savings plan discounts apply, substitute contracted rates during quarterly refresh.

### 3.1 General Assumptions
* Regions: Single primary region (Prod) + lower-cost paired region for DR data copies (selective) – assume no active-active in Phase 1.
* Environments: Dev, Test, Prod (3); optional Sandbox (excluded from baseline unless noted). Multipliers: Dev ~25% of Prod consumption; Test ~40% (load/replay).
* Storage retention: 7 years raw immutable (tiering policy after 90 days Hot → Cool; after 1 year Cool → Archive for low-access claim/enrollment payloads where policy permits). Only Year 1 accumulation cost budgeted; future years amortized via lifecycle tiering.
* PaaS & Serverless preference. No dedicated VM costs assumed.
* Identity / Networking baseline (Entra ID, DNS, Private Endpoints) assumed shared corporate overhead—NOT directly attributed here except for Private Endpoint transaction counts (negligible cost compared to core drivers).
* Purview governed assets limited to raw + outbound containers initially.
* Monitoring: Central Log Analytics workspace shared per environment; ingestion constrained by sampling & custom table design.
* All resources tagged: `env`, `costCenter`, `owner`, `dataSensitivity`, `workload=edi`.

### 3.2 Volume → Cost Driver Mapping (Illustrative)
| Volume Driver | Affects | Notes |
|---------------|---------|-------|
| File Count (~5k/week) | ADF pipeline/activity runs; Function executions; Service Bus messages | Each inbound file = 1 ingestion pipeline + 1 router function + N routing messages (per ST) |
| ST Transaction Density (avg 5 ST per 837 batch file assumption) | Service Bus messages, outbound ack fan-out | 837 batches multiply routing events beyond file count |
| Claims (~250k) | Storage (raw + metadata), routing messages, 277CA generation | Each accepted claim yields later a 277CA + potential 835 linkage |
| Subscribers growth | 834 delta file size, potential enrollment frequency | Minor impact vs. claims volume |
| Outbound Acks (TA1/999/277CA/835) | Function / Orchestrator executions, Storage outbound | Response counts roughly 1–1.3x inbound files (some multi-response lifecycle) |

## 4. Azure Resource Inventory & Sizing Rationale

### 4.1 Core Data & Ingestion
| Resource | Purpose | Proposed SKU / Tier | Sizing Notes | Cost Sensitivity |
|----------|---------|--------------------|-------------|-----------------|
| Storage Account (Landing + SFTP) | Partner SFTP ingress, short-term holding | Standard General Purpose v2, Hot | 5k files/week * avg 3 MB ≈ 15 GB/week ≈ 780 GB/year raw landing before lifecycle; keep 30 days → ~120 GB hot | Medium (capacity + transactions) |
| Data Lake Storage (Raw / Curated) | Immutable retention + zone layout | Standard GPv2 (separate account) | Year 1 retained raw: assume 260k files * avg 3 MB = 780 GB + overhead + growth buffer 30% → ~1.0 TB (pre-compression) | Medium |
| Immutable Policy / Legal Hold | Compliance (optional) | Blob versioning + immutability | Adds overhead (version metadata). Budget +5% capacity | Low |
| Lifecycle Policies | Tier cost optimization | Rules only | Moves 90+ day objects to Cool (~60% cheaper), 1 yr to Archive | Negative (saves cost) |

### 4.2 Orchestration & Processing
| Resource | Purpose | SKU / Plan | Volumetric Basis (Monthly) | Est. Qty / Month (Prod) | Notes |
|----------|---------|-----------|----------------------------|------------------------|-------|
| Azure Data Factory | Ingestion pipelines | Consumption (Activity runs + Data movement) | ~5k files/week → ~21.7k activity runs + ancillary lookups (×1.3) | ~28k runs | Add 10% for reprocess / failures |
| Azure Functions – Router | Envelope peek + routing messages | Consumption (Y1 Plan) | ~21.7k invocations/month | ~22k | Header slice only (low GB-s) |
| Azure Functions – Outbound Orchestrator | Ack assembly timer batches | Consumption | Batching every 5 min active window (16 hrs/day) ≈ 192 batches/day + on-demand triggers | ~6k executions | Consider Durable overhead if used |
| Azure Functions – Validation / AV (future) | Structural / AV scan | Disabled until needed | n/a | Placeholder cost line |

### 4.3 Messaging & Eventing
| Resource | Purpose | SKU | Sizing Notes | Monthly Message Estimate |
|----------|---------|-----|-------------|--------------------------|
| Event Grid | Blob Created triggers | Consumption | 5k events/week | ~21.7k |
| Service Bus Namespace | Routing & outbound topics | Standard (partitioned) | 1 topic (`edi-routing`) + 1 optional (`edi-outbound-ready`), 4–6 subscriptions | See below |
| Service Bus Messages | Routing fan-out | Standard unit (brokered message ops) | Per file: avg 3 ST sets? (range 1–10). Assume 3.5 × 21.7k ≈ 76k publish + equal deliveries (× #subscriptions filtering) | ~300k–400k ops including management |

### 4.4 Governance, Security, Observability
| Resource | Purpose | SKU | Volume Basis | Notes |
|----------|---------|-----|-------------|-------|
| Key Vault | Secrets (SFTP creds, counters) | Standard | 50–100 secret ops/day | Control number counter reads from Table Storage preferred to reduce ops |
| Azure Table Storage (in Data Lake acct or separate) | Control numbers, metadata status | Standard (Transactions) | ~Ack batches + pipeline writes (≤10k tx/mo) | Low cost |
| Microsoft Purview | Data catalog + lineage | Standard (1 Capacity Unit) | Limited assets (<500) | Reassess when adding semantic parsing |
| Log Analytics Workspace | Central logs, custom tables | Pay-as-you-go (ingest GB) | Router + ADF + Function + SB diag estimated 1.0–1.5 GB/day Prod | 30–45 GB/mo ingestion |
| Application Insights (per Function) | Function telemetry (Classic or Workspace-based) | Workspace-based | Included in Log ingestion estimate | Consolidated |
| Azure Monitor Alerts / Action Groups | SLA & error alerts | Consumption | Few hundred signals/mo | Minor |

### 4.5 Optional / Future Phase Placeholders (Not Costed in Expected Baseline)
| Resource | Trigger | Rationale |
|----------|---------|-----------|
| Azure Synapse / Fabric | Phase 2 semantic transformations | Not required Phase 1 ingestion routing only |
| Azure Container Apps (Parsing) | Advanced validation / decompression at scale | Only if Function cold starts / memory become bottleneck |
| Azure API Management | Partner API channel (non-SFTP) | Phase 2 expansion |
| Azure Data Explorer / Dedicated Kusto | High-frequency analytics dashboards | Existing Log Analytics sufficient initially |

## 5. Cost Envelope (Live Unit Pricing Basis)
Figures reflect published PAYG unit prices (captured on 2025-09-29) for an assumed US region (e.g., East US). Substitute negotiated/EA or Savings Plan rates as they become available.

### 5.0 Current Unit Pricing (Key Extracts)
| Service / Meter | Unit Price (USD) | Source Notes |
|-----------------|------------------|--------------|
| Blob Storage Hot (LRS) | $0.018 per GB-month | From pricing table (rounded) |
| Blob Storage Cool (LRS) | $0.010 per GB-month | |
| Blob Storage Cold (LRS) | $0.0036 per GB-month | |
| Blob Storage Archive (LRS) | $0.002 per GB-month | Planning (rarely Year 1) |
| Data Factory Orchestration | $1 per 1,000 activity runs | $0.001 per activity run |
| Data Factory Data Movement | $0.25 / DIU-hour | Pro‑rated per minute |
| Functions Consumption Exec | 1M free + $0.20 per additional 1M | Expect below free grant |
| Functions Consumption GB-s | 400k GB-s free + $0.000016/GB-s | Low memory fast execs |
| Event Grid Basic Ops | First 100k free + $0.60 per 1M ops | < free tier initially |
| Service Bus Standard Base | $0.0135 per hour (~$9.86/mo) | Includes 13M ops/mo |
| Service Bus Std Ops (excess) | $0.80 per 1M (13–100M) | Not reached in baseline |
| Key Vault Secret Ops | $0.03 per 10K operations | Very low volume |
| Log Analytics (Analytics Logs) | $2.30 per GB ingested | 31 days retention included |
| Retention (beyond included) | $0.10 per GB-month | Not used (baseline 31 days) |
| Purview (Data Gov – 1 CU placeholder) | ~ $190 per month | Legacy Data Map CU analog (estimate) |

### 5.1 Updated Monthly Cost Table (Prod)
Low = optimized & deferred features, Expected = baseline volumes described, High = stress / early Phase 2 ramp.

| Category | Low | Expected | High | Basis / Formula |
|----------|-----|----------|------|-----------------|
| Storage (Landing + Raw + Outbound) | $18 | $25 | $45 | Hot 250 GB *0.018 + Cool 500 GB *0.01 + misc; High adds slower tiering + 50% growth |
| Data Factory | $150 | $215 | $400 | Orchestration: 30K runs *0.001 ≈ $30; Data movement: Low 15K copies *$0.006 ≈ $90; Expected 22K copies (2 DIU *1 min) ≈ $183; High adds heavier DIU/time & reprocess |
| Functions (All) | $0 | $3 | $15 | Under free grant (router + orchestrator); High assumes >1M execs & GB-s overage |
| Event Grid | $0 | $0 | $1 | ~22K ops < 100K free; High scenario ~2M ops (1.9M billable ≈ $1.14) |
| Service Bus (Std) | $10 | $10 | $40 | Base ~$9.86; High adds excess ops (e.g., 20M → ~7M billable ≈ $5.6) + headroom |
| Key Vault | $0.50 | $1 | $3 | (Ops/10K)*$0.03 rounded + occasional cert ops |
| Purview Data Governance | $0 | $190 | $380 | Low = deferred adoption; Expected 1 CU; High 2 CUs / increased scans |
| Log Analytics (+App Insights) | $69 | $85 | $138 | Ingestion GB * $2.30 (30 / 37 / 60 GB) |
| Monitoring & Alerts | $3 | $5 | $10 | Alert rule queries & notifications |
| Total (Prod Monthly) | ~$251 | ~$534 | ~$1,032 | Summation (rounded) |

### 5.2 Environment Roll-Up (Monthly)
Simple proportional scaling (optimize further by sharing Purview & SB where policy permits). Service Bus base is proportionally allocated for simplicity.

| Environment | Low | Expected | High | Notes |
|-------------|-----|----------|------|-------|
| Dev (~25%) | $63 | $135 | $260 | Lower activity, minimal Purview scans |
| Test (~40%) | $100 | $214 | $410 | Includes load / replay tests |
| Prod | $251 | $534 | $1,032 | From 5.1 |
| Total / Month | ~$414 | ~$883 | ~$1,702 | |

Annual (Expected) ≈ $10.6K. Add 20% contingency (pricing drift, scope creep) → **Budget Ask: $12.7K Year 1**.

### 5.3 Observed Efficiency Factors
Lower steady-state run rate is driven by: (a) activity-run centric ADF usage vs. heavy data flows, (b) Service Bus operations well below included 13M, (c) Functions under free grants, (d) optimized log volume < 1.5 GB/day.

### 5.4 Sensitivity Levers
| Driver | Elasticity | Comment |
|--------|-----------|---------|
| ST transactions per file (× factor) | High (ADF + SB + Functions) | Each extra ST adds routing message + potential downstream log events |
| Log verbosity (% increase) | Linear in $ | Keep below 2 GB/day to maintain < $140/mo |
| Purview adoption breadth | Step | Enabling auto-scans across many sources can double cost (add 1 CU) |
| Reprocessing rate (%) | Moderate | 5%→10% increases ADF & Functions proportionally |
| Lifecycle policy delay (days) | Low→Moderate | Extends Hot storage segment; small absolute $ due to modest GB |

### 5.5 Rapid Recalculation Formulae (Pseudo)
```
ADF_Orchestration = ActivityRuns * 0.001 USD
ADF_DataMove = CopyCount * ( (DIU * Minutes)/60 * 0.25 )
LogCost = IngestGB * 2.30
SB_Cost = 9.86 + max(0, (Ops - 13_000_000)/1_000_000 * 0.80)
Functions_Exec = max(0, (Execs - 1_000_000)/1_000_000 * 0.20)
Functions_GBs = max(0, (GBs - 400_000) * 0.000016)
StorageHot = HotGB * 0.018 ; StorageCool = CoolGB * 0.01 ; StorageCold = ColdGB * 0.0036
```

### 5.6 Refresh Procedure
1. Export current 30-day telemetry (activity runs, exec count, SB ops, log GB, storage tier distribution).
2. Apply formulas above; compare variance >10% to prior month.
3. If Purview scanning introduced, insert CU or per-scan consumption line.
4. Update this section with new unit prices quarterly (pricing pages capture date).
5. Reevaluate reserved capacity if any single category > 25% of total recurring run rate.

### 5.7 Caveats
* Purview pricing currently evolving; placeholder uses legacy Data Map CU analog—confirm licensing/consumption alignment before committing.
* Region differentials & currency conversion not applied.
* Does not include network egress (expected negligible—SFTP partner downloads minimal size). Add if >5% of storage throughput.
* Archive retrieval & rehydration costs excluded (Phase 2 retention operations).
* Key Vault certificate renewal spikes (e.g., mass rotation) not modeled (add ad‑hoc line if scheduled).
* Any shift to Premium Service Bus or Functions Premium invalidates related cost lines—recalculate with plan rates.

> NOTE: This section is system of record for cost projections (as of 2025-09-29). Prior draft estimates have been deprecated.

## 6. Scaling Triggers & Thresholds
| Trigger Metric | Threshold | Action | Impact |
|----------------|-----------|--------|--------|
| Routing messages > 1M / month | Sustained 2 months | Evaluate Premium Service Bus (throughput, predictable latency) | +$300–$500/mo |
| Log ingestion > 2 GB/day | Trend 30-day ↑ | Increase sampling / reduce verbosity, archive raw diag to storage | Savings 10–30% logs |
| ADF activity concurrency waits > 5% | Weekly average | Split pipelines or add parallelization / Data Flows review | Maintain SLA |
| Function cold start p95 > 2s | >5% of invocations | Enable pre-warming / move critical path to Elastic Premium | +$100–$200/mo |
| Raw storage > 2 TB Year 1 | Growth curve | Accelerate lifecycle to Cool sooner (30 days) | Save 20–30% storage |
| Purview assets > 5k | Catalog expansion | Add 1 more Capacity Unit or evaluate scanning schedule optimization | +$190/mo |

## 7. Optimization & Governance Levers
1. Early lifecycle tiering (30/90 day policies) for large 837/835 files.
2. Minimize routing message payload (already envelope-only) to keep Service Bus payload < 4 KB (lower ingress/egress cost impact).
3. Consolidate ADF activities (parameterized reusable pipeline) to reduce activity run counts.
4. Enforce structured logging schema to avoid verbose unstructured logs; adopt sampling for success paths (retain errors fully).
5. Use Table Storage for counters vs. Key Vault to lower transaction cost (Key Vault primarily for secrets, not high-frequency reads).
6. Consider Reserved Capacity (1-year) for Log Analytics once baseline stable (can save 20–30%).
7. Evaluate Storage compression for archival (e.g., pack older EDI into gzip bundles) if retrieval rarity justifies rehydration overhead.
8. Tag-driven cost dashboards (FinOps) with anomaly detection alert on >25% MoM spike unaligned to volume drivers.
9. Purview scan scheduling weekly vs. daily until semantic parsing adds more assets.
10. Periodic cost review (quarterly) – adjust scaling triggers and reserved commitments.

## 8. Cost Allocation & Tagging Model
| Dimension | Tag Key | Example Value | Allocation Use |
|----------|---------|---------------|---------------|
| Environment | env | prod | Roll-up by lifecycle stage |
| Workload | workload | edi | Distinguish from analytics / other apps |
| Data Sensitivity | dataSensitivity | PHI | Compliance reporting |
| Owner | owner | dataplatform | Accountability |
| Partner (where feasible) | partnerCode | PARTNERA | Showback / ingestion cost per partner (derived via Log Analytics) |
| Transaction Set | x12Set | 837 | Analytical cost attribution (custom log dimension) |

## 9. Risks & Mitigations
| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Underestimation of ST transactions per file (actual >5x) | Service Bus & Function cost spike | Medium | Implement early telemetry of ST count distribution; refine model month 1 |
| Large 837 batch spikes (100MB) | Ingestion latency & storage cost | Medium | Parallel block blob upload config; enforce partner file size guidance |
| Log verbosity creep | Log cost escalation | High | Logging standards + sampling; dashboards tracking GB/day |
| Control number counter contention | Retries inflate storage/Key Vault ops | Low | Use Table Storage optimistic concurrency; monitor retry metric |
| Early expansion to additional X12 sets (278, 820) | Increased orchestration & ack volume | Medium | Reassess cost envelope after scope change; apply reserved tiers as needed |
| Catalog growth via semantic parsing Phase 2 | Purview capacity cost doubling | Medium | Stage rollout; evaluate if single CU performance still adequate |
| Compliance mandates immutability for all tiers | Higher storage (no delete/tiering) | Low–Med | Engage compliance early; propose differential retention policy |

## 10. Future Phase Cost Impacts (Not in Year 1 Baseline)
| Feature | Added Resources / Costs | Order of Magnitude |
|---------|------------------------|-------------------|
| Real-time API ingestion (AS2/API Mgmt) | API Management, Front Door, Additional Functions | +$500–$1k/mo |
| Semantic EDI to FHIR transformation | Container Apps / Synapse Spark, Increased Storage & Logs | +$700–$1.5k/mo |
| Advanced ML anomaly detection | Azure Machine Learning / Cognitive Services | +$300–$800/mo |
| Event-sourced acknowledgments (higher event volume) | Service Bus / Event Grid ops ↑ | +$50–$150/mo |
| PGP encryption (per partner) | Key Vault key ops ↑, Compute for encrypt/decrypt | +$25–$75/mo |

## 11. Validation & Next Steps
1. Capture month-1 telemetry: (a) Files Ingested, (b) ST Messages Published, (c) Ack Files Generated, (d) Log GB Ingested, (e) Storage Growth by Tier, (f) Function Exec Count & GB-s, (g) ADF Activity Runs, (h) Service Bus Ops.
2. Apply formulas in Section 5.5; variance >10% vs. Expected triggers investigation or model adjustment.
3. After stabilization (≈30 days), evaluate Reserved Capacity / Commitment Tiers (Log Analytics, Potential ADF Data Flows if introduced) or Savings Plans (Functions Premium if adopted).
4. Quarterly refresh: update unit prices, reassess scaling triggers, verify Purview CU usage, and document any architectural changes affecting cost drivers.
5. Maintain FinOps review cadence (monthly light, quarterly deep dive) and add anomaly alerts for sudden >25% MoM shifts uncorrelated to volume metrics.

---
Prepared: <DATE_PLACEHOLDER – replace with YYYY-MM-DD>

Owner: Data Platform Architecture
