## Puppet Conventions

Conventions for a **Puppet control repository** that is mid-migration from **Puppet 5
to Puppet 6**. The fleet has mixed agent versions during the transition, so manifests
generally must stay valid on both 5 and 6 until every agent is cut over. Grow this
section with real lessons as the migration proceeds — keep entries concrete ("this broke
a catalog compile"), not generic style advice.

### Puppet 5 → 6 migration landmines (the ones that actually bite)

- **Core resource types were removed in Puppet 6.** Types/providers that were built into
  the Puppet 5 agent moved to Forge modules in 6 — `cron`, `mount`, `yumrepo`, `augeas`,
  `selboolean`, `selmodule`, `ssh_authorized_key`, `sshkey`, `zone`, `zfs`, `zpool`, and
  more. A manifest that compiled on 5 fails on a 6 agent until the corresponding
  `puppetlabs-*` (or `puppet-*`) module is added to the **Puppetfile**. Audit for these
  first — they are the most common migration break.
- **Hiera 3 is gone.** Puppet 6 requires Hiera 5 (`version: 5` `hiera.yaml` at the global,
  environment, and module layers). Any legacy v3 `hiera.yaml` / `:backends:` config must be
  converted before a 6 master will use it.
- **Ruby version bump.** The Puppet 6 agent ships Ruby 2.5 (5 shipped 2.4). Custom facts,
  functions, and any bundled gems must work under 2.5.
- **App orchestration was removed** in 6; `stringify_facts` and other long-deprecated
  settings are gone. Do not reintroduce them.
- **Guard 6-only features while 5 agents remain.** `Deferred` functions (evaluate on the
  agent at apply time — the right tool for secrets) and the newest built-in functions exist
  only on 6. Don't use them in code that a Puppet 5 agent still has to compile/apply until
  the fleet has cut over.

### Control repo structure

- **Roles and profiles.** Component modules → profiles (technology-specific config) →
  roles (business-level; a node gets exactly one role). Node classification selects a role;
  the role includes profiles. Keep logic in profiles, data in Hiera, reusable code in
  component modules.
- **Puppetfile pins every module** to an exact version (or a git ref), managed by
  r10k / Code Manager. Environments map to git branches; promotion runs feature → test →
  production. Never float a dependency.
- **Data out of code.** All data lives in Hiera, never hardcoded in manifests. Secrets go
  through `hiera-eyaml` or Vault — plus `Deferred` on Puppet 6 so they never enter the
  catalog. Keep the Hiera hierarchy shallow and documented.
- Custom facts live in `<module>/lib/facter/`; custom functions in
  `<module>/lib/puppet/functions/` (the modern Puppet 4 API, not the legacy 3.x API).

### Manifest style & safety

- **Idempotency is non-negotiable.** A second `puppet apply`/agent run must show no
  changes. Prefer native resource types over `exec`; guard any unavoidable `exec` with
  `onlyif` / `unless` / `creates`.
- **Never `ensure => latest`** — it is non-deterministic and causes silent drift. Pin
  package versions (or use `installed`).
- Use typed, namespaced class parameters; enable `strict_variables`. Read facts from the
  `$facts[]` and `$trusted[]` hashes, not legacy top-scope `$::fact` names.
- Watch `undef` vs `''`, and Hiera returning a **string** (`"false"`) where the manifest
  expects a **boolean** — a frequent source of "why didn't this toggle" bugs.
- Order with explicit relationships/`require`; use `contain` (not bare `include`) when a
  class's resources must be contained for ordering. No reliance on declaration order.

### Validation & testing

- Validate before every commit: `puppet parser validate`, `puppet-lint` (clean),
  `metadata-json-lint` on module metadata.
- Unit-test catalog compilation with **rspec-puppet** (`bundle exec rake spec`), using
  `rspec-puppet-facts` to cover each supported OS. Acceptance tests via Litmus or Beaker.
- **Pin the toolchain during the migration.** The `puppet` gem, `rspec-puppet`, and
  related gems in the `Gemfile` should match the Puppet version you are testing against;
  run the suite under both 5 and 6 while the fleet is mixed.
- A failing validate or unit run is a blocker — do not open a PR with known failures.

### Useful references

- **Puppet 6 platform release notes / "types removed from core"** — the canonical list of
  what moved to modules: <https://puppet.com/docs/puppet/6/release_notes.html>.
- **Puppet language style guide** — <https://puppet.com/docs/puppet/6/style_guide.html>.
- **Roles and profiles method** — <https://puppet.com/docs/pe/latest/the_roles_and_profiles_method.html>.
- **Hiera 5** — <https://puppet.com/docs/puppet/6/hiera_intro.html>.
- **rspec-puppet** — <https://rspec-puppet.com/>.
