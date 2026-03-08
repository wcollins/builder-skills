# FlowAgent Pricing Analysis

**Date:** 2026-03-08
**Platform:** platform-6-aidev.se.itential.io
**Dataset:** 344 missions across 40+ unique agents

---

## Executive Summary

Token usage per mission is driven almost entirely by **tool response size** (97.4% input tokens), not by the agent's reasoning or step count. Step-based pricing alone doesn't work — the same number of steps can vary 60-100x in tokens depending on what data the tools return. The recommended model is a **4-tier token budget** based on the type of work being done, not the number of steps.

---

## 1. Raw Data — What We Measured

### Overall Distribution (344 missions)

| Metric | Min | P10 | P25 | Median | P75 | P90 | P95 | P99 | Max |
|--------|-----|-----|-----|--------|-----|-----|-----|-----|-----|
| Total tokens | 216 | 1,634 | 2,855 | 6,743 | 15,102 | 45,258 | 76,245 | 130,106 | 170,748 |

- **Input tokens = 97.4%** of total cost (tool responses fed back as context)
- **Output tokens = 2.6%** (the agent's actual reasoning is cheap)
- **Median tool calls per mission: 3**
- **Average tool calls per mission: 3.9**

### Token Usage by Tool Call Count

| Tool Calls | Missions | Median Tokens | P75 | P95 | Max | Predictable? |
|-----------|----------|--------------|-----|-----|-----|-------------|
| 0 | 24 | 1,222 | 1,859 | 2,684 | 5,020 | Yes |
| 1 | 59 | 4,401 | 9,242 | 75,597 | 76,317 | No — 61x spread |
| 2 | 68 | 3,349 | 6,815 | 76,245 | 149,465 | No — 100x spread |
| 3 | 54 | 6,878 | 8,677 | 126,107 | 126,180 | No — 91x spread |
| 4 | 31 | 9,123 | 20,082 | 45,258 | 45,469 | Moderate — 23x |
| 5 | 36 | 7,772 | 11,526 | 23,359 | 130,106 | No — 72x spread |
| 6 | 16 | 12,314 | 18,271 | 127,976 | 127,976 | No — 34x spread |
| 7 | 15 | 13,607 | 29,517 | 58,474 | 58,474 | Moderate — 21x |
| 8+ | 41 | 31,689 | 56,229 | 137,796 | 170,748 | No |

**Key finding:** The spread within each step count is massive. A 2-call mission can cost 1,496 tokens or 149,465 tokens. Steps don't predict cost.

### Why Steps Don't Predict Cost

The token-per-tool-call ratio has a coefficient of variation of **199%** (extremely high):

| Metric | Value |
|--------|-------|
| Tokens/call median | 2,286 |
| Tokens/call max | 76,317 |
| Standard deviation | 10,528 |
| CV (coefficient of variation) | 199% |

A single tool call can cost 364 tokens (creating a ticket) or 76,317 tokens (analyzing a workflow). The variance is in what the tool **returns**, not how many times it's called.

---

## 2. What Actually Drives Cost

### The 97/3 Rule

| Component | % of Total Tokens | What It Is |
|-----------|-------------------|------------|
| Input (context) | 97.4% | System prompt + conversation history + ALL previous tool responses |
| Output (reasoning) | 2.6% | Agent's tool calls + final conclusion |

The agent's thinking is almost free. The cost is carrying tool responses forward in context. Every step re-reads all previous tool results.

### Tool Response Size Categories

| Category | Examples | Response Size | Impact |
|----------|----------|--------------|--------|
| **Tiny** | Create ticket, check status, get ID | 50-500 tokens | Negligible |
| **Small** | Device lookup, list interfaces | 500-2,000 tokens | Low |
| **Medium** | Show commands, partial configs | 2,000-5,000 tokens | Moderate |
| **Large** | Full device config, workflow JSON | 10,000-30,000 tokens | High |
| **Massive** | Compliance scan results, bulk sync, full inventory | 30,000-100,000+ tokens | Dominant |

### Context Growth Pattern

```
Step 1:  system_prompt (500) + tool_response_1 (X)     = 500 + X
Step 2:  all of step 1 + tool_response_2 (Y)            = 500 + X + Y
Step 3:  all of step 2 + tool_response_3 (Z)            = 500 + X + Y + Z
...
Total input = sum of ALL previous responses × (n - position)
```

This is why a compliance agent with 3 calls costs 126K tokens — each compliance result is ~40K tokens, and steps 2 and 3 re-read step 1's result.

---

## 3. Agent Cost Profiles — Real Data

### Most Expensive Agents

| Agent | Missions | Median Tokens | Max Tokens | Avg Calls | Cost Driver |
|-------|----------|--------------|------------|-----------|-------------|
| Synch TO NetBox | 2 | 154,272 | 170,748 | 13 | Bulk device data sync |
| Synch FROM NetBox | 1 | 130,106 | 130,106 | 5 | Large inventory payloads |
| Infrastructure_Compliance_Agent | 5 | 126,142 | 127,976 | 3 | Compliance scan results |
| Workflow Analyzer | 11 | 76,245 | 149,465 | 2 | Full workflow JSON in context |
| Network Visualization as Mind Map | 3 | 87,801 | 120,065 | 12 | Device topology data |
| PSIRT Assessment Agent | 10 | 47,022 | 61,882 | 12 | Vulnerability scan data |

### Most Efficient Agents

| Agent | Missions | Median Tokens | Max Tokens | Avg Calls | Why It's Cheap |
|-------|----------|--------------|------------|-----------|----------------|
| Port_Turn_Up_Service_Agent | 13 | 10,875 | 16,655 | 7 | Small tool responses (ticket IDs, status) |
| SNOW Incident Troubleshooting Agent | 4 | 10,784 | 11,398 | 5 | Structured ITSM responses |
| Linux_Patch_Agent | 4 | 13,424 | 16,274 | 4 | Command outputs are short |
| Cloud_Ops_Provisioning_Agent | 3 | 14,811 | 16,141 | 6 | API responses are compact |

### The Pattern

Expensive agents pull **large unstructured data** (configs, compliance reports, inventory dumps).
Cheap agents work with **small structured data** (ticket IDs, status codes, short API responses).

---

## 4. Outlier Analysis

### Threshold: > 70,126 tokens (2 standard deviations above mean)

| Count | % of Total | Characteristics |
|-------|-----------|-----------------|
| 20 missions | 5.8% | These 20 missions consumed 44% of all tokens |

### Top 5 Outliers

| Agent | Tokens | Tool Calls | Root Cause |
|-------|--------|-----------|------------|
| Synch TO NetBox | 170,748 | 13 | Full device inventory sync — each call returns bulk data |
| Workflow Analyzer | 149,465 | 2 | Single workflow JSON (50K+ tokens) loaded into context |
| Synch TO NetBox | 137,796 | 10 | Same pattern — bulk data per call |
| Synch FROM NetBox | 130,106 | 5 | Large inventory payloads |
| Infrastructure_Compliance_Agent | 127,976 | 6 | Compliance results are enormous |

**Key insight:** The compliance agent uses only 3 tool calls but costs 126K tokens because the compliance plan result is ~40K tokens and gets re-read in every subsequent step. Tool call count is irrelevant — the response payload is everything.

---

## 5. Recommended Pricing Model

### Why NOT Step-Based Pricing

| Approach | Problem |
|----------|---------|
| Price per step | Same step can cost 364 or 76,317 tokens (199% CV) |
| Price per tool call | A ticket create (500 tokens) vs config dump (30K tokens) — can't charge the same |
| Price per token | Unpredictable for the customer, hard to budget |

### Recommended: Token Budget Tiers

| Tier | Budget | Missions Covered | Cumulative | Typical Use Cases |
|------|--------|-----------------|------------|-------------------|
| **S — Small** | 5,000 | 39% | 39% | LLM-only, single ticket create, status lookup, simple query |
| **M — Medium** | 20,000 | 41% | 80% | Port turn-up, device onboard, health check, patching, incident triage |
| **L — Large** | 75,000 | 14% | 94% | PSIRT scan, NOC assistant, multi-device ops, workflow analysis |
| **XL — Extra Large** | 175,000 | 6% | 100% | Compliance reporting, NetBox sync, bulk config dump, topology mapping |

### How It Works

1. **Customer selects a tier** when creating an agent or running a mission
2. **Agent runs until completion or budget exhaustion** — whichever comes first
3. **Budget is the ceiling**, not the charge — if a mission finishes in 3K tokens on a Medium tier, they paid for Medium
4. **Overage option** — instead of hard stop, charge per-token above the ceiling (discourages but doesn't block)

### Tier Selection Guide (for the customer)

| "What are you doing?" | Tier | Why |
|------------------------|------|-----|
| Create or update a ticket | S | Tiny tool responses |
| Check device status | S | Small response |
| Run a health check across devices | M | Multiple small responses |
| Provision a port or onboard a device | M | Several structured API calls |
| Analyze a workflow for issues | L | Workflow JSON is large |
| Run PSIRT vulnerability assessment | L | Scan data is substantial |
| Run compliance audit | XL | Compliance results are massive |
| Sync inventory with NetBox | XL | Bulk data transfer |
| Generate network topology visualization | XL | Full device data dump |

---

## 6. Risk Mitigation

### The 5.8% Problem

20 out of 344 missions (5.8%) consumed **44% of all tokens**. These are the compliance, sync, and analysis workloads. Without guardrails, a customer could accidentally run an XL workload on an S budget.

### Guardrail Options

| Guardrail | How It Works | Trade-off |
|-----------|-------------|-----------|
| **Hard budget cap** | Mission stops at token limit | Agent may not finish — bad UX |
| **Soft cap + warning** | Agent warned at 80%, hard stop at 120% | Better UX, slight overage risk |
| **Tool response truncation** | Large responses summarized before feeding back | Reduces cost 5-10x but may lose detail |
| **Tool classification** | Tag tools as S/M/L/XL — agent can only use tools matching its tier | Prevents mismatched expectations |
| **Pre-flight estimate** | Before mission starts, estimate cost based on tools in capabilities | Customer sees expected tier before running |

### Recommended Combination

1. **Pre-flight estimate** — when creating an agent, classify its tools and suggest a tier
2. **Soft cap at 80%** — agent gets a system message: "Approaching token budget. Wrap up."
3. **Hard stop at 120%** — prevents runaway missions
4. **Tool response truncation for XL tools** — optional, customer can enable to save cost

---

## 7. Financial Modeling

### Cost Per Tier (Claude Haiku at $0.80/M input, $4/M output)

| Tier | Budget | Typical Input | Typical Output | Est. LLM Cost |
|------|--------|--------------|----------------|---------------|
| S | 5,000 | 4,870 | 130 | $0.004 |
| M | 20,000 | 19,480 | 520 | $0.018 |
| L | 75,000 | 73,050 | 1,950 | $0.066 |
| XL | 175,000 | 170,450 | 4,550 | $0.154 |

### Cost Per Tier (Claude Sonnet at $3/M input, $15/M output)

| Tier | Budget | Est. LLM Cost |
|------|--------|---------------|
| S | 5,000 | $0.016 |
| M | 20,000 | $0.066 |
| L | 75,000 | $0.248 |
| XL | 175,000 | $0.580 |

### Cost Per Tier (GPT-4o at $2.50/M input, $10/M output)

| Tier | Budget | Est. LLM Cost |
|------|--------|---------------|
| S | 5,000 | $0.014 |
| M | 20,000 | $0.054 |
| L | 75,000 | $0.202 |
| XL | 175,000 | $0.472 |

**Note:** These are raw LLM API costs. Platform markup, compute, and tool execution costs are separate.

---

## 8. Key Takeaways

1. **Don't price by steps.** The data shows 199% coefficient of variation in tokens-per-step. It's not predictable.

2. **Price by workload type.** The customer knows if they're creating a ticket (S) or running compliance (XL). Map their intent to a tier.

3. **97.4% of cost is tool responses in context.** The agent's reasoning is almost free. The expensive part is what the platform tools return.

4. **80% of missions fit in S or M (under 20K tokens).** Most agent work is lightweight — don't let the 5.8% outliers set the price for everyone.

5. **Compliance and sync are a different class.** These should be priced separately or explicitly flagged as XL. They're not normal agent work — they're bulk data operations that happen to use an LLM.

6. **Tool response truncation is the biggest cost lever.** If you summarize a 30K-token config response down to 2K tokens, an XL mission becomes an M mission. This is an engineering decision, not a pricing one.

7. **Pre-flight estimation is possible.** You know which tools are in the agent's capabilities. You can estimate the tier before the mission runs based on the tools' historical response sizes.
