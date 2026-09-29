#!/bin/bash
# Pin both the official binary release and its checksum.
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
root="$PWD/.build/sparkle"
archive="$root/Sparkle-${version}.tar.xz"
mkdir -p "$root"
if [[ ! -f "$archive" ]]; then
  curl -fL --retry 3 "https://github.com/sparkle-project/Sparkle/releases/download/${version}/Sparkle-${version}.tar.xz" -o "$archive"
fi
echo "$checksum  $archive" | shasum -a 256 --check >&2
mkdir -p "$root/$version"
tar -xJf "$archive" -C "$root/$version"
echo "$root/$version"
