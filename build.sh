#!/usr/bin/env bash
# Emphere EOL-PHP backport build driver.
# Builds one or more PHP EOL branches with the official CVE-2026-109618 /
# CVE-2026-109619 security commit applied, extracts a redistributable artifact
# bundle, and records checksums. Run from the php-backport/ directory.
#
#   ./build.sh 8.1          # just 8.1
#   ./build.sh all          # 7.4, 8.0, 8.1
set -euo pipefail
cd "$(dirname "$0")"

# branch -> "release_version sha256 patch_file"
declare -A REL=(
  [7.4]="7.4.33 5a2337996f07c8a097e03d46263b5c98d2c8e355227756351421003bea8f463e patches/php-7.4.patch"
  [8.0]="8.0.30 449d2048fcb20a314d8c218097c6d1047a9f1c5bb72aa54d5d3eba0a27a4c80c patches/php-8.0.patch"
  [8.1]="8.1.34 3c5b060ec8e0d5dd1d8237823f3161cc8bc5342aab3c46893eba9857759c4bfa patches/php-8.1.patch"
)

PLATFORM="${PLATFORM:-linux/amd64}"   # production arch; emulated on Apple Silicon
mkdir -p out

build_one() {
  local br="$1"
  read -r ver sha patch <<<"${REL[$br]}"
  local img="emphere/php-backport:${br}"
  echo "=============================================================="
  echo " Building PHP ${ver}  (branch ${br})  platform=${PLATFORM}"
  echo "=============================================================="
  docker build --platform "${PLATFORM}" \
    --build-arg PHP_VERSION="${ver}" \
    --build-arg PHP_SHA256="${sha}" \
    --build-arg PATCH_FILE="${patch}" \
    -t "${img}" .

  # Extract the installed tree + provenance from the image.
  local cid; cid="$(docker create --platform "${PLATFORM}" "${img}")"
  local stage="out/php-${ver}-emphere-backport"
  rm -rf "${stage}"; mkdir -p "${stage}"
  docker cp "${cid}:/opt/php" "${stage}/php" >/dev/null
  docker rm "${cid}" >/dev/null

  # Functional smoke: boot the built PHP, exercise sessions + a real multipart
  # upload, assert it works. Saved into the artifact's provenance dir.
  echo "--- functional smoke ---"
  if docker run --rm --platform "${PLATFORM}" -v "$(pwd)/smoke:/smoke:ro" "${img}" \
       bash /smoke/run.sh > "${stage}/php/emphere/smoke.txt" 2>&1; then
    tail -1 "${stage}/php/emphere/smoke.txt"
  else
    echo "SMOKE FAILED — see ${stage}/php/emphere/smoke.txt"; tail -5 "${stage}/php/emphere/smoke.txt"; exit 1
  fi

  # Redistributable tarball + checksum.
  local tgz="out/php-${ver}-emphere-backport-$(echo "${PLATFORM}" | tr '/' '-').tar.gz"
  tar -C "${stage}" -czf "${tgz}" php
  ( cd out && sha256sum "$(basename "${tgz}")" > "$(basename "${tgz}").sha256" )
  echo "ARTIFACT: ${tgz}"
  echo "VERSION : $(cat "${stage}/php/emphere/php-v.txt" | head -1)"
  echo "TESTS   :"; sed 's/^/           /' "${stage}/php/emphere/test-summary.txt" 2>/dev/null || echo "  (none)"
  echo
}

targets=()
if [[ "${1:-all}" == "all" ]]; then targets=(7.4 8.0 8.1); else targets=("$@"); fi
for t in "${targets[@]}"; do build_one "$t"; done
echo "Done. Artifacts in ./out:"
ls -la out
