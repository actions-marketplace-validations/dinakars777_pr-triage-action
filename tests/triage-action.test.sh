#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"

cat > "$TMP_DIR/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2" == "pr view" ]]; then
  cat <<'JSON'
{"number":1,"title":"Fix parser","state":"OPEN","author":{"login":"alice"},"createdAt":"2026-05-01T00:00:00Z","updatedAt":"2026-05-01T00:00:00Z","baseRefName":"main","headRefName":"fix/parser","isDraft":false,"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","labels":[],"reviewDecision":"","reviewRequests":[],"additions":10,"deletions":2,"changedFiles":1,"body":"Fix bug","url":"https://example.test/pr/1","milestone":null,"assignees":[]}
JSON
elif [[ "$1" == "api" && "$2" == "repos/o/r/pulls/1/files" ]]; then
  printf 'src/a.js\n'
elif [[ "$1 $2" == "pr list" && "$*" == *"--state open"* && "$*" != *"--author"* ]]; then
  cat <<'JSON'
{"number":2,"title":"Similar parser fix","author":{"login":"bob"},"headRefName":"fix/other-parser"}
JSON
elif [[ "$1" == "api" && "$2" == "repos/o/r/pulls/2/files" ]]; then
  if [[ "${FAKE_SCENARIO}" == "exact-overlap" ]]; then
    printf 'src/a.js\n'
  else
    printf 'src/a.js.bak\n'
  fi
elif [[ "$1" == "api" && "$2" == "repos/o/r/issues/1/comments" ]]; then
  true
elif [[ "$1 $2" == "pr comment" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--body" ]]; then
      shift
      printf '%s' "$1" > "$OUT_COMMENT"
      exit 0
    fi
    shift
  done
  echo "missing --body" >&2
  exit 2
else
  echo "unexpected gh call: $*" >&2
  exit 2
fi
FAKE_GH
chmod +x "$TMP_DIR/bin/gh"

run_triage() {
  local scenario="$1"
  local comment_file="$TMP_DIR/${scenario}.md"

  FAKE_SCENARIO="$scenario" \
    OUT_COMMENT="$comment_file" \
    PATH="$TMP_DIR/bin:$PATH" \
    GH_TOKEN="test-token" \
    PR_NUMBER="1" \
    REPO="o/r" \
    ENABLE_LABELS="false" \
    ENABLE_CONTRIBUTOR_PROFILE="false" \
    bash "$ROOT_DIR/scripts/triage-action.sh" > "$TMP_DIR/${scenario}.log"

  printf '%s' "$comment_file"
}

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "Expected $file to contain: $expected" >&2
    echo "--- comment ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    echo "Expected $file not to contain: $unexpected" >&2
    echo "--- comment ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

comment_file="$(run_triage exact-overlap)"
assert_contains "$comment_file" "### 🔍 Potential Duplicates"
assert_contains "$comment_file" "| #2 | Similar parser fix | @bob | 100% | high |"

comment_file="$(run_triage prefix-only)"
assert_not_contains "$comment_file" "### 🔍 Potential Duplicates"

echo "triage-action tests passed"
