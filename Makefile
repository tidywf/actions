# Release helper for tidywf/actions.
#
# Usage:
#   make release V=1.2.3
#
# Validates, creates the `vX.Y.Z` tag on the current commit, and pushes it.
# The push triggers .github/workflows/release.yaml, which moves the `vX`
# alias tag and creates the GitHub Release.

SHELL := /bin/bash
TAG   := v$(V)

.PHONY: release check-version check-clean check-branch check-tag

release: check-version check-clean check-branch check-tag
	@echo "Tagging $(TAG) at $$(git rev-parse --short HEAD) and pushing..."
	git tag $(TAG)
	git push origin $(TAG)
	@echo "Pushed $(TAG). release.yaml will move the major alias + create the Release."

check-version:
ifndef V
	$(error V is required, e.g. make release V=1.2.3)
endif
	@[[ "$(V)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$$ ]] || \
		{ echo "V must be semver X.Y.Z (no leading 'v'), got '$(V)'"; exit 1; }

check-clean:
	@[[ -z "$$(git status --porcelain)" ]] || \
		{ echo "Working tree is dirty; commit or stash first."; exit 1; }

check-branch:
	@[[ "$$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || \
		{ echo "Not on main (on '$$(git rev-parse --abbrev-ref HEAD)'). Release from main."; exit 1; }

check-tag:
	@git fetch --tags --quiet
	@! git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null || \
		{ echo "Tag $(TAG) already exists."; exit 1; }
