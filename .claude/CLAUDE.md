# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo contains only reusable GitHub Actions workflows (`workflow_call`) shared across all tidywf R packages. There is no local build, test, or lint step — all work is done in CI.

## Workflow inventory

| File | Name | Role in release |
|------|------|-----------------|
| `bump.yaml` | Bump Version | 1st — updates `DESCRIPTION`, renders `README.qmd`, commits |
| `condarise.yaml` | Conda Deploy | 2nd — builds with `rattler-build`, uploads to Anaconda, regenerates lock files |
| `tag.yaml` | Tag Release | 3rd — creates a `vX.Y.Z` git tag pointing at latest commit |
| `dockerise.yaml` | Docker Deploy | 4th — builds multi-arch image (linux/amd64, linux/arm64), pushes to ghcr.io |
| `pkgdownise.yaml` | pkgdown Deploy | 5th — deploys R package docs site to `gh-pages` branch |

## Key conventions

**Action pinning** — every `uses:` line is pinned to a full SHA, not a semver tag, for supply-chain safety. The human-readable version is kept in a comment (`# v3.2.0`). Dependabot keeps both in sync via weekly PRs.

**Bot identity** — commits made by CI use the GitHub App bot:
```
user.email = ${APP_ID}+tidywf-ci-bot[bot]@users.noreply.github.com
user.name  = tidywf-ci-bot[bot]
```
The App credentials come from `vars.BOT1_APP_ID` and `secrets.BOT1_APP_PRIVATE_KEY`.

**Miniforge version lock** — all Miniforge setups pin `miniforge-version: 26.1.0-0` to stay below mamba 2.6.0 due to [conda/conda-lock#906](https://github.com/conda/conda-lock/issues/906). Do not bump this without verifying the upstream issue is resolved.

**Branch-aware conda labels** — `condarise.yaml` detects `refs/heads/dev` and routes conda builds/uploads to the `dev` label on Anaconda; `main` goes to the default label.

**Conda lock platforms** — lock files are generated for `linux-64` and `linux-aarch64` only (server targets). Docker images are also built for both (`linux/amd64`, `linux/arm64`).

**Caller-side file layout** — workflows expect the calling repo to have:
- `deploy/conda/env/yaml/<name>.yaml` — conda environment spec (default)
- `deploy/conda/env/lock/` — destination for generated lock files
- `deploy/conda/recipe/recipe.yaml` — rattler-build recipe
- `DESCRIPTION` — R package metadata (for `bump.yaml`)
- `README.qmd` — rendered by `bump.yaml` after version bump

Optional `dvc` inputs (bool) activate DVC pull from S3 before the relevant step.

## Dependabot

Weekly updates for `github-actions` ecosystem are configured in `.github/dependabot.yml`. PRs from dependabot update the SHA pins and version comments.
