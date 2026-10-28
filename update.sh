#!/usr/bin/env bash
#
# Update every package manager present on this machine in one go:
# apt / pacman / Homebrew, flatpak, uv tools, rustup, and a firmware check.
#
# Anything not installed is skipped. Sudo is asked for once up front (only if
# a step needs it) and kept alive until the script exits. A failing step is
# reported but doesn't stop the rest.
#
# Written against bash 3.2 so it runs under macOS's stock /bin/bash.

set -uo pipefail

if [ -t 1 ]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[0;34m'
    C_OFF=$'\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_OFF=''
fi

log_step()    { printf '\n%s==>%s %s\n'  "$C_BLUE"   "$C_OFF" "$1"; }
log_success() { printf '%s[OK]%s %s\n'   "$C_GREEN"  "$C_OFF" "$1"; }
log_skip()    { printf '%s[SKIP]%s %s\n' "$C_YELLOW" "$C_OFF" "$1"; }
log_error()   { printf '%s[FAIL]%s %s\n' "$C_RED"    "$C_OFF" "$1" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

if [ "$(id -u)" -eq 0 ]; then
    log_error "Run this as your user, not root; it calls sudo where needed."
    exit 1
fi

# ----------------------------------------------------------------- steps ---

update_apt() {
    sudo apt-get update \
        && sudo apt-get upgrade -y \
        && sudo apt-get autoremove -y
}

update_pacman() {
    sudo pacman -Syu --noconfirm
}

update_brew() {
    # Homebrew refuses to run as root.
    brew update && brew upgrade
}

flatpak_has_remotes() {
    [ -n "$(flatpak remotes "--$1" --columns=name 2>/dev/null)" ]
}

update_flatpak() {
    # System installation needs root; the per-user one must not use it.
    if flatpak_has_remotes system; then
        sudo flatpak update -y --system --noninteractive || return 1
    fi
    if flatpak_has_remotes user; then
        flatpak update -y --user --noninteractive || return 1
    fi
}

update_uv_tools() {
    uv tool upgrade --all
}

update_rustup() {
    rustup update
}

# List-only: firmware updates often need a reboot, so apply them deliberately
# with `fwupdmgr update`. Exit code 2 means "nothing to do".
check_firmware() {
    local rc=0
    sudo fwupdmgr refresh --assume-yes >/dev/null 2>&1 || rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
        echo "fwupdmgr refresh failed (exit $rc); checking with cached metadata."
    fi
    rc=0
    fwupdmgr get-updates --no-unreported-check --no-metadata-check || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "No firmware updates available."
        return 0
    fi
    [ "$rc" -eq 0 ] && echo "Run 'fwupdmgr update' to install these."
    return "$rc"
}

# ------------------------------------------------------------------ plan ---

# Each entry is "label:function". Built first so we know whether sudo is needed.
STEPS=()
NEEDS_SUDO=0

if has apt-get; then
    STEPS+=("apt:update_apt"); NEEDS_SUDO=1
elif has pacman; then
    STEPS+=("pacman:update_pacman"); NEEDS_SUDO=1
fi
if has brew; then
    STEPS+=("brew:update_brew")
fi
if has flatpak; then
    STEPS+=("flatpak:update_flatpak")
    flatpak_has_remotes system && NEEDS_SUDO=1
fi
if has uv; then
    STEPS+=("uv tools:update_uv_tools")
fi
if has rustup; then
    STEPS+=("rustup:update_rustup")
fi
if has fwupdmgr; then
    STEPS+=("firmware (check only):check_firmware"); NEEDS_SUDO=1
fi

if [ "${#STEPS[@]}" -eq 0 ]; then
    log_skip "No supported package managers found."
    exit 0
fi

# ------------------------------------------------------------------- run ---

if [ "$NEEDS_SUDO" -eq 1 ]; then
    if ! has sudo; then
        log_error "sudo is required for some steps but isn't installed."
        exit 1
    fi
    # One password prompt, then refresh the timestamp in the background so
    # long upgrades don't make sudo ask again.
    sudo -v || exit 1
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    KEEPALIVE_PID=$!
    trap 'kill "$KEEPALIVE_PID" 2>/dev/null' EXIT
fi

FAILED=()

for step in "${STEPS[@]}"; do
    name="${step%%:*}"
    func="${step#*:}"
    log_step "$name"
    if "$func"; then
        log_success "$name"
    else
        log_error "$name"
        FAILED+=("$name")
    fi
done

echo
if [ "${#FAILED[@]}" -eq 0 ]; then
    log_success "Everything is up to date."
else
    log_error "Failed: $(printf '%s, ' "${FAILED[@]}" | sed 's/, $//')"
    exit 1
fi
