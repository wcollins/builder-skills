# Quickstart Guide

From install to your first delivery in minutes.

---

## 1. Install the Plugin

Open Claude Code and run:

```bash
/plugin marketplace add itential/builder-skills
/plugin install itential-builder@itential-builder
```

This gives you all the skills as slash commands, available anywhere in Claude Code.

---

## 2. Set Up Your Environment

Copy one of the environment templates to your use-case directory and edit it with your platform credentials:

```bash
# Cloud / OAuth
cp environments/cloud-lab.env my-use-case/.env

# Local dev
cp environments/local-dev.env my-use-case/.env

# Staging
cp environments/staging.env my-use-case/.env
```

Open `.env` and fill in your values:

```bash
PLATFORM_URL=https://your-platform.itential.io
AUTH_METHOD=oauth
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret
```

> The agent reads `.env` automatically — you authenticate once and every skill reuses the token.

---

## 3. Pick Your Flow

### Deliver from Spec _(recommended for new automation)_

Start with a use case, build it end-to-end with full traceability.

```
/itential-builder:spec-agent
```
Claude refines your use case and produces an approved `customer-spec.md`.

```
/itential-builder:solution-arch-agent
```
Claude connects to your platform, assesses feasibility, and produces `solution-design.md`.

```
/itential-builder:builder-agent
```
Claude builds all assets, tests each component, delivers, and produces `as-built.md`.

---

### Explore _(no spec, freestyle)_

Connect to a platform and build freely without following a delivery lifecycle.

```
/itential-builder:explore
```

---

### FlowAgent to Spec _(convert an agent to a workflow)_

Take an existing FlowAgent and convert its proven pattern to a deterministic workflow.

```
/itential-builder:flowagent-to-spec
```
Then continue with `/itential-builder:solution-arch-agent` → `/itential-builder:builder-agent`.

---

### Generate Spec from Project _(document existing automation)_

Read an existing project and extract the spec and solution design.

```
/itential-builder:project-to-spec
```

---

## 4. What Gets Produced

| Stage | Artifact | What It Is |
|-------|----------|------------|
| Requirements | `customer-spec.md` | Approved HLD — scope, flow, acceptance criteria |
| Feasibility | `feasibility.md` | Platform capability assessment |
| Design | `solution-design.md` | Component inventory, adapter mappings, build plan |
| Build | `assets/` | Delivered workflows, templates, configs |
| As-Built | `as-built.md` | Delivered state, deviations, learnings |

Each artifact is approved by the engineer before the next stage begins.

---

## 5. Troubleshooting

**Auth fails on first run**
- Check `PLATFORM_URL` has no trailing slash
- For OAuth: verify `CLIENT_ID` and `CLIENT_SECRET` are correct
- For local: default is `USERNAME=admin` / `PASSWORD=admin`

**Skill not found after install**
- Restart Claude Code after installing the plugin
- Verify install: `/plugin list`

**Platform data not pulling**
- Run `/itential-builder:explore` first to confirm connectivity
- Check that your platform is reachable from your machine

---

## Reference

- [`docs/developer-flow.md`](developer-flow.md) — full lifecycle diagram and design principles
- [`docs/builder-flow.md`](builder-flow.md) — build sequence and import pattern
- [`helpers/`](../helpers/) — JSON scaffolds for workflows, templates, and projects
- [`spec-files/`](../spec-files/) — 22 ready-to-use infrastructure automation specs
