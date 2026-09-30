#!/usr/bin/env bash
# Installs the Godot editor and export templates pinned in tools/toolchain.json
# on a Linux CI runner and puts `godot` on PATH.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
expected="$(jq -r .godot_version "${root}/tools/toolchain.json")"
# 4.7.stable.official.<hash> -> release 4.7-stable, template folder 4.7.stable
template_version="$(cut -d. -f1-3 <<<"${expected}")"
release="${template_version%.*}-${template_version##*.}"
tmp="${RUNNER_TEMP:-$(mktemp -d)}"
url="https://github.com/godotengine/godot/releases/download/${release}"
bin_dir="${tmp}/godot"
template_dir="${HOME}/.local/share/godot/export_templates/${template_version}"

mkdir -p "${bin_dir}" "${template_dir}"
curl --fail --location --retry 3 --silent --show-error -o "${tmp}/godot.zip" "${url}/Godot_v${release}_linux.x86_64.zip"
curl --fail --location --retry 3 --silent --show-error -o "${tmp}/templates.tpz" "${url}/Godot_v${release}_export_templates.tpz"
unzip -q "${tmp}/godot.zip" -d "${bin_dir}"
unzip -q "${tmp}/templates.tpz" -d "${tmp}/templates"
cp -R "${tmp}/templates/templates/." "${template_dir}/"
rm -rf "${tmp}/godot.zip" "${tmp}/templates.tpz" "${tmp}/templates"
mv "${bin_dir}/Godot_v${release}_linux.x86_64" "${bin_dir}/godot"
chmod +x "${bin_dir}/godot"

actual="$("${bin_dir}/godot" --version)"
if [ "${actual}" != "${expected}" ]; then
  echo "Engine mismatch: expected ${expected}, got ${actual}" >&2
  exit 1
fi
if [ -n "${GITHUB_PATH:-}" ]; then echo "${bin_dir}" >> "${GITHUB_PATH}"; fi
echo "Installed Godot ${actual}"
