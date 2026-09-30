#!/usr/bin/env bash
# The repository only carries the Web and Windows Sentry binaries. A Linux CI
# editor needs the Linux library too, or the SDK's scripts fail to parse and
# its export plugin cannot add sentry-bundle.js to the Web page.
# Downloads the Linux x86_64 library from the matching sentry-godot release
# into addons/sentry/bin/linux (git-ignored). Requires gh with GH_TOKEN.
set -euo pipefail

version="2.1.1"
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

gh release download "${version}" --repo getsentry/sentry-godot --dir "${tmp}" \
  --pattern "sentry-godot-${version}?*.zip"
archive="$(ls "${tmp}"/sentry-godot-"${version}"*.zip | grep -v -e demo-project -e debug-symbols)"
unzip -q "${archive}" 'addons/sentry/bin/linux/x86_64/*' 'addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll' -d "${tmp}/pkg"

# Guard against a version drift between the committed SDK and this download.
if ! cmp -s "${tmp}/pkg/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" \
  "${root}/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll"; then
  echo "sentry-godot ${version} does not match the committed addon; update the version here" >&2
  exit 1
fi
mkdir -p "${root}/addons/sentry/bin/linux"
cp -R "${tmp}/pkg/addons/sentry/bin/linux/x86_64" "${root}/addons/sentry/bin/linux/"
echo "Installed sentry-godot ${version} Linux library"
