# Itential Platform — AI-Assisted Development

Skills and specs that enable an AI agent (Claude Code) to help engineers build automation on the Itential Platform.

## What's Here

```
.claude/skills/              Claude Code slash commands
  itential-setup/            Platform auth + bootstrap
  itential-studio/           Workflows, templates, adapters, projects
  itential-devices/          Devices, backups, diffs, device groups
  itential-golden-config/    Golden config, compliance, remediation
  solution-design/           Spec-driven design + build process

helpers/                     JSON templates + bootstrap script
spec-files/                  Technology-agnostic HLD use-case specs
docs/                        Architecture diagrams
CLAUDE.md                    Agent instructions (auto-loaded by Claude Code)
```

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Access to an Itential Automation Platform instance
  - **Local dev**: URL (e.g., `http://localhost:4000`) + username/password
  - **Cloud**: URL + OAuth client_id/client_secret

### Getting Started

```bash
git clone https://github.com/keepithuman/itential-skills.git
cd itential-skills
claude
```

Claude Code automatically loads `CLAUDE.md` and the 5 skills. You'll see them in the `/` slash command picker.

### First Run: Connect to Your Platform

Once inside Claude Code, tell the agent your platform details:

```
> Connect to my Itential platform at http://localhost:4000 with admin/admin
```

Or for cloud:
```
> Connect to my platform at https://my-instance.itential.io
> Client ID: abc123, Client Secret: xyz789
```

The agent authenticates, pulls the task catalog (11,000+ tasks), discovers adapters, devices, and applications, and creates a working directory with everything it needs to start building.

### Then: Choose Your Path

After setup, the agent asks what you want to do:

**Build from a spec** — pick a use-case spec (e.g., Port Turn-Up, Software Upgrade) and the agent designs + builds the solution for your environment:
1. Forks the spec to your working directory (your copy to customize)
2. Discovers devices, workflows, adapters in your environment
3. Collects your business context (naming conventions, policies)
4. Produces a solution design, walks through it with you
5. Saves the approved spec + design before building
6. Builds and tests everything step by step

Your spec (`{use-case}/spec.md`) is your source of truth. Change it later to add features, then re-run.

**Explore / build freestyle** — use the skills directly:
```
> List all devices and their OS types
> Create a command template for show vlan brief
> Build a workflow that backs up all Cisco devices
```

See `docs/developer-flow.md` for the full process diagram.

## Skills

| Skill | What It Does |
|-------|-------------|
| `/itential-setup` | **Start here.** Auth, bootstrap, then choose: build from spec or explore freestyle. |
| `/itential-studio` | Build workflows, Jinja2/TextFSM templates, command templates, projects. Run and test jobs. |
| `/itential-devices` | List devices, backup configs, diff configs, manage device groups, apply templates |
| `/itential-golden-config` | Create golden config trees, config specs, compliance plans. Run compliance, grade, remediate. |
| `/solution-design` | Entered from setup. Fork spec → discover → design → refine → plan → build. |

## Spec Files

21 technology-agnostic HLD specs that describe **what** to automate, not how:

| Spec | Use Case |
|------|----------|
| `spec-software-upgrade.md` | Network device OS upgrade with pre/post validation and rollback |
| `spec-circuit-provisioning.md` | Dual-sided circuit turn-up with A-side/Z-side coordination |
| `spec-dns-record-management.md` | DNS record CRUD across providers with propagation verification |
| `spec-config-backup-compliance.md` | Scheduled config backups with drift detection and compliance checking |
| `spec-vlan-provisioning.md` | VLAN create/modify/delete across campus and DC switches |
| `spec-firewall-rule-lifecycle.md` | Rule request → validate → deploy → verify → recertify → decommission |
| `spec-device-onboarding.md` | Day-0/Day-1 provisioning: base config, register, monitor, verify |
| `spec-incident-auto-remediation.md` | Alert → classify → match playbook → remediate → verify → close |
| `spec-network-compliance-audit.md` | Scan configs against standards, grade, report, optionally remediate |
| `spec-change-management.md` | Maintenance window orchestration: ticket, approve, suppress, execute, restore |
| `spec-device-decommissioning.md` | Remove from monitoring, IPAM, inventory, archive configs |
| `spec-bgp-peer-provisioning.md` | Add/modify/remove BGP sessions with both-side deployment and verification |
| `spec-network-health-check.md` | Standardized health check: CPU, memory, interfaces, neighbors, reachability |
| `spec-load-balancer-vip.md` | VIP provisioning with pool, health monitors, and persistence profiles |
| `spec-cloud-security-groups.md` | AWS SG / Azure NSG / GCP firewall rule management with blast-radius analysis |
| `spec-ssl-certificate-lifecycle.md` | Certificate request → deploy → verify → monitor expiry → auto-renew |
| `spec-wan-bandwidth-modification.md` | Circuit bandwidth upgrade/downgrade with QoS policy updates |
| `spec-config-drift-remediation.md` | Detect config drift from golden standard, classify, remediate or ticket |
| `spec-vpn-tunnel-provisioning.md` | IPsec/GRE tunnel setup with both-endpoint config and traffic verification |
| `spec-ipam-lifecycle.md` | IP allocate → assign → track → reclaim with DNS/DHCP integration |
| `spec-port-turn-up.md` | L2/L3 port provisioning with ITSM, IPAM, DCIM, and monitoring updates |

Each spec has 9 sections: Problem Statement, High-Level Flow, Phases, Key Design Decisions, Scope, Risks, Requirements, Batch Strategy, and Acceptance Criteria.

## Helpers

JSON templates in `helpers/` provide starting points for API calls:

- `bootstrap.sh` — bootstraps a use-case working directory
- `create-workflow.json`, `create-command-template.json`, `create-template-jinja2.json` — asset creation
- `workflow-task-application.json`, `workflow-task-adapter.json` — task templates for workflows
- `create-project.json`, `add-components-to-project.json` — project packaging

