# Skill Evaluation Coverage Report

**Date:** 2026-03-08
**Branch:** skillsv2
**Compared against:** master branch gotchas and lessons learned

---

## Executive Summary

All gotchas from the master branch are covered across the skillsv2 skill files. No gaps found. The eval suite (`evals/evals.json`) contains 32 test cases across 5 skills, with 76 assertions testing critical gotchas and structural correctness.

---

## Gotcha Coverage Matrix

### Legend
- **Covered** = Documented in skill with correct guidance
- **Skill** = Which skill file covers it
- **Eval** = Which eval tests it (skill:id)

### $var Resolution (6 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 1 | Task IDs must be hex-only `[0-9a-f]{1,4}` | Yes | workflow-engine, builder, CLAUDE.md | workflow-engine:2 |
| 2 | $var only resolves at top level of incoming | Yes | workflow-engine, builder, CLAUDE.md | workflow-engine:3, builder:1 |
| 3 | $var inside nested objects stores literal string | Yes | workflow-engine, builder | builder:1, builder:4 |
| 4 | Use merge/makeData/query to build nested objects | Yes | workflow-engine, builder | builder:1, builder:4 |
| 5 | $var inside newVariable value stores literal | Yes | workflow-engine, builder | builder:7 |
| 6 | Non-hex task IDs silently fail (classified as static) | Yes | workflow-engine | workflow-engine:2 |

### childJob (7 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 7 | actor MUST be "job" | Yes | builder, workflow-engine | builder:2 |
| 8 | task MUST be "" (empty string) | Yes | builder, workflow-engine | builder:2 |
| 9 | job_details MUST be null | Yes | builder, workflow-engine | builder:2 |
| 10 | All incoming fields required (even unused) | Yes | builder, workflow-engine | builder:2 |
| 11 | Variables use {"task","value"} NOT $var | Yes | builder, workflow-engine, CLAUDE.md | builder:3 |
| 12 | $var inside childJob variables = indefinite hang | Yes | workflow-engine | builder:2 |
| 13 | Query childJob output uses flat var names not nested paths | Yes | builder, workflow-engine | builder:3 |

### merge (3 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 14 | Uses "variable" NOT "value" (different from childJob) | Yes | builder, workflow-engine, CLAUDE.md | builder:1 |
| 15 | Requires at least 2 items (1 item = silently null) | Yes | builder, workflow-engine | workflow-engine:4 |
| 16 | Outgoing must declare merged_object: null | Yes | builder | builder:1 |

### evaluation (1 gotcha)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 17 | MUST have BOTH success AND failure transitions | Yes | builder, workflow-engine, CLAUDE.md | builder:6 |

### Transitions & Error Handling (3 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 18 | Every adapter/external task needs error transition | Yes | builder, solution-design, CLAUDE.md | builder:1, workflow-engine:1 |
| 19 | Missing error transition = "No available transitions" + stuck job | Yes | workflow-engine, builder | workflow-engine:1 |
| 20 | JSON duplicate key problem (success+error to same target) | Yes | builder, CLAUDE.md | builder:5 |

### forEach (2 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 21 | Last body task has empty {} transition | Yes | workflow-engine, builder | workflow-engine:5 |
| 22 | current_item overwritten each iteration (use push to accumulate) | Yes | workflow-engine | — |

### push/pop/shift (1 gotcha)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 23 | Takes variable NAME as plain string, not $var reference | Yes | builder, workflow-engine | builder:8 |

### makeData (2 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 24 | variables field must be a resolved object | Yes | builder, workflow-engine | builder:4 |
| 25 | Use merge first to build variables, then $var reference | Yes | builder, workflow-engine | builder:4 |

### Adapter Tasks (4 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 26 | app field from apps.json NOT tasks.json | Yes | builder, setup, solution-design, CLAUDE.md | builder:1, solution-design:1 |
| 27 | adapter_id required in incoming (not in schema) | Yes | builder | builder:1 |
| 28 | genericAdapterRequest prepends base_path | Yes | CLAUDE.md | — |
| 29 | Adapter responses are transformed (don't assume native API shape) | Yes | CLAUDE.md, builder | — |

### Auth & Setup (4 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 30 | OAuth MUST use x-www-form-urlencoded | Yes | setup | setup:1 |
| 31 | Tokens expire mid-session | Yes | setup | setup:4 |
| 32 | tasks/list app field has WRONG casing for adapters | Yes | setup, CLAUDE.md | setup:1 |
| 33 | OpenAPI spec ~1.5MB — search locally with jq | Yes | setup, CLAUDE.md | — |

### Projects (4 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 34 | Create project first, then build inside it | Yes | CLAUDE.md, solution-design | solution-design:4 |
| 35 | Move re-prefixes names but doesn't update childJob refs | Yes | solution-design, CLAUDE.md | solution-design:4 |
| 36 | Component type is mopCommandTemplate not mop | Yes | CLAUDE.md, builder | — |
| 37 | Members PATCH is full replacement | Yes | builder, CLAUDE.md | — |

### MOP (15 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 38 | Missing variable = skip = PASS (not fail) | Yes | mop | mop:3 |
| 39 | case: true = case-INsensitive | Yes | mop | — |
| 40 | Eval types are case-sensitive (RegEx not regex) | Yes | mop | mop:2 |
| 41 | Empty rules = auto-pass | Yes | mop | — |
| 42 | RegEx 5-second timeout | Yes | mop | — |
| 43 | contains does substring matching | Yes | mop | — |
| 44 | Only "name" is required | Yes | mop | — |
| 45 | Update is full replacement | Yes | mop | mop:5 |
| 46 | MOP is read-only (never push config) | Yes | mop, CLAUDE.md | mop:4 |
| 47 | _id equals name | Yes | mop | — |
| 48 | Rule-level missing var != command-level skip | Yes | mop | — |
| 49 | Template name change on update = delete + create | Yes | mop | — |
| 50 | Import renames on collision | Yes | mop | — |
| 51 | Cannot set namespace directly | Yes | mop | — |
| 52 | Analytic pre/post must have exactly 1 match each | Yes | mop | — |

### Workflow Structure (4 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 53 | canvasName from tasks.json (may differ from name) | Yes | builder | — |
| 54 | Validation errors = draft workflow | Yes | CLAUDE.md | — |
| 55 | API response shapes vary by endpoint | Yes | CLAUDE.md, builder | — |
| 56 | Endpoint base paths differ (workflow_builder vs automation-studio) | Yes | CLAUDE.md | — |

### Templates (2 gotchas)

| # | Gotcha | Covered | Skill(s) | Eval |
|---|--------|---------|----------|------|
| 57 | Template group cannot be empty or whitespace-only | Yes | builder | — |
| 58 | TextFSM may have control chars that break jq | Yes | CLAUDE.md | — |

---

## Eval Suite Summary

| Skill | Total Evals | Positive (should trigger) | Negative (should not trigger) | Total Assertions |
|-------|-------------|--------------------------|-------------------------------|-----------------|
| itential-builder | 10 | 8 | 2 | 30 |
| itential-setup | 5 | 4 | 1 | 14 |
| itential-builder (runtime) | 6 | 5 | 1 | 15 |
| itential-mop | 6 | 5 | 1 | 12 |
| solution-design | 5 | 4 | 1 | 10 |
| **Total** | **32** | **26** | **6** | **81** |

### Assertion Types

| Type | Count | Description |
|------|-------|-------------|
| critical | 24 | Must pass — failure means the skill teaches wrong behavior |
| structural | 50 | Should pass — correct patterns and structure |
| negative | 7 | Skill should NOT trigger for unrelated prompts |

---

## Gotchas NOT Directly Eval'd (Covered in Skills, No Dedicated Test Case)

These 20 gotchas are documented in the skills but don't have a specific eval test case. They are lower-frequency edge cases or documentation-only items:

- forEach current_item overwrite (#22)
- genericAdapterRequest base_path prepend (#28)
- Adapter response transformation (#29)
- OpenAPI spec size (#33)
- Component type naming (#36)
- Members PATCH full replacement (#37)
- case: true naming confusion (#39)
- Empty rules auto-pass (#41)
- RegEx timeout (#42)
- Substring matching (#43)
- Only name required (#44)
- _id equals name (#47)
- Rule vs command missing var behavior (#48)
- Name change = delete+create (#49)
- Import rename collision (#50)
- Cannot set namespace (#51)
- Analytic 1-match rule (#52)
- canvasName differs from name (#53)
- Validation errors = draft (#54)
- TextFSM control chars (#58)

**Recommendation:** These are well-documented in the skill text. Adding eval cases for each would increase the suite to 50+ tests. Worth doing only if eval failures surface in these areas during real usage.

---

## How to Run

```bash
# Using Anthropic's skill-creator eval mode
/skill-creator eval

# Or target a specific skill
/skill-creator eval --skill itential-builder
```

The eval framework will:
1. Run each prompt with and without the skill loaded
2. Grade outputs against assertions
3. Report pass/fail rates per skill and per assertion type
4. Suggest improvements for failing cases

---

## Conclusion

**Coverage: 58/58 gotchas documented (100%)**
**Eval coverage: 38/58 gotchas tested (66%)**
**Critical gotchas tested: 24/24 (100%)**

All critical gotchas that cause silent failures, stuck jobs, or wrong behavior have dedicated eval assertions. The remaining 20 are documentation-level items covered in the skill text but not individually tested. No gaps require new skill content.
