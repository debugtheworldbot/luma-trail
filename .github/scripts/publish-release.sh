#!/bin/bash
# Publish dist/Luma-Trail-MVP.zip as a GitHub Release for this commit.
# Run from the repository root after build.sh. GitHub Actions provides
# GH_TOKEN, GH_REPO, GITHUB_SHA, and GITHUB_REPOSITORY.
set -euo pipefail

version=$(plutil -extract CFBundleShortVersionString raw Info.plist)
if [[ ! "$version" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
  echo "CFBundleShortVersionString cannot be used in a release tag: ${version}" >&2
  exit 1
fi

if [[ ! "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ && ! "${GITHUB_SHA:-}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "GITHUB_SHA must be the full commit sha" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

short=${GITHUB_SHA:0:7}
tag="v${version}-${short}"
src="dist/Luma-Trail-MVP.zip"
asset="dist/Luma-Trail-arm64.zip"

if [[ ! -f "$src" ]]; then
  echo "Missing ${src}. Run build.sh first." >&2
  exit 1
fi

cp "$src" "$asset"
checksum=$(shasum -a 256 "$asset" | awk '{print $1}')
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT

cat > "$notes" <<EOF
Apple Silicon（arm64）构建，适用于 macOS 13 及更新系统。

解压后打开 Luma Trail.app。此包为 ad-hoc 签名，未经 Developer ID 公证。若系统拦截，请在 Finder 中按住 Control 点按应用，选择「打开」。

- 版本：${version}
- 提交：${GITHUB_SHA}
- SHA-256：${checksum}
EOF

title="Luma Trail ${version} (${short})"

if gh release view "$tag" >/dev/null 2>&1; then
  gh release upload "$tag" "$asset" --clobber
  gh release edit "$tag" --title "$title" --notes-file "$notes" --draft=false
else
  gh release create "$tag" "$asset" \
    --target "$GITHUB_SHA" \
    --title "$title" \
    --latest=false \
    --notes-file "$notes"
fi

tip=$(gh api "repos/${GITHUB_REPOSITORY}/commits/main" --jq .sha)
if [[ "$tip" == "$GITHUB_SHA" ]]; then
  gh release edit "$tag" --latest
fi

echo "Published ${tag}"
