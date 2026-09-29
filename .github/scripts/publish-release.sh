#!/bin/bash
# Publish dist/Luma-Trail-MVP.zip as a GitHub Release for this commit.
# Run from the repository root after build.sh. GitHub Actions provides
# GH_TOKEN, GH_REPO, GITHUB_SHA, and GITHUB_REPOSITORY.
set -euo pipefail

plist="dist/Luma Trail.app/Contents/Info.plist"
version=$(plutil -extract CFBundleShortVersionString raw "$plist")
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
echo "tag=$tag" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# Published version archives are immutable; retries reuse the existing release.
if gh release view "$tag" >/dev/null 2>&1; then
  gh release download "$tag" --pattern appcast.xml --dir "$(mktemp -d)"
  echo "Reusing published ${tag}"
  exit 0
fi

if [[ ! -f "$src" ]]; then
  echo "Missing ${src}. Run build.sh first." >&2
  exit 1
fi

cp "$src" "$asset"
updates=$(mktemp -d)
cp "$asset" "$updates/Luma-Trail-arm64.zip"
sparkle=$(bash scripts/prepare-sparkle.sh)
printf '%s' "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}" | \
  "$sparkle/bin/generate_appcast" --ed-key-file - --maximum-deltas 0 \
    --download-url-prefix "https://github.com/${GITHUB_REPOSITORY}/releases/download/${tag}/" "$updates"
cp "$updates/appcast.xml" dist/appcast.xml
xcrun swift -module-cache-path .build/swift-module-cache scripts/verify-appcast.swift \
  dist/appcast.xml "$asset" "$plist" "https://github.com/${GITHUB_REPOSITORY}/releases/download/${tag}/Luma-Trail-arm64.zip"
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

gh release create "$tag" "$asset" dist/appcast.xml \
    --target "$GITHUB_SHA" \
    --title "$title" \
    --latest=false \
    --notes-file "$notes"

echo "Published ${tag}"
