# Itential — Builder Skills

[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

From spec to delivery — infrastructure automation and orchestration driven by AI agents.

---

## What This Is

A set of AI agent skills for the Itential Platform. Agents deliver automation end-to-end — from requirements through feasibility, design, build, and as-built documentation — or explore and build freestyle.

```
Requirements  →  Feasibility  →  Design  →  Build  →  As-Built
      │                │              │          │           │
  /spec-agent    /solution-       /solution-  /builder-  /builder-
                  arch-agent       arch-agent    agent      agent
      │                │              │          │           │
  customer-       feasibility.md  solution-    assets     as-built.md
  spec.md         (approved)      design.md    (delivered) (approved)
  (approved)                      (approved)
```

---

## Getting Started

```bash
/plugin install itential-builder@claude-plugins-official
```

Point at your platform:

```bash
/itential-builder:setup
```

---

## Interaction Modes

**Deliver from Spec** — structured end-to-end delivery with artifact-based approvals:
```
/itential-builder:spec-agent → /itential-builder:solution-arch-agent → /itential-builder:builder-agent
```

**FlowAgent to Spec** — convert an agent's proven pattern into a deterministic workflow:
```
/itential-builder:flowagent-to-spec → /itential-builder:solution-arch-agent → /itential-builder:builder-agent
```

**Generate Spec from Project** — extract formal documentation from existing automation:
```
/itential-builder:project-to-spec
```

**Explore** — connect to a platform, browse capabilities, build freely:
```
/itential-builder:explore
```

See [`docs/developer-flow.md`](docs/developer-flow.md) for the full flow diagram and design principles.

---

## Skills

| Skill | What It Does |
|-------|-------------|
| `/itential-builder:setup` | Initialize credentials for the current working directory |
| `/itential-builder:spec-agent` | Requirements — refine use case, produce approved HLD |
| `/itential-builder:solution-arch-agent` | Feasibility + Design — assess platform, produce solution design |
| `/itential-builder:builder-agent` | Build + As-Built — implement design, test, deliver, document |
| `/itential-builder:flowagent-to-spec` | Read a FlowAgent → produce deterministic workflow spec |
| `/itential-builder:project-to-spec` | Read an existing project → produce spec + design docs |
| `/itential-builder:explore` | Auth, discover platform, browse freely |
| `/itential-builder:flowagent` | Create and run AI agents (LLM providers, tools, missions) |
| `/itential-builder:iag` | IAG services — Python, Ansible, OpenTofu via iagctl |
| `/itential-builder:itential-mop` | Command templates with validation rules |

---

## Spec Library

22 technology-agnostic HLD specs in `spec-files/` covering:

**Networking** — Port Turn-Up, VLAN, Circuit, BGP, VPN, WAN Bandwidth

**Operations** — Software Upgrade, Config Backup, Health Check, Device Onboarding/Decommissioning, Change Management, Incident Remediation

**Security** — Firewall Rules, Cloud Security Groups, SSL Certificates

**Infrastructure** — DNS Records, IPAM, Load Balancer VIP, Config Drift, Compliance Audit

Each spec has 9 sections: Problem Statement, Flow, Phases, Design Decisions, Scope, Risks, Requirements, Batch Strategy, and Acceptance Criteria.

---

## Docs

- [`docs/developer-flow.md`](docs/developer-flow.md) — full lifecycle diagram and design principles
- [`docs/builder-flow.md`](docs/builder-flow.md) — build sequence and import pattern
- [`helpers/`](helpers/) — JSON scaffolds and reference workflow patterns

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) to get started.

Before contributing, you'll need to sign our [Contributor License Agreement](CLA.md).

## Support

- **Bug Reports**: [Open an issue](https://github.com/itential/builder-skills/issues/new)
- **Questions**: [Start a discussion](https://github.com/itential/builder-skills/discussions)
- **Lead Maintainer**: [@keepithuman](https://github.com/keepithuman)
- **Maintainer**: [@wcollins](https://github.com/wcollins)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by the <a href="https://github.com/itential">Itential</a> community
</p>
