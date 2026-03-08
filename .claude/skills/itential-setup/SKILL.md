---
name: itential-setup
description: Connect to an Itential Platform, then choose ad-hoc exploration or spec-driven build. This is the single entry point for all work.
argument-hint: "[use-case-name]"
---

# Itential Setup — Connect and Go

This is the entry point. Authenticate, discover the environment, then build.

```
/itential-setup
    │
    ├── Step 1: Authenticate
    │
    ├── Step 2: "Exploring or building from a spec?"
    │     │
    │     ├── Exploring → Pull platform data → Use skills as needed
    │     │
    │     └── Spec-based → Pick spec → Pull platform data → Review spec → /solution-design
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

## Gotchas

- OAuth MUST use `Content-Type: application/x-www-form-urlencoded`, not JSON
- Tokens expire mid-session — if you get auth errors, re-authenticate
- `tasks/list` `app` field has WRONG casing for adapters — use `apps/list` for correct names
- OpenAPI spec is ~1.5MB — search it locally with `jq`, never load into context

## Step 2: Choose Your Path

Once authenticated, ask: **"Are you exploring or building from a spec?"**

### Path A: Exploring

The engineer wants to look around, build freestyle, or isn't sure yet.

**Pull platform data** to a working directory:

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
- **`/itential-builder`** — create projects, workflows, templates, command templates (MOP), run/test, debug
- **`/itential-devices`** — devices, backups, diffs, device groups
- **`/itential-golden-config`** — golden config, compliance, remediation
- **`/iag`** — IAG services (Python, Ansible, OpenTofu)

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

If the directory already exists AND the spec file is already there, **reuse it** — the engineer may have customized it from a previous session. Do NOT overwrite. Only copy the spec if it doesn't exist yet.

```bash
mkdir -p {use-case-name}
# Only fork the spec if it doesn't already exist
[ ! -f {use-case}/{use-case}-spec.md ] && cp spec-files/spec-port-turn-up.md {use-case}/{use-case}-spec.md
```

**3. Pull all platform data.**

Run these in two groups. **Do not run them all in one parallel batch** — if one call fails, parallel cancellation kills the others. Run Stage 1 together, then Stage 2 together.

**Stage 1: Core platform data** (run these in parallel):
```bash
curl -s "{BASE}/help/openapi?url={ENCODED_BASE}&token=TOKEN" > {use-case}/openapi.json
curl -s "{BASE}/workflow_builder/tasks/list?token=TOKEN" > {use-case}/tasks.json
curl -s "{BASE}/automation-studio/apps/list?token=TOKEN" > {use-case}/apps.json
curl -s "{BASE}/health/adapters?token=TOKEN" > {use-case}/adapters.json
curl -s "{BASE}/health/applications?token=TOKEN" > {use-case}/applications.json
```

**Stage 2: Environment-specific data** (run these in parallel, after Stage 1 succeeds):

**Devices** (note: POST, not GET):
```bash
curl -s -w "\n%{http_code}" -X POST "{BASE}/configuration_manager/devices?token=TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"options":{"start":0,"limit":1000,"sort":[{"name":1}],"order":"ascending"}}' \
  > {use-case}/devices.json
```
Response shape: `{"list": [...]}` — devices are in the `list` field.

**Device groups:**
```bash
curl -s -w "\n%{http_code}" "{BASE}/configuration_manager/deviceGroups?token=TOKEN" > {use-case}/device-groups.json
```

**Existing workflows:**
```bash
curl -s -w "\n%{http_code}" "{BASE}/automation-studio/workflows?limit=500&token=TOKEN" > {use-case}/workflows.json
```
Response shape: `{"items": [...]}` — workflows are in the `items` field.

**Handling failures:** Some endpoints may return errors (HTML pages, empty responses, or non-200 status codes). Before parsing any saved file, check if it contains valid JSON:
```bash
jq type {use-case}/devices.json 2>/dev/null || echo "empty"
```
If a file is invalid, treat it as "no data available" and move on — don't let one failed endpoint block the entire flow. Not every use case needs every data type (e.g., change management doesn't need devices).

**Do NOT invoke other skills during this step.** The APIs above are all you need for discovery. Only invoke `/itential-builder` later when you're ready to build.

**4. Review the spec against the environment:**

Read the forked spec and the environment data. For each capability and integration in the spec:
- Check if the platform can do it (adapter exists? app available?)
- Resolve what you can from the data
- Ask the engineer only what the data can't answer

Update `{use-case}/{use-case}-spec.md` with everything learned.

**5. Present the spec for approval (Gate 1):**

Show the engineer:
- Environment summary (adapters, apps, devices, existing workflows)
- Spec requirements resolved against the environment (what's available, what's missing)
- Remaining questions that data couldn't answer
- Updated spec with all changes

Ask: *"Here's your spec updated with what I found. Review it — add, remove, or change anything. When you approve, I'll design the solution."*

The engineer may add features, remove scope, change decisions, or adjust acceptance criteria. Update `{use-case}/{use-case}-spec.md` with every change.

**When the engineer approves: the spec is locked.** Save the file.

**6. Transition to `/solution-design`** — the working directory has all the data and an approved spec. Solution-design reads local files and produces the implementation plan (Gate 2).

---

## Files Created

### Exploring

| File | Purpose |
|------|---------|
| `openapi.json` | Full API reference — search locally, never load into context |
| `tasks.json` | Task catalog — search with grep |
| `apps.json` | Apps and adapters with `name` and `type` |
| `adapters.json` | Adapter details: `id`, `package_id`, `state`, `connection.state` |
| `applications.json` | Application details with state |

### Spec-based — adds:

| File | Purpose |
|------|---------|
| `{use-case}-spec.md` | Forked spec — updated with environment details, engineer input |
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

**When debugging — check local files FIRST, not the API:**
- Wrong field name? → `openapi.json` has every request body schema
- Task not found? → `tasks.json` has all tasks — search with grep or jq
- Wrong app name? → `apps.json` has the correct casing
- Already fetched a schema? → Check `task-schemas.json` before calling `multipleTaskDetails` again

## Key Adapter Mapping

- `app` field in workflow tasks uses `apps/list` `name` (e.g., `Servicenow`)
- `adapter_id` in workflow tasks uses `health/adapters` `id` (e.g., `ServiceNow`)
- `tasks/list` `app` field may have WRONG casing — don't trust it for adapter names
