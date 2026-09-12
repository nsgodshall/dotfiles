#!/usr/bin/env bash
#
# Dotfiles bootstrap.
#
# Idempotent: safe to run repeatedly.
# Supports Debian/Ubuntu (apt), Arch (pacman) and macOS (Homebrew).
#
# Written against bash 3.2 so it runs under macOS's stock /bin/bash:
# no ${var,,}, no associative arrays, no mapfile.

set -euo pipefail

# --------------------------------------------------------------- logging ---

if [ -t 1 ]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[0;34m'
    C_OFF=$'\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_OFF=''
fi

WARN_COUNT=0

log_info()    { printf '%s[INFO]%s %s\n'    "$C_BLUE"  "$C_OFF" "$1"; }
log_success() { printf '%s[SUCCESS]%s %s\n' "$C_GREEN" "$C_OFF" "$1"; }
log_error()   { printf '%s[ERROR]%s %s\n'   "$C_RED"   "$C_OFF" "$1" >&2; }
log_warning() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '%s[WARNING]%s %s\n' "$C_YELLOW" "$C_OFF" "$1"
}

# -------------------------------------------------------------- platform ---

OS_NAME=$(uname -s)
ARCH_NAME=$(uname -m)

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$DOTFILES_DIR/zshrc" ] || [ ! -f "$DOTFILES_DIR/p10k.zsh" ]; then
    log_error "Could not find dotfiles in $DOTFILES_DIR"
    log_error "Please run this script from the dotfiles directory"
    exit 1
fi

# Captured before we prepend, so the shadow check below can reason about the
# PATH the user actually has rather than the one we just doctored.
ORIGINAL_PATH="$PATH"

# Locally installed tools must be visible to the checks below.
export PATH="$HOME/.local/bin:$PATH"

# Homebrew is not on PATH until a shell profile runs `brew shellenv`, which is
# exactly what has not happened yet on a fresh machine. Find it ourselves.
if [ "$OS_NAME" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
    for brew_candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew_candidate" ]; then
            eval "$("$brew_candidate" shellenv)"
            break
        fi
    done
fi

# `readlink -f` does not exist on BSD/macOS before Monterey; do it by hand.
resolve_path() {
    local target="$1"
    [ -e "$target" ] || [ -L "$target" ] || return 1
    (
        local hops=0 link
        while [ -L "$target" ]; do
            hops=$((hops + 1))
            [ "$hops" -gt 40 ] && return 1
            link=$(readlink "$target")
            case "$link" in
                /*) target="$link" ;;
                *)  target="$(dirname "$target")/$link" ;;
            esac
        done
        if [ -d "$target" ]; then
            cd "$target" && pwd -P
        else
            cd "$(dirname "$target")" \
                && printf '%s/%s\n' "$(pwd -P)" "$(basename "$target")"
        fi
    )
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ------------------------------------------------------- package manager ---

detect_package_manager() {
    if [ "$OS_NAME" = "Darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            echo "brew"
            return 0
        fi
        return 1
    fi
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
        return 0
    fi
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
        return 0
    fi
    return 1
}

install_hint() {
    case "$(detect_package_manager 2>/dev/null || echo none)" in
        apt)    echo "sudo apt-get install <package>" ;;
        pacman) echo "sudo pacman -S <package>" ;;
        brew)   echo "brew install <package>" ;;
        *)      echo "your system package manager" ;;
    esac
}

have_c_compiler() {
    command -v cc >/dev/null 2>&1 \
        || command -v gcc >/dev/null 2>&1 \
        || command -v clang >/dev/null 2>&1
}

# macOS needs the Command Line Tools for git and a C compiler; Homebrew
# depends on them too. Check early so the failure is legible.
check_macos_toolchain() {
    [ "$OS_NAME" = "Darwin" ] || return 0

    if ! xcode-select -p >/dev/null 2>&1; then
        log_error "Xcode Command Line Tools are not installed."
        log_error "Run: xcode-select --install"
        log_error "Then re-run this script."
        exit 1
    fi

    if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew was not found, and it is required on macOS."
        log_error "Install it from https://brew.sh, then re-run this script:"
        log_error '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
}

# Install packages one at a time on failure, so a single unavailable package
# never aborts the whole bootstrap.
apt_install() {
    log_info "Installing packages via apt-get..."
    sudo apt-get update -y \
        || log_warning "apt-get update failed; continuing with cached package lists"

    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends "$@"; then
        return 0
    fi

    log_warning "Bulk install failed; retrying one package at a time"
    local pkg
    for pkg in "$@"; do
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            --no-install-recommends "$pkg" \
            || log_warning "Could not install package: $pkg"
    done
}

pacman_install() {
    log_info "Installing packages via pacman..."
    if sudo pacman -Sy --needed --noconfirm "$@"; then
        return 0
    fi

    log_warning "Bulk install failed; retrying one package at a time"
    local pkg
    for pkg in "$@"; do
        sudo pacman -S --needed --noconfirm "$pkg" \
            || log_warning "Could not install package: $pkg"
    done
}

brew_install() {
    local pkg missing=""
    for pkg in "$@"; do
        if ! brew list --formula "$pkg" >/dev/null 2>&1; then
            missing="$missing $pkg"
        fi
    done

    if [ -z "$missing" ]; then
        log_info "All Homebrew packages already installed"
        return 0
    fi

    log_info "Installing packages via Homebrew:$missing"
    for pkg in $missing; do
        brew install "$pkg" || log_warning "Could not install package: $pkg"
    done
}

install_system_packages() {
    local manager
    if ! manager=$(detect_package_manager); then
        log_warning "No supported package manager found (apt, pacman or brew)."
        log_warning "Install git, zsh, neovim and a C compiler manually."
        return 0
    fi

    if [ "$manager" != "brew" ] && ! command -v sudo >/dev/null 2>&1; then
        log_warning "sudo is not available; skipping automatic package installation."
        log_warning "Ensure git, zsh, neovim and a C compiler are installed."
        return 0
    fi

    case "$manager" in
        apt)
            # NOTE: the runtime library is libpcre2-8-0. "libpcre2-8" does not
            # exist in Debian/Ubuntu and used to abort this script on line one.
            # No neovim here on purpose: Debian ships 0.10.x, which this
            # config cannot run (it needs 0.11+), and /usr/bin/nvim then
            # shadows the current build we fetch below in any shell that
            # does not put ~/.local/bin first.
            apt_install git zsh tmux curl wget ripgrep unzip tar \
                fontconfig fzf gcc libpcre2-8-0 flatpak
            ;;
        pacman)
            pacman_install git zsh tmux curl wget ripgrep unzip tar neovim \
                fontconfig fzf gcc pcre2 flatpak
            ;;
        brew)
            # unzip and tar ship with macOS; fontconfig is not used there.
            # Compilers come from the Command Line Tools, not a gcc formula.
            # flatpak is Linux-only (bubblewrap/namespaces), so it is absent.
            brew_install git zsh tmux curl wget ripgrep neovim fzf pcre2
            ;;
    esac

    hash -r 2>/dev/null || true
    log_success "Base packages installed"
}

# --------------------------------------------------------------- neovim ---

# Asset base name for the current platform, or non-zero if unsupported.
nvim_release_target() {
    case "$OS_NAME/$ARCH_NAME" in
        Linux/x86_64|Linux/amd64)   echo "nvim-linux-x86_64" ;;
        Linux/aarch64|Linux/arm64)  echo "nvim-linux-arm64" ;;
        *) return 1 ;;
    esac
}

# Distro packages lag well behind what Kickstart wants, so pull the current
# release on Linux. On macOS, Homebrew's neovim is already current.
# The tag that releases/latest redirects to, e.g. "v0.12.5".
latest_neovim_tag() {
    curl -fsSLI -o /dev/null -w '%{url_effective}' \
        https://github.com/neovim/neovim/releases/latest 2>/dev/null \
        | sed -n 's|.*/tag/||p'
}

install_latest_neovim_release() {
    if [ "$OS_NAME" = "Darwin" ]; then
        log_info "Using Homebrew's neovim on macOS (already current)."
        return 0
    fi

    local target
    if ! target=$(nvim_release_target); then
        log_warning "No prebuilt Neovim release for $OS_NAME/$ARCH_NAME; using the packaged version."
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
        log_warning "curl or tar missing; cannot install the latest Neovim release."
        return 0
    fi

    local tmp_dir archive download_url install_dir bin_dir extracted top_dir
    local latest_tag installed_version
    # Upstream renamed these assets: nvim-linux64.tar.gz is gone and 404s.
    download_url="https://github.com/neovim/neovim/releases/latest/download/${target}.tar.gz"
    install_dir="$HOME/.local/neovim"
    bin_dir="$HOME/.local/bin"

    # Re-running this script should not re-download 40MB every time.
    latest_tag=$(latest_neovim_tag) || true
    if [ -n "${latest_tag:-}" ] && [ -x "$install_dir/bin/nvim" ]; then
        installed_version=$("$install_dir/bin/nvim" --version 2>/dev/null | head -1) || true
        case "${installed_version:-}" in
            *"$latest_tag"*)
                log_info "Neovim $latest_tag already installed; skipping download."
                mkdir -p "$bin_dir"
                ln -sf "$install_dir/bin/nvim" "$bin_dir/nvim"
                return 0
                ;;
        esac
    fi

    tmp_dir=$(mktemp -d)
    archive="$tmp_dir/nvim.tar.gz"

    log_info "Downloading latest Neovim release ($target)..."
    if ! curl -fsSL "$download_url" -o "$archive"; then
        log_warning "Failed to download Neovim from $download_url"
        rm -rf "$tmp_dir"
        return 0
    fi

    log_info "Extracting Neovim to $install_dir..."
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        log_warning "Failed to extract the Neovim archive."
        rm -rf "$tmp_dir"
        return 0
    fi

    # Read the top-level directory out of the archive rather than assuming its
    # name, so a future upstream rename degrades instead of breaking.
    # `|| true`: head closes the pipe early on a ~100MB archive, tar takes
    # SIGPIPE, and pipefail + set -e would abort the script right here.
    top_dir=$(tar -tzf "$archive" 2>/dev/null | head -1 | cut -d/ -f1) || true
    extracted="$tmp_dir/$top_dir"
    if [ -z "$top_dir" ] || [ ! -d "$extracted" ]; then
        log_warning "Unexpected Neovim archive layout; skipping custom install."
        rm -rf "$tmp_dir"
        return 0
    fi

    # No backup: this directory only ever holds an extracted upstream release
    # that this script put there, and timestamped copies pile up at 40MB each.
    rm -rf "$install_dir"
    mkdir -p "$HOME/.local" "$bin_dir"
    mv "$extracted" "$install_dir"
    ln -sf "$install_dir/bin/nvim" "$bin_dir/nvim"

    rm -rf "$tmp_dir"
    hash -r 2>/dev/null || true
    log_success "Neovim installed to $install_dir (symlinked at $bin_dir/nvim)"
}

# --------------------------------------------------------- prerequisites ---

check_prerequisites() {
    log_info "Verifying required tools..."

    local missing=""
    command -v git  >/dev/null 2>&1 || missing="$missing git"
    command -v zsh  >/dev/null 2>&1 || missing="$missing zsh"
    command -v nvim >/dev/null 2>&1 || missing="$missing neovim"
    have_c_compiler                 || missing="$missing a-C-compiler"

    if [ -n "$missing" ]; then
        log_error "Missing required tools:$missing"
        log_error "Install them with: $(install_hint)"

        # Don't send people to `apt-get install neovim`: that is the 0.10.x
        # package this config cannot run, which is why we skip it above.
        case "$missing" in
            *neovim*)
                if [ "$(detect_package_manager 2>/dev/null || true)" = "apt" ]; then
                    log_error "Note: Debian/Ubuntu ship neovim 0.10.x, too old for this config."
                    log_error "Re-run this script once the network is back, or grab a 0.11+"
                    log_error "release from https://github.com/neovim/neovim/releases"
                fi
                ;;
        esac
        exit 1
    fi

    if [ -f "$DOTFILES_DIR/tmux.conf" ] && ! command -v tmux >/dev/null 2>&1; then
        log_warning "tmux is not installed; ~/.tmux.conf will be linked but unused."
    fi

    # A second nvim earlier on PATH silently shadows the one we installed and
    # is usually too old for init.lua. Say so here instead of letting it
    # surface later as a wall of Lua errors in whichever shell picked it up.
    local managed_nvim="$HOME/.local/bin/nvim" shadows other
    if [ -x "$managed_nvim" ]; then
        shadows=$(
            PATH="$ORIGINAL_PATH:$PATH"
            type -a -P nvim 2>/dev/null | sort -u | grep -vxF "$managed_nvim"
        ) || shadows=""

        for other in $shadows; do
            [ -x "$other" ] || continue
            log_warning "Another nvim is installed at $other"
            log_warning "  $other: $("$other" --version 2>/dev/null | head -1 || true)"
            log_warning "  $managed_nvim: $("$managed_nvim" --version 2>/dev/null | head -1 || true)"
            log_info "Shells that do not put ~/.local/bin first will use the wrong one."
            log_info "Remove the distro package, e.g. sudo apt-get remove neovim"
        done
    fi

    log_success "All required tools present"
}

# -------------------------------------------------------------- linking ---

backup_file() {
    local target="$1"
    local source="$2"

    if [ -L "$target" ]; then
        local link_target source_abs
        link_target=$(resolve_path "$target" 2>/dev/null || true)
        source_abs=$(resolve_path "$source" 2>/dev/null || true)

        if [ -n "$link_target" ] && [ "$link_target" = "$source_abs" ]; then
            # 2 = already correct, caller can skip the relink.
            return 2
        fi
        log_warning "Symlink points elsewhere, replacing: $target -> $link_target"
        rm -f "$target"
    elif [ -e "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "File exists, backing up to: $backup"
        mv "$target" "$backup"
    fi
}

link_dotfile() {
    local source="$1"
    local target="$2"
    local name="$3"

    local rc=0
    backup_file "$target" "$source" || rc=$?
    if [ "$rc" -eq 2 ]; then
        log_info "$name already linked: $target"
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    if ln -sfn "$source" "$target"; then
        log_success "Linked $name: $target -> $source"
    else
        log_error "Failed to create symlink: $target"
        return 1
    fi
}

# ----------------------------------------------------------------- fonts ---

install_nerd_font() {
    local requested_font="${NERD_FONT_NAME:-Monokai}"
    local font_name="$requested_font"

    if [ "$(lowercase "$requested_font")" = "monokai" ]; then
        font_name="Mononoki"
        log_info "Monokai Nerd Font isn't published upstream; installing Mononoki instead."
    fi

    if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
        log_warning "curl or unzip missing; skipping Nerd Font install."
        return 0
    fi

    local fonts_dir
    if [ "$OS_NAME" = "Darwin" ]; then
        fonts_dir="$HOME/Library/Fonts"
    else
        fonts_dir="$HOME/.local/share/fonts"
    fi

    local font_display="${font_name} Nerd Font"
    local target_dir="$fonts_dir/${font_name}-NerdFont"

    # Cheap local check first; fc-list is Linux-only and not always present.
    if [ -d "$target_dir" ] \
        && ls "$target_dir"/*.ttf "$target_dir"/*.otf >/dev/null 2>&1; then
        log_info "$font_display already installed at $target_dir"
        return 0
    fi
    if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "$font_display"; then
        log_info "$font_display already installed."
        return 0
    fi

    local tmp_dir archive download_url
    tmp_dir=$(mktemp -d)
    archive="$tmp_dir/font.zip"
    download_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

    log_info "Downloading $font_display..."
    if ! curl -fsSL "$download_url" -o "$archive"; then
        log_warning "Failed to download $font_display from $download_url"
        rm -rf "$tmp_dir"
        return 0
    fi

    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    if ! unzip -oq "$archive" -d "$target_dir"; then
        log_warning "Failed to extract $font_display; install it manually."
        rm -rf "$tmp_dir" "$target_dir"
        return 0
    fi
    rm -rf "$tmp_dir"

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$fonts_dir" >/dev/null 2>&1 || true
        log_success "$font_display installed and font cache refreshed."
    else
        # macOS picks up ~/Library/Fonts without any cache step.
        log_success "$font_display installed to $target_dir"
    fi
}

# ---------------------------------------------------------------- neovim ---

# init.lua does `require 'kickstart.plugins.*'`, so those modules must exist
# under ~/.config/nvim/lua/kickstart.
#
# Pinned deliberately. On 2026-04-20 upstream kickstart migrated to Neovim's
# built-in vim.pack (commit c460542): its modules now call vim.pack.add and
# return nothing, so `require` yields `true`, and the lazy.nvim spec in our
# init.lua dies with "attempt to get length of local 'spec' (a boolean value)".
# cd7adee is the last commit before that, and it still ships gitsigns.lua.
KICKSTART_REPO="${KICKSTART_REPO:-https://github.com/nvim-lua/kickstart.nvim.git}"
KICKSTART_REF="${KICKSTART_REF:-cd7adee3cebd9cc915bbe69db5472b7da479e001}"

# The modules init.lua actually requires, read from init.lua itself so this
# never drifts out of sync with it. Commented-out requires are ignored.
required_kickstart_modules() {
    grep -oE "^[[:space:]]*require 'kickstart\.plugins\.[A-Za-z0-9_-]+'" \
        "$DOTFILES_DIR/init.lua" 2>/dev/null \
        | sed -e "s/.*kickstart\.plugins\.//" -e "s/'//" || true
}

kickstart_modules_ok() {
    local dir="$1" mod
    [ -d "$dir" ] || return 1

    # A vim.pack-era checkout is unusable with the lazy.nvim spec in init.lua.
    if grep -rqs 'vim\.pack\.add' "$dir"; then
        log_warning "Found vim.pack-era Kickstart modules; incompatible with init.lua."
        return 1
    fi

    for mod in $(required_kickstart_modules); do
        [ -f "$dir/plugins/$mod.lua" ] || return 1
    done
    return 0
}

# Fetch one pinned revision. Prefer a shallow fetch by SHA, falling back to a
# full clone for servers that refuse fetch-by-revision.
fetch_kickstart() {
    local dest="$1"
    if (
        mkdir -p "$dest" \
            && cd "$dest" \
            && git init --quiet . \
            && git remote add origin "$KICKSTART_REPO" \
            && git fetch --depth 1 --quiet origin "$KICKSTART_REF" \
            && git checkout --quiet FETCH_HEAD
    ) 2>/dev/null; then
        return 0
    fi

    log_info "Shallow fetch by revision failed; falling back to a full clone."
    rm -rf "$dest"
    if git clone --quiet "$KICKSTART_REPO" "$dest" \
        && (cd "$dest" && git checkout --quiet "$KICKSTART_REF"); then
        return 0
    fi
    return 1
}

ensure_kickstart_modules() {
    local config_dir="$1"
    local kickstart_dir="$config_dir/lua/kickstart"

    if [ -z "${KICKSTART_REFRESH:-}" ] && kickstart_modules_ok "$kickstart_dir"; then
        log_info "Kickstart modules already present at $kickstart_dir"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "Fetching Kickstart modules (pinned at ${KICKSTART_REF:0:12})..."
    if ! fetch_kickstart "$tmp_dir/repo"; then
        log_warning "Could not fetch Kickstart from $KICKSTART_REPO"
        log_warning "Neovim will error on startup until lua/kickstart exists."
        rm -rf "$tmp_dir"
        return 0
    fi

    if [ ! -d "$tmp_dir/repo/lua/kickstart" ]; then
        log_warning "Kickstart layout changed; lua/kickstart missing at $KICKSTART_REF"
        rm -rf "$tmp_dir"
        return 0
    fi

    mkdir -p "$config_dir/lua"
    rm -rf "$kickstart_dir"
    cp -R "$tmp_dir/repo/lua/kickstart" "$kickstart_dir"
    rm -rf "$tmp_dir"

    # Confirm every module init.lua requires actually landed.
    local mod missing=""
    for mod in $(required_kickstart_modules); do
        [ -f "$kickstart_dir/plugins/$mod.lua" ] || missing="$missing $mod"
    done
    if [ -n "$missing" ]; then
        log_warning "init.lua requires Kickstart modules that are missing:$missing"
        log_warning "Neovim will error on startup until those requires are removed."
    else
        log_success "Kickstart modules installed at $kickstart_dir"
    fi
}

# init.lua does `{ import = "custom.plugins" }`, which errors out if the
# directory does not exist. Seed it once and never touch it again: this is
# the user's own plugin space, not ours.
seed_custom_plugins_dir() {
    local custom_dir="$1/lua/custom/plugins"

    if [ -d "$custom_dir" ]; then
        return 0
    fi

    mkdir -p "$custom_dir"
    {
        echo "-- Your own plugins go here, or in sibling files in this directory."
        echo "-- init.lua pulls them in via { import = 'custom.plugins' }."
        echo "---@module 'lazy'"
        echo "---@type LazySpec"
        echo "return {}"
    } > "$custom_dir/init.lua"

    log_success "Seeded $custom_dir"
}

setup_neovim_config() {
    if [ -d "$DOTFILES_DIR/nvim" ]; then
        link_dotfile "$DOTFILES_DIR/nvim" "$HOME/.config/nvim" "nvim (entire dir)"
        return 0
    fi

    if [ ! -f "$DOTFILES_DIR/init.lua" ]; then
        log_warning "No init.lua in dotfiles; skipping Neovim configuration."
        return 0
    fi

    local config_dir="$HOME/.config/nvim"

    # Older runs of this script left a Kickstart git checkout here. It still
    # works, so leave it alone rather than blowing away someone's config.
    mkdir -p "$config_dir"

    ensure_kickstart_modules "$config_dir"
    seed_custom_plugins_dir "$config_dir"
    link_dotfile "$DOTFILES_DIR/init.lua" "$config_dir/init.lua" "nvim/init.lua"
}

# ----------------------------------------------------------------- shell ---

current_login_shell() {
    if [ "$OS_NAME" = "Darwin" ]; then
        dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
    elif command -v getent >/dev/null 2>&1; then
        getent passwd "$USER" 2>/dev/null | cut -d: -f7
    else
        printf '%s\n' "${SHELL:-}"
    fi
}

set_default_shell_to_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        log_warning "zsh is not installed; cannot set it as the default shell."
        return 0
    fi

    local zsh_path current
    zsh_path=$(command -v zsh)
    current=$(current_login_shell || true)

    if [ "$current" = "$zsh_path" ]; then
        log_info "zsh is already the default shell."
        return 0
    fi

    # macOS already defaults to /bin/zsh. Switching to Homebrew's zsh is not
    # worth a password prompt, so accept any zsh as good enough.
    if [ "$(basename "${current:-none}")" = "zsh" ]; then
        log_info "Login shell is already zsh ($current); leaving it unchanged."
        return 0
    fi

    # chsh refuses a shell that is not listed in /etc/shells.
    if [ -r /etc/shells ] && ! grep -qxF "$zsh_path" /etc/shells; then
        log_warning "$zsh_path is not listed in /etc/shells, so chsh will refuse it."
        log_info "Add it, then re-run:  echo '$zsh_path' | sudo tee -a /etc/shells"
        return 0
    fi

    log_info "Setting default shell to zsh (you may be prompted for your password)..."
    if chsh -s "$zsh_path"; then
        log_success "Default shell changed to zsh. Log out and back in to apply."
    else
        log_warning "Could not change the default shell. Run 'chsh -s $zsh_path' manually."
    fi
}

# -------------------------------------------------------------- reporting ---

# Interactive non-login bash reads ~/.bashrc and NOT ~/.profile. That gap is why
# `nvim` can come back "command not found" in a terminal even when the login
# shell is zsh and everything installed correctly.
bashrc_has_local_bin() {
    [ -r "$HOME/.bashrc" ] || return 1
    grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null
}

report_next_steps() {
    local zsh_path login_shell
    zsh_path=$(command -v zsh 2>/dev/null) || zsh_path=""
    login_shell=$(current_login_shell) || login_shell=""

    echo ""
    log_info "Next steps:"

    case "$(basename "${login_shell:-none}")" in
        zsh)
            log_info "  Login shell is zsh ($login_shell). Nothing to do."
            ;;
        *)
            log_warning "  Login shell is ${login_shell:-unknown}, not zsh."
            if [ -n "$zsh_path" ]; then
                log_info "  Change it with:  chsh -s $zsh_path"
                log_info "  Then log out and back in for it to take effect."
            fi
            ;;
    esac

    log_info "  Start zsh now with:  exec zsh"
    log_info "  The first zsh launch installs zinit and plugins; give it a minute."

    # Everything we install by hand lands in ~/.local/bin, and only zshrc puts
    # that on PATH. Say so before the user hits it from a bash terminal.
    if [ -d "$HOME/.local/bin" ] && command -v bash >/dev/null 2>&1 \
        && ! bashrc_has_local_bin; then
        echo ""
        log_warning "  bash will not find the tools installed to ~/.local/bin."
        log_info "  zsh puts it on PATH, and ~/.profile covers login shells, but a"
        log_info "  plain bash terminal reads only ~/.bashrc. Add it there too:"
        log_info "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    fi
}

# ------------------------------------------------------------------ main ---

main() {
    log_info "Starting dotfiles bootstrap..."
    log_info "Platform: $OS_NAME/$ARCH_NAME"
    log_info "Dotfiles: $DOTFILES_DIR"

    check_macos_toolchain
    install_system_packages
    install_latest_neovim_release
    check_prerequisites

    link_dotfile "$DOTFILES_DIR/zshrc" "$HOME/.zshrc" "zshrc"
    link_dotfile "$DOTFILES_DIR/p10k.zsh" "$HOME/.p10k.zsh" "p10k.zsh"

    if [ -f "$DOTFILES_DIR/tmux.conf" ]; then
        link_dotfile "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" "tmux.conf"
    fi

    setup_neovim_config
    install_nerd_font
    set_default_shell_to_zsh

    # Zinit and fzf are intentionally not installed here: zshrc bootstraps
    # zinit on first launch and installs fzf as a zinit plugin.

    echo ""
    if [ "$WARN_COUNT" -eq 0 ]; then
        log_success "Bootstrap completed successfully."
    else
        log_success "Bootstrap completed with $WARN_COUNT warning(s) (see above)."
    fi
    report_next_steps
}

main "$@"
