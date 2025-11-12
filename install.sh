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
                    ;;
                zsh)
                    echo "  - Debian/Ubuntu: sudo apt-get install zsh"
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
                    ;;
                "nvim (or vim)")
                    echo "  - Debian/Ubuntu: sudo apt-get install neovim"
                    ;;
            esac
        done
        echo ""
    fi
    
    log_success "All required prerequisites met"
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

# Main installation function
main() {
    log_info "Starting dotfiles bootstrap..."
    log_info "Home directory: $HOME"
    
    check_prerequisites
    
    # Link dotfiles
    link_dotfile "$DOTFILES_DIR/zshrc" "$HOME/.zshrc" "zshrc"
    link_dotfile "$DOTFILES_DIR/p10k.zsh" "$HOME/.p10k.zsh" "p10k.zsh"
    
    # Link optional dotfiles if they exist
    if [ -f "$DOTFILES_DIR/tmux.conf" ]; then
        link_dotfile "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" "tmux.conf"
    fi
    
    if [ -f "$DOTFILES_DIR/init.lua" ]; then
        # Create nvim config directory if it doesn't exist
        mkdir -p "$HOME/.config/nvim"
        link_dotfile "$DOTFILES_DIR/init.lua" "$HOME/.config/nvim/init.lua" "nvim/init.lua"
    fi
    
    # Install dependencies
    install_zinit
    install_fzf
    
    log_success "Bootstrap completed successfully!"
    echo ""
    log_info "To activate your new configuration, run:"
    echo "  source ~/.zshrc"
    echo ""
    log_info "Or start a new shell session."
}

# Run main function
main "$@"
