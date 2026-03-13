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
Build only from the approved design.**

In three words: **spec → environment → implementation.**

### Core Rules

1. **One phase owns one kind of work.**
   - Setup = route the user
   - Solution-design = understand, approve, discover, design
   - Builder = execute the locked plan

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
```

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

## The Mental Model

```
INTENT              FEASIBILITY              EXECUTION
───────────         ──────────────           ──────────
Understand          Discover + Design        Build
Lock the spec       Lock the design          Follow the plan
(Phase 1 + Gate 1)  (Phase 2-3 + Gate 2)     (Phase 4)
```

Scope, reasoning, and execution stay in that order. They never mix.
