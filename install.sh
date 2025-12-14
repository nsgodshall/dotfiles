#!/bin/bash

# Improved dotfiles bootstrap script
# This script is idempotent and can be run multiple times safely

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect the dotfiles directory
# This script should be run from the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$DOTFILES_DIR/zshrc" ] || [ ! -f "$DOTFILES_DIR/p10k.zsh" ]; then
    log_error "Could not find dotfiles in $DOTFILES_DIR"
    log_error "Please run this script from the dotfiles directory"
    exit 1
fi

# Optional files (warn if missing but don't fail)
if [ ! -f "$DOTFILES_DIR/tmux.conf" ]; then
    log_warning "tmux.conf not found in dotfiles directory (optional)"
fi
if [ ! -f "$DOTFILES_DIR/init.lua" ]; then
    log_warning "init.lua not found in dotfiles directory (optional)"
fi

log_info "Detected dotfiles directory: $DOTFILES_DIR"

# Ensure ~/.local/bin is evaluated before running checks so locally installed tools are detected
export PATH="$HOME/.local/bin:$PATH"

# Detect the package manager (supports Debian/Ubuntu via apt and Arch via pacman)
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
        return 0
    fi

    if command -v pacman &> /dev/null; then
        echo "pacman"
        return 0
    fi

    return 1
}

# Install base system packages using the detected package manager
install_system_packages() {
    local manager
    if ! manager=$(detect_package_manager); then
        log_warning "Could not detect a supported package manager (apt or pacman)."
        log_warning "Please install git, zsh, and neovim manually before proceeding."
        return 0
    fi

    if ! command -v sudo &> /dev/null; then
        log_warning "sudo is not available; skipping automatic package installation."
        log_warning "Ensure git, zsh, and neovim are installed before continuing."
        return 0
    fi

    local packages=(git zsh curl wget ripgrep unzip tar neovim)

    case "$manager" in
        apt)
            log_info "Installing required packages via apt-get..."
            sudo apt-get update -y
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
            ;;
        pacman)
            log_info "Installing required packages via pacman..."
            sudo pacman -Sy --needed --noconfirm "${packages[@]}"
            ;;
    esac

    log_success "Base packages installed"
}

# Install the latest Neovim release from GitHub for Linux x86_64 systems.
install_latest_neovim_release() {
    local os_name
    os_name=$(uname -s)
    local arch
    arch=$(uname -m)

    if [ "$os_name" != "Linux" ]; then
        log_warning "Automatic Neovim release install is only supported on Linux. Skipping custom install."
        return 0
    fi

    case "$arch" in
        x86_64|amd64)
            :
            ;;
        *)
            log_warning "Automatic Neovim install currently supports only x86_64/amd64. Skipping custom install."
            return 0
            ;;
    esac

    if ! command -v curl &> /dev/null || ! command -v tar &> /dev/null; then
        log_warning "curl or tar missing; cannot install latest Neovim release."
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local download_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"
    local archive="$tmp_dir/nvim.tar.gz"
    local install_dir="$HOME/.local/neovim"
    local bin_dir="$HOME/.local/bin"

    log_info "Downloading latest Neovim release..."
    if ! curl -fsSL "$download_url" -o "$archive"; then
        log_warning "Failed to download Neovim release archive."
        rm -rf "$tmp_dir"
        return 0
    fi

    log_info "Extracting Neovim to $install_dir..."
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        log_warning "Failed to extract Neovim archive."
        rm -rf "$tmp_dir"
        return 0
    fi

    backup_existing_path "$install_dir"
    mkdir -p "$HOME/.local"
    mv "$tmp_dir/nvim-linux64" "$install_dir"

    mkdir -p "$bin_dir"
    ln -sf "$install_dir/bin/nvim" "$bin_dir/nvim"

    rm -rf "$tmp_dir"
    log_success "Latest Neovim installed to $install_dir (symlinked at $bin_dir/nvim)"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_required=()
    local missing_optional=()

    # Required dependencies (script will fail without these)
    if ! command -v git &> /dev/null; then
        missing_required+=("git")
    fi

    if ! command -v zsh &> /dev/null; then
        missing_required+=("zsh")
    fi

    if ! command -v nvim &> /dev/null; then
        missing_required+=("neovim")
    fi
    
    # Optional dependencies (script will warn but continue)
    if [ -f "$DOTFILES_DIR/tmux.conf" ] && ! command -v tmux &> /dev/null; then
        missing_optional+=("tmux")
    fi
    
    if [ -f "$DOTFILES_DIR/init.lua" ] && ! command -v nvim &> /dev/null && ! command -v vim &> /dev/null; then
        missing_optional+=("nvim (or vim)")
    fi
    
    # Check for required dependencies
    if [ ${#missing_required[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_required[*]}"
        log_error "Please install them before running this script"
        echo ""
        log_info "Installation suggestions:"
        for dep in "${missing_required[@]}"; do
            case "$dep" in
                git)
                    echo "  - Debian/Ubuntu: sudo apt-get install git"
                    echo "  - Arch Linux: sudo pacman -S git"
                    ;;
                zsh)
                    echo "  - Debian/Ubuntu: sudo apt-get install zsh"
                    echo "  - Arch Linux: sudo pacman -S zsh"
                    ;;
                neovim)
                    echo "  - Debian/Ubuntu: sudo apt-get install neovim"
                    echo "  - Arch Linux: sudo pacman -S neovim"
                    ;;
            esac
        done
        exit 1
    fi
    
    # Warn about optional dependencies
    if [ ${#missing_optional[@]} -gt 0 ]; then
        log_warning "Some optional tools are missing: ${missing_optional[*]}"
        log_info "The script will continue, but some features may not work"
        echo ""
        log_info "Installation suggestions:"
        for dep in "${missing_optional[@]}"; do
            case "$dep" in
                tmux)
                    echo "  - Debian/Ubuntu: sudo apt-get install tmux"
                    echo "  - Arch Linux: sudo pacman -S tmux"
                    ;;
                "nvim (or vim)")
                    echo "  - Debian/Ubuntu: sudo apt-get install neovim"
                    echo "  - Arch Linux: sudo pacman -S neovim"
                    ;;
            esac
        done
        echo ""
    fi

    log_success "All required prerequisites met"
}

# Backup a path (file, dir, or symlink) before replacing it
backup_existing_path() {
    local target="$1"

    if [ -L "$target" ] || [ -e "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing path $target to $backup"
        mv "$target" "$backup"
    fi
}

# Backup existing file if it exists and is not a symlink to our dotfiles
backup_file() {
    local target="$1"
    local source="$2"
    
    if [ -L "$target" ]; then
        # Check if it's already pointing to our dotfiles
        local link_target=$(readlink -f "$target" 2>/dev/null || true)
        local source_abs=$(readlink -f "$source" 2>/dev/null || true)
        
        if [ "$link_target" = "$source_abs" ]; then
            log_info "Symlink already exists and points to correct location: $target"
            return 0
        else
            log_warning "Symlink exists but points elsewhere: $target -> $link_target"
            log_info "Removing old symlink..."
            rm -f "$target"
        fi
    elif [ -e "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "File exists, backing up to: $backup"
        mv "$target" "$backup"
    fi
}

# Create symlink for a dotfile
link_dotfile() {
    local source="$1"
    local target="$2"
    local name="$3"
    
    log_info "Linking $name..."
    
    backup_file "$target" "$source"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"
    
    # Create symlink
    if ln -sf "$source" "$target"; then
        log_success "Linked $name: $target -> $source"
    else
        log_error "Failed to create symlink: $target"
        return 1
    fi
}

# Install Zinit
install_zinit() {
    local zinit_dir="$HOME/.local/share/zinit/zinit.git"
    
    # Check if Zinit is already installed in the expected location
    if [ -d "$zinit_dir" ] && [ -f "$zinit_dir/zinit.zsh" ]; then
        log_info "Zinit already installed at $zinit_dir"
        if [ -d "$zinit_dir/.git" ]; then
            log_info "Checking for updates..."
            (cd "$zinit_dir" && git pull --quiet 2>/dev/null || log_warning "Could not update Zinit (may already be up to date)")
        fi
        log_success "Zinit is ready"
        return 0
    fi
    
    # Check if Zinit might be installed elsewhere (check if zinit command exists)
    if command -v zinit &> /dev/null || [ -n "${ZINIT_HOME:-}" ]; then
        log_warning "Zinit appears to be installed elsewhere"
        log_info "This script will install Zinit to: $zinit_dir"
        log_info "If you prefer to use your existing installation, you may need to update your zshrc"
    fi
    
    log_info "Installing Zinit to $zinit_dir..."
    
    mkdir -p "$(dirname "$zinit_dir")"
    
    if git clone --quiet https://github.com/zdharma-continuum/zinit.git "$zinit_dir"; then
        log_success "Zinit installed successfully"
    else
        log_error "Failed to install Zinit"
        return 1
    fi
}

# Install fzf
install_fzf() {
    local fzf_dir="$HOME/.fzf"
    
    # Check if fzf is already available in PATH (system-wide or other installation)
    if command -v fzf &> /dev/null; then
        local fzf_path=$(command -v fzf)
        log_info "fzf is already available at: $fzf_path"
        
        # If it's in our expected location, try to update it
        if [ -d "$fzf_dir" ] && [ -d "$fzf_dir/.git" ]; then
            log_info "Found fzf installation at $fzf_dir, checking for updates..."
            (cd "$fzf_dir" && git pull --quiet 2>/dev/null || log_warning "Could not update fzf (may already be up to date)")
        else
            log_info "Using existing fzf installation (not in $fzf_dir)"
            log_info "Your zshrc should work with the existing fzf installation"
        fi
        log_success "fzf is ready"
        return 0
    fi
    
    # Check if fzf directory exists but fzf command is not in PATH
    if [ -d "$fzf_dir" ]; then
        log_info "fzf directory exists at $fzf_dir but fzf command not found in PATH"
        log_info "Checking for updates..."
        if [ -d "$fzf_dir/.git" ]; then
            (cd "$fzf_dir" && git pull --quiet 2>/dev/null || log_warning "Could not update fzf")
        fi
        log_warning "fzf directory exists but may not be properly configured"
        log_info "You may need to add $fzf_dir/bin to your PATH"
        return 0
    fi
    
    log_info "Installing fzf to $fzf_dir..."
    
    if git clone --depth 1 --quiet https://github.com/junegunn/fzf.git "$fzf_dir"; then
        log_info "Running fzf install script..."
        # The install script may fail if fzf is already in PATH from another source,
        # but that's okay - we just want the key bindings and completion
        if "$fzf_dir/install" --key-bindings --completion --no-update-rc 2>/dev/null; then
            log_success "fzf installed successfully"
        else
            log_warning "fzf cloned but install script had issues"
            log_info "This may be okay if fzf is already available elsewhere"
            log_info "You can manually run: $fzf_dir/install"
        fi
    else
        log_error "Failed to clone fzf"
        return 1
    fi
}

# Ensure Kickstart (Neovim starter config) is installed
ensure_kickstart_repo() {
    local config_dir="$1"
    local kickstart_repo="${KICKSTART_REPO:-https://github.com/nvim-lua/kickstart.nvim.git}"

    if [ -d "$config_dir/lua/kickstart" ]; then
        if [ -d "$config_dir/.git" ]; then
            log_info "Kickstart repository detected, checking for updates..."
            if (cd "$config_dir" && git pull --ff-only --quiet); then
                log_success "Kickstart updated"
            else
                log_warning "Could not update Kickstart repository (perhaps local changes exist)"
            fi
        else
            log_info "Kickstart directory already present at $config_dir"
        fi
        return 0
    fi

    log_info "Installing Kickstart Neovim configuration..."
    backup_existing_path "$config_dir"

    mkdir -p "$(dirname "$config_dir")"
    if git clone --depth 1 "$kickstart_repo" "$config_dir"; then
        log_success "Kickstart installed at $config_dir"
    else
        log_error "Failed to clone Kickstart into $config_dir"
        return 1
    fi
}

# Set Zsh as the default shell for the current user
set_default_shell_to_zsh() {
    if ! command -v zsh &> /dev/null; then
        log_warning "zsh is not installed; cannot set it as the default shell."
        return
    fi

    local zsh_path
    zsh_path=$(command -v zsh)

    local current_shell
    if command -v getent &> /dev/null; then
        current_shell=$(getent passwd "$USER" | cut -d: -f7)
    else
        current_shell="${SHELL:-}"
    fi

    if [ "$current_shell" = "$zsh_path" ]; then
        log_info "zsh is already the default shell."
        return
    fi

    log_info "Setting default shell to zsh..."
    if chsh -s "$zsh_path" "$USER"; then
        log_success "Default shell changed to zsh. Please log out and back in for changes to take effect."
    else
        log_warning "Failed to change default shell automatically. Run 'chsh -s $zsh_path' manually."
    fi
}

# Configure Neovim with Kickstart if needed
setup_neovim_config() {
    if [ -d "$DOTFILES_DIR/nvim" ]; then
        link_dotfile "$DOTFILES_DIR/nvim" "$HOME/.config/nvim" "nvim (entire dir)"
        return
    fi

    if [ ! -f "$DOTFILES_DIR/init.lua" ]; then
        log_warning "No Neovim configuration found in dotfiles (init.lua missing). Skipping."
        return
    fi

    ensure_kickstart_repo "$HOME/.config/nvim"

    link_dotfile "$DOTFILES_DIR/init.lua" "$HOME/.config/nvim/init.lua" "nvim/init.lua"
}

# Main installation function
main() {
    log_info "Starting dotfiles bootstrap..."
    log_info "Home directory: $HOME"

    install_system_packages

    local package_manager=""
    if package_manager=$(detect_package_manager); then
        if [ "$package_manager" = "apt" ]; then
            install_latest_neovim_release
        fi
    fi

    check_prerequisites

    # Link dotfiles
    link_dotfile "$DOTFILES_DIR/zshrc" "$HOME/.zshrc" "zshrc"
    link_dotfile "$DOTFILES_DIR/p10k.zsh" "$HOME/.p10k.zsh" "p10k.zsh"
    
    # Link optional dotfiles if they exist
    if [ -f "$DOTFILES_DIR/tmux.conf" ]; then
        link_dotfile "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" "tmux.conf"
    fi
    
    setup_neovim_config

    # Install dependencies
    install_zinit
    install_fzf

    set_default_shell_to_zsh

    log_success "Bootstrap completed successfully!"
    echo ""
    log_info "To activate your new configuration, run:"
    echo "  source ~/.zshrc"
    echo ""
    log_info "Or start a new shell session."
}

# Run main function
main "$@"
