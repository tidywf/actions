# CLAUDE.md

Reusable `workflow_call` workflows for tidywf R packages. No local
build/test/lint — all work in CI.

See `README.md` for the workflow inventory, release process, caller-side file
layout, and conventions. Guardrails specific to editing this repo:

- **Action pinning** — keep the full-SHA pin AND the `# vX.Y.Z` comment in sync
  on every `uses:` line. Never downgrade a SHA to a bare tag. Dependabot updates
  both weekly.
- **Miniforge version lock** — all Miniforge setups pin
  `miniforge-version: 26.1.0-0` (stays below mamba 2.6.0 due to
  [conda/conda-lock#906](https://github.com/conda/conda-lock/issues/906)). Do
  not bump without verifying the issue is resolved.
- **Bot identity** — CI commits use the `tidywf-ci-bot[bot]` GitHub App
  (`vars.BOT1_APP_ID` / `secrets.BOT1_APP_PRIVATE_KEY`). Don't hardcode.
