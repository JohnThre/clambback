#!/bin/bash

# This file is part of clambback, derived from trojan.
# Clambback is free software distributed under GPLv3-or-later.
# Copyright (C) 2017-2020  The Trojan Authors.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Builds clambback from source on Rocky Linux and installs it as a native
# RPM via dnf, so the prebuilt (Ubuntu-built) release RPM's newer glibc/Boost
# ABI requirements are never an issue.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/JohnThre/clambback/main/scripts/install-rocky.sh | bash
#   ./install-rocky.sh [--skip-tests]
#
# Environment:
#   CLAMBBACK_REF  Git ref/tag to build. Defaults to the latest GitHub release tag.

set -euo pipefail

readonly REPO="JohnThre/clambback"
readonly CFG="/etc/clambback/config.json"

log() {
    printf '[install-rocky] %s\n' "$*"
}

error() {
    printf '[install-rocky] error: %s\n' "$*" >&2
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [--skip-tests]

Builds and installs clambback from the latest GitHub release on Rocky Linux.

  --skip-tests  Skip running the ctest smoke suite before packaging.

Environment:
  CLAMBBACK_REF  Override the git ref/tag to build (default: latest GitHub release tag).
EOF
}

skip_tests=0
for arg in "$@"; do
    case "$arg" in
        --skip-tests)
            skip_tests=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "unknown argument: $arg"
            usage
            exit 1
            ;;
    esac
done

if [[ "$(id -u)" -eq 0 ]]; then
    sudo() { "$@"; }
fi

if [[ ! -r /etc/os-release ]]; then
    error "/etc/os-release not found; cannot verify this is Rocky Linux."
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != "rocky" ]]; then
    error "this script targets Rocky Linux only (detected ID=${ID:-unknown} NAME=${NAME:-unknown})."
    exit 1
fi
log "detected ${PRETTY_NAME:-Rocky Linux}"

if ! command -v dnf >/dev/null 2>&1; then
    error "dnf not found; this script requires Rocky Linux's package manager."
    exit 1
fi

log "installing build and test dependencies..."
sudo dnf install -y \
    gcc-c++ \
    cmake \
    make \
    git \
    boost-devel \
    boost-program-options \
    boost-system \
    openssl-devel \
    openssl \
    rpm-build \
    curl \
    nmap-ncat \
    python3

resolve_ref() {
    if [[ -n "${CLAMBBACK_REF:-}" ]]; then
        printf '%s' "$CLAMBBACK_REF"
        return
    fi
    # Use the releases list, not /releases/latest: that endpoint only returns
    # the newest non-prerelease release and 404s while every published
    # release is a prerelease (e.g. the current -alpha.N series).
    local api="https://api.github.com/repos/${REPO}/releases?per_page=1"
    local body
    if ! body=$(curl -fsSL -H "User-Agent: clambback-install-script" "$api"); then
        error "failed to query $api for the latest release. Set CLAMBBACK_REF=vX.Y.Z and re-run."
        exit 1
    fi
    local tag
    tag=$(printf '%s' "$body" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    if [[ -z "$tag" ]]; then
        error "could not parse latest release tag from the GitHub API response. Set CLAMBBACK_REF=vX.Y.Z and re-run."
        exit 1
    fi
    printf '%s' "$tag"
}

ref="$(resolve_ref)"
log "building clambback ${ref}"

workdir="$(mktemp -d /tmp/clambback-install.XXXXXX)"
cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

src="$workdir/src"
build="$src/build"

git clone --branch "$ref" --depth 1 "https://github.com/${REPO}.git" "$src"

cmake -S "$src" -B "$build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_MYSQL=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc

cmake --build "$build" --parallel "$(nproc)"

if [[ "$skip_tests" -eq 0 ]]; then
    log "running smoke tests..."
    ctest --test-dir "$build" --output-on-failure
else
    log "skipping tests (--skip-tests given)"
fi

log "packaging RPM..."
cpack --config "$build/CPackConfig.cmake" -G RPM

mapfile -t rpm_files < <(find "$build" -maxdepth 1 -name '*.rpm')
if [[ ${#rpm_files[@]} -ne 1 ]]; then
    error "expected exactly one .rpm in $build, found: ${rpm_files[*]:-none}"
    exit 1
fi
rpm_path="${rpm_files[0]}"
log "built $(basename "$rpm_path")"

backup=""
if [[ -f "$CFG" ]]; then
    backup="${CFG}.bak.$(date +%Y%m%d%H%M%S)"
    sudo cp -p "$CFG" "$backup"
    log "existing config found; backed up to $backup"
fi

log "installing via dnf..."
sudo dnf install -y "$rpm_path"

if [[ -n "$backup" ]]; then
    sudo cp -p "$backup" "$CFG"
    log "restored your existing config over the packaged default (backup kept at $backup)"
fi

systemd_unit=""
for candidate in /usr/lib/systemd/system/clambback.service /lib/systemd/system/clambback.service; do
    if [[ -f "$candidate" ]]; then
        systemd_unit="$candidate"
        break
    fi
done

log "clambback installed successfully."
log "binary: $(command -v clambback || echo /usr/bin/clambback)"
log "config: $CFG"
log "next steps:"
log "  1. Edit $CFG (set real ssl.cert/ssl.key paths and password list)"
log "  2. Validate: clambback -t $CFG"
if [[ -n "$systemd_unit" ]]; then
    log "  3. Start: sudo systemctl enable --now clambback"
else
    log "  3. Run: clambback -c $CFG"
fi
