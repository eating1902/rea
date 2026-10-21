#!/usr/bin/env bash
# Explicit opt-in provisioning for the eating1902/rea Codex Cloud environment.
set -euo pipefail
umask 022

mode=${1:-install}
case "$mode" in
  install|--check) ;;
  *) echo 'Usage: bash scripts/cloud/setup.sh [--check]' >&2; exit 2 ;;
esac
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
tools=/workspace/rea-tools
toolchain=/workspace/rea-toolchain
jdk_root=jdk-21.0.12.1+1
ghidra_root=ghidra_12.1.4_PUBLIC
export npm_config_cache=/workspace/.npm-cache
export HUSKY=0
export JAVA_HOME="$tools/$jdk_root"
export GHIDRA_INSTALL_DIR="$tools/$ghidra_root"
export PATH="$toolchain/node_modules/.bin:$JAVA_HOME/bin:$PATH"

fail() { echo "REA cloud setup: $*" >&2; exit 1; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] ||
  fail 'Linux x86_64 is required.'
command -v python3 >/dev/null || fail 'python3 is required.'
python3 - "$repo/package.json" <<'PY'
import json, sys
if json.load(open(sys.argv[1]))['version'] != '6.7.0':
    raise SystemExit('This setup is pinned to REA 6.7.0; review before updating.')
PY

toolchain_ready() {
  [[ -x "$toolchain/node_modules/.bin/node" &&
     -x "$toolchain/node_modules/.bin/npm" ]] &&
    [[ $("$toolchain/node_modules/.bin/node" --version) == v24.18.0 ]] &&
    [[ $("$toolchain/node_modules/.bin/npm" --version) == 11.16.0 ]]
}

# Reuse only versioned installations with the tested archive provenance marker.
# An unknown existing directory is never replaced automatically.
install_archive() {
  local url=$1 hash=$2 format=$3 root=$4
  local destination="$tools/$root"
  if [[ -e "$destination" || -L "$destination" ]]; then
    [[ ! -L "$destination" && -f "$destination/.rea-archive-sha256" ]] &&
      [[ $(cat "$destination/.rea-archive-sha256") == "$hash" ]] ||
      fail "Inspect existing installation: $destination"
    echo "Using existing $root"
    return
  fi
  [[ "$mode" != --check ]] || fail "Missing installation: $destination"
  (
    set -euo pipefail
    stage=$(mktemp -d "$tools/.install.XXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    curl --fail --location --silent --show-error --retry 3 \
      --connect-timeout 20 --max-time 900 \
      --proto '=https' --proto-redir '=https' \
      "$url" -o "$stage/archive"
    printf '%s  %s\n' "$hash" "$stage/archive" | sha256sum --check --strict
    if [[ "$format" == tar ]]; then
      tar --no-same-owner -xzf "$stage/archive" -C "$stage"
    else
      unzip -q "$stage/archive" -d "$stage"
    fi
    test -d "$stage/$root"
    printf '%s\n' "$hash" > "$stage/$root/.rea-archive-sha256"
    mv -T -- "$stage/$root" "$destination"
  )
}

echo "REA cloud setup started: $(date -u +%FT%TZ); mode=$mode"
if ! toolchain_ready; then
  [[ "$mode" != --check ]] || fail 'Pinned Node/npm toolchain is missing.'
  command -v npm >/dev/null || fail 'Bootstrap npm is required.'
  npm install --prefix "$toolchain" --no-audit --no-fund \
    node@24.18.0 npm@11.16.0
  toolchain_ready || fail 'Node/npm version check failed.'
fi

if [[ "$mode" != --check ]]; then
  for cmd in curl sha256sum tar unzip; do
    command -v "$cmd" >/dev/null || fail "Missing prerequisite: $cmd"
  done
  mkdir -p "$tools"
fi

install_archive \
  'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz' \
  ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94 \
  tar "$jdk_root"
install_archive \
  'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip' \
  ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db \
  zip "$ghidra_root"

if [[ "$mode" != --check ]]; then
  [[ ! -L "$tools/env.sh" ]] || fail 'Refusing to replace an env.sh symlink.'
  (
    staged_env=$(mktemp "$tools/.env.XXXXXX")
    trap 'rm -f -- "$staged_env"' EXIT
    cat > "$staged_env" <<'ENV'
export JAVA_HOME='/workspace/rea-tools/jdk-21.0.12.1+1'
export GHIDRA_INSTALL_DIR='/workspace/rea-tools/ghidra_12.1.4_PUBLIC'
export PATH="/workspace/rea-toolchain/node_modules/.bin:$JAVA_HOME/bin:$PATH"
export npm_config_cache=/workspace/.npm-cache
export HUSKY=0
ENV
    if ! cmp -s "$staged_env" "$tools/env.sh"; then
      if [[ -e "$tools/env.sh" ]]; then
        backup=$(mktemp "$tools/env.sh.backup.XXXXXX")
        cp -p -- "$tools/env.sh" "$backup"
      fi
      chmod 644 "$staged_env"
      mv -- "$staged_env" "$tools/env.sh"
    fi
  )
fi

cd "$repo"
if ! node scripts/check-dependency-install.mjs; then
  [[ "$mode" != --check ]] || fail 'Locked REA dependencies are missing.'
  npm ci --no-audit --no-fund
fi
if [[ ! -f dist/main.js ]]; then
  [[ "$mode" != --check ]] || fail 'REA runtime has not been built.'
  npm run build:cached
fi
[[ $(node scripts/rea.mjs --version) == 6.7.0 ]] || fail 'REA version mismatch.'
"$JAVA_HOME/bin/java" -version
"$JAVA_HOME/bin/javac" -version
diagnosis=$(node scripts/rea.mjs doctor --provider ghidra --json)
printf '%s\n' "$diagnosis"
printf '%s\n' "$diagnosis" | python3 -c \
  'import json,sys; sys.exit(0 if json.load(sys.stdin).get("healthy") is True else 1)'
echo "REA cloud setup passed: $(date -u +%FT%TZ)"
