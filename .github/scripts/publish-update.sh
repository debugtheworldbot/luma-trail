#!/bin/bash
set -euo pipefail
: "${GH_REPO:?}" "${GITHUB_SHA:?}" "${RELEASE_TAG:?}"

# A queued old commit may finish after a newer push. Never promote it.
tip=$(gh api "repos/${GH_REPO}/commits/main" --jq .sha)
if [[ "$tip" != "$GITHUB_SHA" ]]; then
  echo "Skipping update promotion: this commit is no longer main's tip."
  exit 0
fi

feed=$(mktemp -d)
gh release download "$RELEASE_TAG" --pattern appcast.xml --dir "$feed"
if gh release view updates >/dev/null 2>&1; then
  gh release upload updates "$feed/appcast.xml" --clobber
else
  gh release create updates "$feed/appcast.xml" --target "$GITHUB_SHA" \
    --title "Luma Trail Update Feed" --latest=false \
    --notes "Stable Sparkle update feed. Download the application from the latest version release."
fi
gh release edit "$RELEASE_TAG" --latest
echo "Published in-app update from ${RELEASE_TAG}"
