## Overlay: Puppet control repo (brownfield, Puppet 5 → 6)

This project is an **existing** Puppet control repository, imported into the repo before
this interview. It is **mid-migration from Puppet 5 to Puppet 6** with a mixed-version
agent fleet. The interview is therefore a *discovery and documentation* exercise, not a
greenfield design — adjust the base interview accordingly.

### Before you ask anything: survey the imported codebase

Read the repository first and build an inventory, so you interview only to fill the gaps
the code cannot answer (per the base rule "do not ask things already answered"). At
minimum, read:

- `Puppetfile` — module inventory and version pins; note anything floating or on a git ref.
- `environment.conf`, `hiera.yaml` (global + environment + module layers) — Hiera version
  (flag any lingering **Hiera 3** config) and hierarchy.
- `manifests/site.pp` and any ENC config — how nodes are classified.
- `site/` or `site-modules/` roles and profiles — enumerate roles and what each includes.
- `metadata.json` in local modules — `puppet` version requirement and OS support.
- `Gemfile` / `.fixtures.yml` / `spec/` — the test toolchain and existing coverage.
- CI config (`.gitlab-ci.yml`, `Jenkinsfile`, GitHub Actions) — validation/promotion gates.

Summarise the inventory back to me before the gap-filling questions.

### Area 1 additions (identity)
- What does this control repo manage — which services, and roughly how many nodes/roles?
- Puppet Enterprise or open-source Puppet? Master/agent or masterless (`puppet apply`)?

### Area 3 additions (platform & constraints)
- What OSes are under management, and what is the node inventory per role?
- **Migration state:** which masters/agents are on 6 vs still on 5, and what is the cutover
  plan/timeline? Must manifests stay Puppet 5-compatible until the fleet is fully migrated?
- Change windows, `noop`/canary policy, and what is deliberately *not* under Puppet
  management (hand-managed or other tooling).

### Area 4 additions (technical)
- r10k or Code Manager? How do git branches map to environments, and how are modules pinned?
- Hiera hierarchy and backends (yaml / eyaml / Vault); where do secrets live today?
- **Migration specifics:** which removed-from-core types (`cron`, `mount`, `yumrepo`,
  `augeas`, `ssh_authorized_key`, …) are used and still need Puppetfile module additions for
  Puppet 6? Any Hiera 3 → 5 conversion outstanding? Ruby 2.4 → 2.5 concerns in custom
  facts/functions/gems?

### Area 6 additions (persistence & data)
- Is PuppetDB in use (exported resources, queries)? How is Hiera data versioned and reviewed?

### Area 7 additions (team & process)
- Promotion workflow (feature → test → production) and who approves it.
- Existing CI: what validates (`parser validate`, `puppet-lint`, `rspec`), and what gates a merge?

### Area 8 additions (risks & unknowns)
- Biggest migration risks: mixed-agent compatibility, module version jumps, drift on nodes
  that rarely run, un-tested roles.
- Where is the tribal knowledge that is not captured anywhere in the repo?

### Output document guidance (adapt the base's six docs to a control repo)

- **product-brief** → *control-repo brief*: what the repo manages, the Puppet infrastructure
  (PE/OSS, master/masterless, r10k/Code Manager), and the current 5→6 migration status.
- **user-stories** → *managed services & operational requirements*: per role, what it
  guarantees and who depends on it.
- **architecture** → the *documented* topology as it exists: environments, node
  classification, the roles/profiles inventory, the Hiera hierarchy, and the Puppetfile
  module inventory.
- **platform-delivery** → OS/node inventory, agent versions (5 vs 6), the run and promotion
  workflow, and change windows.
- **json-schema** → omit, or repurpose as the Hiera data schema if the repo has a defined one.
- **build-plan** → the actual outstanding work, with the **Puppet 5 → 6 migration tasks**
  called out explicitly (Puppetfile additions for removed core types, Hiera 3→5 conversion,
  toolchain pinning, per-role test coverage) alongside any feature or refactor work.
