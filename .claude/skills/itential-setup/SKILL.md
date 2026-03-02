---
name: itential-setup
description: Connect to an Itential Platform, then choose ad-hoc exploration or spec-driven build. This is the single entry point for all work.
argument-hint: "[use-case-name]"
---

# Itential Setup — Connect and Go

This is the entry point. Authenticate, choose your path, then the right amount of discovery happens automatically.

```
/itential-setup
    │
    ├── Step 1: Auth only (instant)
    │
    ├── Step 2: "Ad-hoc or spec-based?"
    │     │
    │     ├── Ad-hoc → Light bootstrap → Explore with skills
    │     │
    │     └── Spec-based → Pick spec → Heavy bootstrap → Solution design flow
    │
    └── Already set up? → Reuse existing working directory
```

---

## Step 1: Authenticate

**Check for an env file first.** If one exists, use it — don't ask questions.

Look for environment files in this order:
1. `{use-case}/.env` — use-case-specific (if working directory already exists)
2. `environments/*.env` — pre-configured environments at repo root

If an env file is found, read it and authenticate automatically. If not, ask the engineer:
1. Platform URL
2. Credentials (username/password or client_id/secret)

### Environment File Format

```bash
# environments/local-dev.env
PLATFORM_URL=http://localhost:4000
AUTH_METHOD=password       # "password" or "oauth"
USERNAME=admin             # for password auth
PASSWORD=admin             # for password auth
CLIENT_ID=your-id          # for oauth
CLIENT_SECRET=your-secret  # for oauth
```

Pre-configured environments are in `environments/`:
- `local-dev.env` — local development (localhost:4000, admin/admin)
- `cloud-lab.env` — cloud lab instance (OAuth)
- `staging.env` — staging instance (OAuth)

The engineer can also create their own `.env` file or copy one: `cp environments/local-dev.env my-use-case/.env`

### Local Development (username/password)

```
POST /login
Content-Type: application/json

{"username": "admin", "password": "admin"}
```

Returns a token string. Use it as a query parameter on all subsequent calls:
```
GET /health/adapters?token=TOKEN
```

### Cloud / OAuth (client_credentials)

```
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

client_id=YOUR_CLIENT_ID
client_secret=YOUR_CLIENT_SECRET
grant_type=client_credentials
```

Returns `{"access_token": "eyJhbG..."}`. Use it as a Bearer token:
```
GET /health/adapters
Authorization: Bearer eyJhbG...
```

### Token Expiration

Tokens expire. If you get authentication errors mid-session, re-authenticate.

---

## Step 2: Choose Your Path

Once authenticated, ask: **"Are you exploring or building from a spec?"**

### Path A: Ad-hoc / Explore

The engineer wants to poke around, build freestyle, or isn't sure yet.

**Light bootstrap** — pull only what's needed to explore:

```bash
mkdir {use-case-name}

# OpenAPI spec — API reference (~1.5MB, search locally, never load into context)
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token=TOKEN" > {use-case}/openapi.json

# Task catalog (11,000+ tasks)
curl -s "{BASE}/workflow_builder/tasks/list?token=TOKEN" > {use-case}/tasks.json

# Apps/adapters list
curl -s "{BASE}/automation-studio/apps/list?token=TOKEN" > {use-case}/apps.json

# Adapter health
curl -s "{BASE}/health/adapters?token=TOKEN" > {use-case}/adapters.json

# Application health
curl -s "{BASE}/health/applications?token=TOKEN" > {use-case}/applications.json
```

Present a quick summary (adapters running, app count, task count) and point them to the skills:
- **`/itential-studio`** — workflows, templates, command templates, projects
- **`/itential-devices`** — devices, backups, diffs, device groups
- **`/itential-golden-config`** — golden config, compliance, remediation

### Path B: Build from a Spec

The engineer wants to build a use case from an HLD spec.

**1. Pick a spec.** Present the available specs from `spec-files/`, grouped by category:

| Category | Specs |
|----------|-------|
| **Networking** | Port Turn-Up, VLAN Provisioning, Circuit Provisioning, BGP Peer, VPN Tunnel, WAN Bandwidth |
| **Operations** | Software Upgrade, Config Backup, Health Check, Device Onboarding, Device Decommissioning, Change Management, Incident Remediation |
| **Security** | Firewall Rules, Cloud Security Groups, SSL Certificates |
| **Infrastructure** | DNS Records, IPAM Lifecycle, Load Balancer VIP, Config Drift Remediation, Compliance Audit |

Or the engineer describes what they need and you recommend a spec.

**2. Create working directory and fork the spec:**
```bash
mkdir {use-case-name}
cp spec-files/spec-port-turn-up.md {use-case}/spec.md
```

**3. Heavy bootstrap** — pull everything needed for design + build. Two stages:

**Stage 1: Core platform data** (direct API calls):
```bash
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token=TOKEN" > {use-case}/openapi.json
curl -s "{BASE}/workflow_builder/tasks/list?token=TOKEN" > {use-case}/tasks.json
curl -s "{BASE}/automation-studio/apps/list?token=TOKEN" > {use-case}/apps.json
curl -s "{BASE}/health/adapters?token=TOKEN" > {use-case}/adapters.json
curl -s "{BASE}/health/applications?token=TOKEN" > {use-case}/applications.json
```

**Stage 2: Use-case data** — invoke the other skills using the Skill tool to get the correct API details:
- **Invoke `/itential-devices`** → use its device listing API (POST with options body) to pull devices and device groups. Save to `{use-case}/devices.json` and `{use-case}/device-groups.json`.
- **Invoke `/itential-studio`** → use its workflow listing API to pull existing workflows and templates. Save to `{use-case}/workflows.json`.

**You MUST invoke these skills** — they have the correct HTTP methods, request bodies, and response shapes. The device endpoint is a POST (not GET), workflows use `items` (not `results`). Don't guess, load the skill.

**4. Present the full environment summary:**
- Adapters running (which external systems are available)
- Device inventory (count, OS types)
- Existing workflows (reuse candidates)
- Existing templates and command templates

**5. Transition to `/solution-design`** — the working directory is fully bootstrapped. Solution-design reads local files, makes zero additional API calls for discovery.

---

## What Gets Created

### Light Bootstrap (ad-hoc)

| File | Purpose |
|------|---------|
| `openapi.json` | Full API reference — search locally, never load into context |
| `tasks.json` | Task catalog — search with grep |
| `apps.json` | Apps and adapters with `name` and `type` |
| `adapters.json` | Adapter details: `id`, `package_id`, `state`, `connection.state` |
| `applications.json` | Application details with state |

### Heavy Bootstrap (spec-based) — adds:

| File | Purpose |
|------|---------|
| `spec.md` | Customer's spec — forked from generic, their source of truth |
| `devices.json` | Device inventory |
| `workflows.json` | Existing workflows (reuse candidates) |
| `device-groups.json` | Device groups |

---

## Using the OpenAPI Spec

The `openapi.json` is the source of truth for API details. Search it locally:

```bash
# Find all endpoints for a specific app
jq '.paths | keys[] | select(contains("configuration_manager"))' {use-case}/openapi.json

# Check if an endpoint is GET or POST
jq '.paths["/configuration_manager/devices"] | keys' {use-case}/openapi.json

# Get request body schema
jq '.paths["/configuration_manager/devices"].post.requestBody' {use-case}/openapi.json
```

**When an API call fails or returns 404:** look it up in `openapi.json` first. Don't guess.

## Key Adapter Mapping

- `app` field in workflow tasks uses `apps/list` `name` (e.g., `Servicenow`)
- `adapter_id` in workflow tasks uses `health/adapters` `id` (e.g., `ServiceNow`)
- `tasks/list` `app` field may have WRONG casing — don't trust it for adapter names
