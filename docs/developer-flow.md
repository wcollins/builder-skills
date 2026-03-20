```
USER ARRIVES
     │
     ▼
"What are you here to do?"
     │
     ├──────────────────────────────────────┐
     │                                      │
     ▼                                      ▼
 EXPLORE                              BUILD FROM SPEC
     │                                      │
     ▼                                      ▼
 Auth now                             Pick a spec
 Pull bootstrap                       Fork → {use-case}/customer-spec.md
 Summarize env                        "Here's what happens next..."
 Use skills freely                          │
     │                                      ▼
     │                          ┌───────────────────────────┐
     │                          │    /solution-design        │
     │                          │                            │
     │                          │  Phase 1: UNDERSTAND       │
     │                          │    Read spec               │
     │                          │    Collect business context │ ← no auth
     │                          │    Ask missing questions    │ ← no API calls
     │                          │    Refine spec              │ ← pure conversation
     │                          │                            │
     │                          │  GATE 1: approve spec ✓    │
     │                          │    (intent locked)         │
     │                          │                            │
     │                          │  Phase 2: DISCOVER         │
     │                          │    Auth now                 │ ← first API call
     │                          │    Pull bootstrap data      │
     │                          │    Pull spec-contingent     │
     │                          │    Resolve capabilities     │
     │                          │    Match integrations       │
     │                          │    Find reuse candidates    │
     │                          │                            │
     │                          │  Phase 3: DESIGN           │
     │                          │    Produce solution-design  │
     │                          │                            │
     │                          │  GATE 2: approve design ✓  │
     │                          │    (plan locked)           │
     │                          └─────────────┬─────────────┘
     │                                        │
     │                                        ▼
     │                          ┌───────────────────────────┐
     │                          │    /itential-builder       │
     │                          │                            │
     │                          │  Execute locked plan       │
     │                          │  Test each component       │
     │                          │  Deliver project           │
     │                          └─────────────┬─────────────┘
     │                                        │
     │                                        ▼
     │                          ┌───────────────────────────┐
     │                          │    Phase 5: RECONCILE      │
     │                          │                            │
     │                          │  Diff built vs designed    │
     │                          │  Update solution-design.md │ ← as-built
     │                          │  Amend customer-spec.md    │ ← if scope changed
     │                          │  Engineer acknowledges ✓   │
     │                          └───────────────────────────┘
     │
     ▼
 Skills directly:
   /itential-builder
   /itential-devices
   /itential-golden-config
   /iag
   /flowagent
   /itential-lcm
   /itential-inventory
```

## Design Principles

**Lock intent before touching the environment.
Design against the approved intent.
Build only from the approved design.
Reconcile what was built back into the spec and design.**

In four words: **spec → environment → implementation → reconcile.**

### Core Rules

1. **One phase owns one kind of work.**
   - Setup = route the user
   - Solution-design = understand, approve, discover, design
   - Builder = execute the locked plan
   - Reconcile = capture deviations, update artifacts

2. **Approval happens once per artifact.**
   - Gate 1 = approve the spec (HLD)
   - Gate 2 = approve the design (LLD)
   - No double approval of the same thing.

3. **Pull late when data depends on scope.**
   - First understand and lock the spec.
   - Then pull only the environment data needed for that locked spec.
   - Early pulls are wasted when scope changes.

4. **Handoffs are artifact-based.**
   - Setup → solution-design: the forked spec file. Nothing else.
   - Solution-design → builder: a complete workspace (spec, design, all data files).
   - Not partial analysis, not verbal instructions — files.

5. **Builder does not reinterpret requirements.**
   - Once design is approved, builder executes the plan.
   - No reopening scope questions, no re-pulling discovery data.
   - If a file is missing, that's an upstream failure — stop and say so.

## Artifact Progression

```
spec-files/spec-*.md              Generic library spec (never modified)
        │
        │  fork + refine with business context
        ▼
{use-case}/customer-spec.md      Customized HLD (intent + business rules)
        │
        │  Gate 1: engineer approves → intent locked
        │
        │  auth, discover, resolve, design
        ▼
{use-case}/solution-design.md    LLD (components, plan, reuse/build/skip)
        │
        │  Gate 2: engineer approves → plan locked
        ▼
{use-case}/*.json                Built assets (workflows, templates, etc.)
        │
        │  Phase 5: reconcile built vs designed
        ▼
{use-case}/solution-design.md    Updated with "As-Built" section (deviations + actuals)
{use-case}/customer-spec.md      Updated with "Amendments" section (if scope changed)
```

On **rebuild of the same use case**, the reconciled files are the starting point:
- Gate 1 reviews the amended `customer-spec.md`, not the original library spec
- Phase 2-3 references the as-built `solution-design.md` as a known baseline
- The original library spec (`spec-files/spec-*.md`) is never modified

## Data Classification

| File | Type | When Pulled | By Whom |
|------|------|-------------|---------|
| `openapi.json` | Bootstrap | After Gate 1 | Solution-design |
| `tasks.json` | Bootstrap | After Gate 1 | Solution-design |
| `apps.json` | Bootstrap | After Gate 1 | Solution-design |
| `adapters.json` | Bootstrap | After Gate 1 | Solution-design |
| `applications.json` | Bootstrap | After Gate 1 | Solution-design |
| `devices.json` | Spec-contingent | After Gate 1 | Solution-design |
| `workflows.json` | Spec-contingent | After Gate 1 | Solution-design |
| `device-groups.json` | Spec-contingent | After Gate 1 | Solution-design |

For the **Explore** path, setup pulls bootstrap data immediately (the user needs it now).

## Builder Contract

The builder receives a **complete workspace**. Every file it needs is already there. The only API calls it makes are:
- **Create** — POST workflows, templates, projects
- **Update** — PUT to edit assets
- **Test** — POST jobs/start, GET job status
- **Schema fetch** — task schemas not yet in `task-schemas.json`
- **Re-auth** — if token expires, use `.env` to refresh `.auth.json`

If `tasks.json` or `adapters.json` is missing, the builder stops and tells the user. It does not re-pull.

## Reconcile Contract

Phase 5 is **light and automatic**. After the builder delivers, reconcile runs:

1. **Diff built vs designed** — compare the delivered assets against `solution-design.md`. Identify deviations: added error handlers, swapped adapters, changed task wiring, dropped or added components.

2. **Update `solution-design.md`** — append an `## As-Built` section at the end:
   - List each deviation with a one-line reason
   - Record actual asset names and IDs (workflow names, template names, project ID)
   - Do not rewrite the original design — the locked plan stays intact above

3. **Amend `customer-spec.md`** — only if scope changed during build. Append an `## Amendments` section:
   - List each scope change (requirement dropped, added, or modified)
   - Tag with date and reason
   - Do not rewrite the original spec — the locked intent stays intact above

4. **Engineer acknowledges** — the engineer confirms the reconcile is accurate. This is not a gate — it's a read-receipt. No approval workflow, no blocking.

**What Reconcile does NOT do:**
- Does not trigger a rebuild
- Does not reopen Gate 1 or Gate 2
- Does not modify the original library spec
- Does not pull new environment data

If deviations are large enough to warrant a redesign, that's a **new iteration** — start from `/itential-setup` with the reconciled files as input.

## Roles by Phase

| Phase | PM | Solution Architect | Infrastructure SME | Platform Engineer | QA | Product Owner |
|-------|----|--------------------|---------------------|-------------------|----|---------------|
| **Phase 1: Understand** | Facilitates requirements gathering, manages timeline | Translates business need into structured spec | Validates technical feasibility, provides domain constraints | — | — | Defines business need, success criteria, priorities |
| **Gate 1: Spec Approval** | Confirms scope matches SOW/timeline | Reviews spec for completeness and technical accuracy | Confirms infrastructure assumptions are sound | — | Reviews acceptance criteria for testability | Approves scope and business intent |
| **Phase 2: Discover** | — | Guides discovery priorities based on spec | Provides environment context (vendors, versions, topology) | Runs discovery against platform, maps capabilities | — | — |
| **Phase 3: Design** | Reviews design for timeline/resource impact | Produces solution design, maps spec to platform components | Validates device/protocol/vendor assumptions in design | Confirms platform capabilities, identifies reuse candidates | Plans test strategy based on design | — |
| **Gate 2: Design Approval** | Confirms design is deliverable within timeline | Approves architecture and component plan | Approves infrastructure and integration approach | Confirms buildability — tasks, adapters, patterns exist | Approves test plan | — |
| **Phase 4: Build** | Tracks progress, manages scope boundary | Available for design clarification | Available for infrastructure/vendor questions | Builds, tests each component, delivers project | Validates components against acceptance criteria | — |
| **Phase 5: Reconcile** | Reviews timeline actuals vs estimates for future planning | Reviews deviations — updates design patterns for future use | Reviews infrastructure findings for future specs | Documents deviations and amendments in artifacts | Validates final delivery matches amended scope | Acknowledges any scope amendments |

## The Mental Model

```
INTENT              FEASIBILITY              EXECUTION            RECONCILE
───────────         ──────────────           ──────────           ──────────
Understand          Discover + Design        Build                Diff + Update
Lock the spec       Lock the design          Follow the plan      Amend artifacts
(Phase 1 + Gate 1)  (Phase 2-3 + Gate 2)     (Phase 4)            (Phase 5)
```

Scope, reasoning, execution, and reconciliation stay in that order. They never mix.
On rebuild, the reconciled artifacts become the new starting point.
