Reusable GitHub Actions for tidywf
==================================

Reusable `workflow_call` workflows shared across the tidywf R packages. There is
no local build, test, or lint step; all work is done in CI.

## Workflow inventory

| File              | Name           | Role                                                                             |
|-------------------|----------------|----------------------------------------------------------------------------------|
| `bump.yaml`       | Bump Version   | Updates `DESCRIPTION`, renders `README.qmd`, commits                             |
| `condarise.yaml`  | Conda Deploy   | Builds with `rattler-build`, uploads to Anaconda, regenerates lock files         |
| `dockerise.yaml`  | Docker Deploy  | Builds multi-arch image (linux/amd64, linux/arm64), pushes to ghcr.io            |
| `pkgdownise.yaml` | pkgdown Deploy | Deploys R package docs site to `gh-pages` branch                                 |
| `release.yaml`    | Release        | On a `vX.Y.Z` tag push: moves the `vX` major alias tag, creates a GitHub Release |

`bump`/`condarise`/`dockerise`/`pkgdownise` are `workflow_call` reusable
workflows invoked by caller repos. `release.yaml` runs in *this* repo, triggered
by pushing a semver tag.

## Referencing releases

Caller repos should pin to a release instead of `@main`. Two options:

- **Moving major alias** (convenience): auto-receives patch/minor updates:

  ```yaml
  uses: tidywf/actions/.github/workflows/bump.yaml@v1
  ```

- **Exact version** (reproducible): immutable; bumped by Dependabot:

  ```yaml
  uses: tidywf/actions/.github/workflows/bump.yaml@v1.2.3
  ```

`@v1` is a literal tag that `release.yaml` force-moves onto the newest `v1.x.y`
after each release; it is *not* a semver range resolved by GitHub.

## Cutting a release

Releases are driven by pushing a semver tag. Use the Makefile helper (validates
semver, clean tree, `main` branch, and that the tag is new):

```sh
make release V=1.2.3
```

Or manually:

```sh
git tag v1.2.3
git push origin v1.2.3
```

Either way, the `vX.Y.Z` tag push triggers [`release.yaml`](.github/workflows/release.yaml),
which:

1. moves the `vX` alias tag (e.g. `v1`) to the new `vX.Y.Z`, and
2. creates/refreshes the GitHub Release with generated notes.

Follow [semantic versioning](https://semver.org/): bump the major version for
breaking changes to a workflow's inputs/behaviour, minor for additive changes,
patch for fixes. A major bump (`v2.0.0`) creates a new `v2` alias and leaves `v1`
callers untouched until they migrate.

## Key conventions

**Action pinning**: every `uses` line is pinned to a full SHA, not a semver
tag, for supply-chain safety. The human-readable version is kept in a comment
(`# v3.2.0`). Dependabot keeps both in sync via weekly PRs.

**Bot identity**: commits made by CI use the GitHub App bot:

```
user.email = ${APP_ID}+tidywf-ci-bot[bot]@users.noreply.github.com
user.name  = tidywf-ci-bot[bot]
```

The App credentials come from `vars.BOT1_APP_ID` and `secrets.BOT1_APP_PRIVATE_KEY`.

**Branch-aware conda labels**: `condarise.yaml` detects `refs/heads/dev` and
sets `ANACONDA_LABEL=--label dev` for uploads; on `main` the variable is left
unset, so `rattler-build upload anaconda` omits `--label` and Anaconda defaults
to the `main` label.

**Conda lock platforms**: lock files are generated for `linux-64` and
`linux-aarch64` only (server targets). Docker images are also built for both
(`linux/amd64`, `linux/arm64`).

## Caller-side file layout

Workflows expect the calling repo to have:

- `deploy/conda/env/yaml/<name>.yaml`: conda environment spec (default)
- `deploy/conda/env/lock/`: destination for generated lock files
- `deploy/conda/recipe/recipe.yaml`: rattler-build recipe
- `DESCRIPTION`: R package metadata (for `bump.yaml`)
- `README.qmd`: rendered by `bump.yaml` after version bump

Optional `dvc` inputs (bool) activate DVC pull from S3 before the relevant step.

## Dependabot

Weekly updates for the `github-actions` ecosystem are configured in
`.github/dependabot.yml`. PRs from Dependabot update the SHA pins and version
comments.
