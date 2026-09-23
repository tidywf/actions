Reusable GitHub Actions for tidywf
==================================

Reusable `workflow_call` workflows shared across the tidywf R packages. There is
no local build, test, or lint step; all work is done in CI.

## Inventory

| File                  | Name           | Kind               | Role                                                                                                            |
|-----------------------|----------------|--------------------|-----------------------------------------------------------------------------------------------------------------|
| `bump.yaml`           | Bump Version   | `workflow_call`    | Bumps `DESCRIPTION`, installs the package, renders `README.qmd`, commits, **pushes the `vX.Y.Z` tag**           |
| `condarise.yaml`      | Conda Deploy   | `workflow_call`    | Builds with `rattler-build`, uploads to Anaconda, generates lock files, **creates the GitHub Release + assets** |
| `dockerise.yaml`      | Docker Deploy  | `workflow_call`    | Downloads the release lock files, builds multi-arch image (linux/amd64, linux/arm64), pushes to ghcr.io         |
| `pkgdownise.yaml`     | pkgdown Deploy | `workflow_call`    | Builds the pkgdown site and deploys it to the `gh-pages` branch                                                 |
| `release.yaml`        | Release        | tag-triggered      | Runs in *this* repo on a `vX.Y.Z` tag push: moves the `vX` major alias tag, creates a GitHub Release            |
| `dvc-pull/action.yaml`| DVC Pull       | composite action   | Sets up DVC and pulls test data from public Cloudflare R2 (no credentials required)                             |

## Caller release pipeline

The four `workflow_call` workflows are **order-dependent**. A caller repo must
run them in this sequence:

```
bump  ──pushes tag vX.Y.Z──►  condarise  ──publishes release assets──►  dockerise
                                   │
                                   └──────────────────────────────────►  pkgdownise
```

Why the order matters:

1. `bump.yaml` is the only workflow that writes: it bumps `DESCRIPTION`,
   commits, and pushes the `vX.Y.Z` tag.
2. `condarise.yaml`, `dockerise.yaml` and `pkgdownise.yaml` all check out
   `ref: v${{ inputs.pkg_version }}`, so that tag must already exist.
3. `condarise.yaml` generates `conda-linux-64.lock` / `conda-linux-aarch64.lock`
   (these are **not** committed) and attaches them to the `vX.Y.Z` GitHub
   Release as `<pkg_name>-vX.Y.Z-conda-<platform>.lock`.
4. `dockerise.yaml` downloads exactly those assets into the build context as the
   bare `conda-<platform>.lock` names its `Dockerfile` `COPY`s.

`pkgdownise.yaml` only needs the tag, so it can run in parallel with
`dockerise.yaml`.

## Versioning convention

Caller package versions carry the dev/release distinction in their *shape*, not
in the branch they were built from:

| Version shape     | Meaning | Anaconda upload    | GitHub Release |
|-------------------|---------|-------------------|----------------|
| `x.y.z`           | release | default (`main`)  | normal         |
| `x.y.z.9XXX`      | dev     | `dev` channel     | `--prerelease` |

`condarise.yaml` derives both from the `pkg_version` input alone.

## Workflow inputs

### `bump.yaml`

| Input                | Type    | Required | Default                 | Notes                                        |
|----------------------|---------|----------|-------------------------|----------------------------------------------|
| `pkg_name`           | string  | yes      | —                       | Currently unused by the workflow body         |
| `pkg_version`        | string  | yes      | —                       | New version; also becomes the `vX.Y.Z` tag    |
| `dir_conda_env_yaml` | string  | no       | `deploy/conda/env/yaml` | Must contain `bump.yaml`                      |
| `dir_conda_recipe`   | string  | no       | `deploy/conda/recipe`   | Currently unused by the workflow body         |
| `dvc`                | boolean | no       | `false`                 | Pull DVC-tracked data before the bump         |

### `condarise.yaml`

| Input                | Type   | Required | Default                 | Notes                                                  |
|----------------------|--------|----------|-------------------------|--------------------------------------------------------|
| `pkg_name`           | string | yes      | —                       | Names `<dir_conda_env_yaml>/<pkg_name>.yaml` and assets |
| `pkg_version`        | string | yes      | —                       | Tag to check out; drives dev vs release behaviour       |
| `conda_org`          | string | no       | `tidywf`                | Anaconda owner and extra build channel                  |
| `dir_conda_recipe`   | string | no       | `deploy/conda/recipe`   | Must contain `recipe.yaml`                              |
| `dir_conda_env_yaml` | string | no       | `deploy/conda/env/yaml` | Must contain `condabuild.yaml` and `<pkg_name>.yaml`    |

### `dockerise.yaml`

| Input         | Type   | Required | Default | Notes                                                              |
|---------------|--------|----------|---------|--------------------------------------------------------------------|
| `pkg_version` | string | yes      | —       | Tag to check out; also the image tag                                |
| `build_args`  | string | no       | `""`    | Newline-separated `KEY=VALUE` pairs passed to `docker build --build-arg` |

### `pkgdownise.yaml`

| Input                 | Type    | Required | Default                 | Notes                                             |
|-----------------------|---------|----------|-------------------------|---------------------------------------------------|
| `pkg_name`            | string  | yes      | —                       |                                                   |
| `pkg_version`         | string  | yes      | —                       | Tag to check out                                  |
| `dir_conda_env_yaml`  | string  | no       | `deploy/conda/env/yaml` | Must contain `pkgdown.yaml`                       |
| `dvc`                 | boolean | no       | `false`                 | Pull DVC-tracked test data before building docs   |
| `install_from_source` | boolean | no       | `false`                 | `R CMD INSTALL` first; needed if pkg not on conda |

## Secrets and variables

Callers should pass `secrets: inherit` (or forward these explicitly):

| Name                        | Kind   | Used by               | Purpose                                     |
|-----------------------------|--------|-----------------------|---------------------------------------------|
| `BOT1_APP_ID`               | var    | bump, pkgdownise      | GitHub App client id for the CI bot token   |
| `BOT1_APP_PRIVATE_KEY`      | secret | bump, pkgdownise      | GitHub App private key                      |
| `ANACONDA_UPLOAD_TOKEN`     | secret | condarise             | `rattler-build upload anaconda` API key     |
| `GITHUB_TOKEN`              | auto   | condarise, dockerise  | Release read/write, ghcr.io login           |

## Caller-side file layout

Workflows expect the calling repo to have:

```
DESCRIPTION                              # R package metadata (bump.yaml)
README.qmd                               # rendered by bump.yaml after the bump
deploy/conda/recipe/recipe.yaml          # rattler-build recipe (condarise)
deploy/conda/env/yaml/
  bump.yaml                              # conda env for bump.yaml        -> bump_env
  condabuild.yaml                        # conda env for condarise.yaml   -> condabuild_env
  pkgdown.yaml                           # conda env for pkgdownise.yaml  -> pkgdown_env
  <pkg_name>.yaml                        # runtime env locked by conda-lock (condarise)
Dockerfile                               # must COPY conda-linux-64.lock / conda-linux-aarch64.lock
```

Note the four *separate* env specs under `deploy/conda/env/yaml/`: three
per-workflow tool environments plus the package runtime environment that
`conda-lock` resolves. The activated environment names (`bump_env`,
`condabuild_env`, `pkgdown_env`) are fixed by the workflows.

`deploy/conda/env/lock/` is the conventional home for committed lock files, but
the lock files `condarise.yaml` produces are published as release assets, not
committed.

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

## Cutting a release of *this* repo

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

`release.yaml` only matches three-part tags (`v[0-9]+.[0-9]+.[0-9]+`), so this
repo has no dev-release channel; the four-part dev convention above applies to
caller packages only.

Follow [semantic versioning](https://semver.org/): bump the major version for
breaking changes to a workflow's inputs/behaviour, minor for additive changes,
patch for fixes. A major bump (`v2.0.0`) creates a new `v2` alias and leaves `v1`
callers untouched until they migrate.

## Key conventions

**Action pinning**: every `uses` line is pinned to a full SHA, not a semver
tag, for supply-chain safety. The human-readable version is kept in a comment
(`# v3.2.0`). Dependabot keeps both in sync via weekly PRs.

**Self-repository references**: the internal `dvc-pull` composite action is
referenced as `uses: $/dvc-pull`, the self-repository shorthand, so it resolves
against whatever ref the caller pinned the reusable workflow to. Do not rewrite
it back to `tidywf/actions/dvc-pull@main`, which would silently escape the pin.

**Bot identity**: commits made by CI use the GitHub App bot:

```
user.email = ${APP_ID}+tidywf-ci-bot[bot]@users.noreply.github.com
user.name  = tidywf-ci-bot[bot]
```

The App credentials come from `vars.BOT1_APP_ID` and `secrets.BOT1_APP_PRIVATE_KEY`.

**Version-shaped conda channels**: `condarise.yaml` inspects `pkg_version`, not
the branch. A four-part `x.y.z.9XXX` version adds `--channel <org>/label/dev` to
the build and uploads with `--channel dev`; a three-part `x.y.z` leaves both
unset so Anaconda defaults to the `main` label.

**Conda lock platforms**: lock files are generated for `linux-64` and
`linux-aarch64` only (server targets). Docker images are also built for both
(`linux/amd64`, `linux/arm64`).

**Release-asset contract**: `condarise.yaml` publishes lock files named
`<pkg_name>-vX.Y.Z-conda-<platform>.lock` and `dockerise.yaml` matches on that
suffix. Changing the naming on either side breaks the handoff.

## Dependabot

Weekly updates for the `github-actions` ecosystem are configured in
`.github/dependabot.yml`. PRs from Dependabot update the SHA pins and version
comments.
