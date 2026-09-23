# CLAUDE.md

Reusable `workflow_call` workflows for tidywf R packages, plus the `dvc-pull`
composite action. No local build/test/lint — all work in CI.

See `README.md` for the workflow inventory, inputs, secrets, caller release
pipeline, caller-side file layout, and release process. Guardrails specific to
editing this repo:

- **Action pinning** — keep the full-SHA pin AND the `# vX.Y.Z` comment in sync
  on every `uses:` line. Never downgrade a SHA to a bare tag. Dependabot updates
  both weekly.
- **Self-repository `uses:`** — the internal composite action is referenced as
  `uses: $/dvc-pull` (`bump.yaml`, `pkgdownise.yaml`), so it resolves against
  the ref the caller pinned the reusable workflow to. This is deliberate
  (commit `5e62c3d`); do not "fix" it back to `tidywf/actions/dvc-pull@main`,
  which escapes the pin.
- **Miniforge version lock** — all Miniforge setups pin
  `miniforge-version: 26.1.0-0` (stays below mamba 2.6.0 due to
  [conda/conda-lock#906](https://github.com/conda/conda-lock/issues/906)). Do
  not bump without verifying the issue is resolved.
- **Bot identity** — CI commits use the `tidywf-ci-bot[bot]` GitHub App
  (`vars.BOT1_APP_ID` / `secrets.BOT1_APP_PRIVATE_KEY`). Don't hardcode.
- **Release-asset contract** — `condarise.yaml` publishes conda lock files as
  `<pkg_name>-vX.Y.Z-conda-<platform>.lock` release assets; `dockerise.yaml`
  matches on that suffix and writes them to the build context as bare
  `conda-<platform>.lock`. Changing the naming on one side breaks the other.
  Platforms are `linux-64` and `linux-aarch64` in both workflows.
- **Don't reintroduce `gh release download`** in `dockerise.yaml`. It reads the
  cached `assets` array on the release object, which intermittently returns
  empty. The current code resolves the release id and lists assets from the
  per-release endpoint, with retries. Rationale is in the step comment.
- **Version shape drives channels** — `condarise.yaml` decides dev vs release
  from `pkg_version` (4-part `x.y.z.9XXX` ⇒ dev channel + `--prerelease`), not
  from the branch ref. Keep docs and code aligned if this changes.
- **Caller ordering** — `condarise`/`dockerise`/`pkgdownise` check out
  `ref: v${{ inputs.pkg_version }}`, which only `bump.yaml` creates, and
  `dockerise` additionally needs `condarise`'s release assets. Any new workflow
  that consumes the tag inherits the same ordering constraint.
- **Input changes are breaking** — these are `workflow_call` interfaces pinned
  by caller repos. Removing or renaming an input needs a major version bump
  (see the release section in `README.md`). Note `bump.yaml` currently declares
  `pkg_name` and `dir_conda_recipe` without using them; leave them until a
  major bump.
