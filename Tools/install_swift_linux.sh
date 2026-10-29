#!/usr/bin/env bash
# Installs a Swift toolchain in a Linux (Ubuntu 24.04) cloud session.
#
# download.swift.org is blocked by the cloud session's network policy, so this
# script unpacks the official `swift:<tag>-noble` Docker image straight from a
# registry API (no Docker daemon needed): Google's Docker Hub mirror
# (mirror.gcr.io) first, because the shared egress IP often exhausts Docker
# Hub's anonymous rate limit, then Docker Hub itself. The image is built on
# Ubuntu 24.04, so its binaries match the host's system libraries.
#
# Usage: bash Tools/install_swift_linux.sh            (default tag 6.2-noble)
#        SWIFT_TAG=6.1-noble bash Tools/install_swift_linux.sh
# Then:  export PATH=/opt/swift-image/usr/bin:$PATH
set -euo pipefail

TAG="${SWIFT_TAG:-6.2-noble}"
DEST="${SWIFT_DEST:-/opt/swift-image}"
REPO="library/swift"

if [ -x "$DEST/usr/bin/swift" ]; then
  echo "Swift already unpacked at $DEST"
  "$DEST/usr/bin/swift" --version
  exit 0
fi

echo "==> Installing Swift's system dependencies (apt)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev \
  libncurses-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev \
  libz3-dev pkg-config tzdata unzip zlib1g-dev >/dev/null

json() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

ACCEPT_INDEX=(-H 'Accept: application/vnd.oci.image.index.v1+json'
              -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json')
ACCEPT_MANIFEST=(-H 'Accept: application/vnd.oci.image.manifest.v1+json'
                 -H 'Accept: application/vnd.docker.distribution.manifest.v2+json')

INDEX=""
for REGISTRY in "https://mirror.gcr.io/v2/$REPO" "https://registry-1.docker.io/v2/$REPO"; do
  AUTH=()
  if [[ "$REGISTRY" == *docker.io* ]]; then
    TOKEN=$(curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$REPO:pull" | json 'd["token"]')
    AUTH=(-H "Authorization: Bearer $TOKEN")
  fi
  echo "==> Resolving $REPO:$TAG for linux/amd64 from ${REGISTRY%/v2/*}"
  if INDEX=$(curl -fsSL "${AUTH[@]}" "${ACCEPT_INDEX[@]}" "$REGISTRY/manifests/$TAG"); then
    break
  fi
  INDEX=""
done
[ -n "$INDEX" ] || { echo "Could not reach any registry for $REPO:$TAG" >&2; exit 1; }

DIGEST=$(echo "$INDEX" | json '[m["digest"] for m in d["manifests"] if m.get("platform",{}).get("architecture")=="amd64" and m["platform"].get("os")=="linux"][0]')
MANIFEST=$(curl -fsSL "${AUTH[@]}" "${ACCEPT_MANIFEST[@]}" "$REGISTRY/manifests/$DIGEST")
LAYERS=$(echo "$MANIFEST" | json '"\n".join(l["digest"] for l in d["layers"])')

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DEST"
for L in $LAYERS; do
  echo "==> Layer $L"
  curl -fsSL "${AUTH[@]}" -o "$WORK/layer" "$REGISTRY/blobs/$L"
  echo "${L#sha256:}  $WORK/layer" | sha256sum -c --quiet -
  # Image layers are gzip tarballs; skip device nodes and ownership we can't set.
  tar -xzf "$WORK/layer" -C "$DEST" --no-same-owner --exclude='dev/*' 2>/dev/null || \
    tar -xzf "$WORK/layer" -C "$DEST" --no-same-owner --exclude='dev/*'
  rm -f "$WORK/layer"
done

echo "==> Done"
"$DEST/usr/bin/swift" --version
echo "Add to PATH: export PATH=$DEST/usr/bin:\$PATH"
