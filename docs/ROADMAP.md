# PR Triage Action Roadmap

Last reviewed: 2026-05-23

## Current State

This repository provides a composite GitHub Action that runs `scripts/triage-action.sh` on pull requests, classifies the PR, assesses risk, checks for overlapping open PRs, profiles the contributor, applies labels, and posts or updates a triage comment.

Recent maintenance completed:

- Fixed duplicate detection so matches collected inside the open-PR loop are included in the final comment.
- Made duplicate file matching exact by path, avoiding prefix-only false positives.
- Added a local fake-`gh` regression test for duplicate reporting.
- Updated repository references from the old `openclaw-triage-action` name to `pr-triage-action`.
- Changed this repository's active PR workflow to check out and run the local action under test.

No open GitHub issues or PRs were present at the time of this review.

## Near-Term Priorities

### 1. Add a Dedicated Validation Workflow

The current PR workflow exercises the action by triaging the PR, but it does not run the local regression suite directly.

Add a separate validation workflow that runs:

```bash
bash -n scripts/triage-action.sh tests/triage-action.test.sh scripts/auth-validator.sh scripts/weekly-digest.sh
tests/triage-action.test.sh
```

If `shellcheck` is available in CI, add it as a non-optional check for every script.

### 2. Validate Inputs Before Running Triage

`duplicate-threshold` and boolean flags are user inputs. Normalize and validate them before any API work:

- Accept only integer thresholds from 0 to 100.
- Normalize booleans case-insensitively.
- Fail fast with a clear `::error::` message for invalid values.

This prevents arithmetic failures and makes workflow misconfiguration easier to diagnose.

### 3. Add Dependency Preflight Checks

The action depends on `gh` and `jq`. Add explicit `command -v` checks near startup so missing runner dependencies produce clear errors instead of later partial failures.

### 4. Expand Regression Coverage

Grow the fake-`gh` test harness around the highest-risk behavior:

- PR type classification for docs, CI, deps, tests, features, fixes, and refactors.
- Risk escalation for security-sensitive paths, CI edits, and large changes.
- Comment update behavior when an existing triage comment is present.
- Label creation and application behavior.
- Contributor tiering for first-time, regular, trusted, and low-merge-rate contributors.

## Product Improvements

### Duplicate Detection

- Compare more than the latest 30 open PRs when repositories have very large queues.
- Add optional title/body similarity signals alongside file overlap.
- Show why a duplicate was flagged, including the overlapping file list capped to a readable length.

### Reviewer Guidance

- Use `CODEOWNERS` or file-pattern configuration to suggest reviewer teams.
- Add optional labels for review lane, such as `review:security`, `review:docs`, or `review:ci`.
- Detect draft-to-ready transitions in addition to opened/reopened/synchronize events.

### Label Management

- Avoid resetting existing label colors on every run.
- Let users configure label prefixes and colors.
- Add a dry-run mode that comments suggested labels without applying them.

### Weekly Digest

`scripts/weekly-digest.sh` exists but is not wired into `action.yml` or documented as a supported workflow. Either promote it into a documented second workflow or move it out of the default action surface until it has tests and a clear entry point.

## Release And Packaging

- Add a `LICENSE` file.
- Add a changelog.
- Publish versioned tags such as `v1`, instead of asking users to pin `@main`.
- Document the minimum permissions needed for comments, labels, and duplicate checks.
- Add a short security note: use `pull_request`, avoid `pull_request_target` for untrusted action code, and keep token permissions minimal.

## Suggested Sequence

1. Validation workflow plus shell syntax checks.
2. Input validation and dependency preflight.
3. Expanded fake-`gh` coverage for classification, risk, labels, and comments.
4. Label-management cleanup.
5. Versioned release/tagging and marketplace readiness.
6. Duplicate-detection depth and reviewer-routing features.
