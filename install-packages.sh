#!/bin/bash

# Script to install apt packages from apt-packages.txt
# Usage: ./install-packages.sh [apt-packages.txt]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${1:-$DOTFILES_DIR/apt-packages.txt}"

if [ ! -f "$PACKAGES_FILE" ]; then
    log_error "Packages file not found: $PACKAGES_FILE"
    exit 1
fi

log_info "Reading packages from: $PACKAGES_FILE"

# Extract package names (ignore comments and empty lines)
PACKAGES=$(grep -v '^#' "$PACKAGES_FILE" | grep -v '^$' | grep -v '^[[:space:]]*$' | tr '\n' ' ')

if [ -z "$PACKAGES" ]; then
    log_warning "No packages found in $PACKAGES_FILE"
    exit 0
fi

log_info "Packages to install:"
echo "$PACKAGES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /'

echo ""
read -p "Do you want to proceed with installation? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
fi

log_info "Updating package list..."
sudo apt-get update

log_info "Installing packages..."
# Use xargs to handle the package list properly
echo "$PACKAGES" | xargs sudo apt-get install -y

log_success "Package installation completed!"

# Post-installation notes
echo ""
log_info "Post-installation notes:"
log_info "- If you installed docker.io, add your user to docker group:"
echo "  sudo usermod -aG docker \$USER"
echo ""
log_info "- Some tools have different command names:"
echo "  - fd-find → use 'fd'"
echo "  - ripgrep → use 'rg'"
echo ""
log_info "- Consider installing these via other methods for latest versions:"
echo "  - thefuck: pip install thefuck"
echo "  - bat, exa, delta, lazygit: Check GitHub releases"

