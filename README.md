# Dotfiles

Personal dotfiles configuration for zsh with Powerlevel10k, Zinit, and fzf.

## Features

- **Bootstrapper** installs required packages on Debian/Ubuntu (apt) and Arch (pacman)
- **Zsh** configuration with Powerlevel10k theme and zsh set as the default shell
- **Zinit** plugin manager + **fzf** fuzzy finder
- **tmux** configuration (optional)
- **Neovim + Kickstart** configuration with lazy.nvim (latest Neovim release downloaded automatically on apt-based systems)

## Quick Start

### Prerequisites

- Ability to run `sudo` for package installation
- Debian/Ubuntu or Arch-based distro with either `apt` or `pacman`

### Installation

1. Clone this repository:
   ```bash
   git clone <your-repo-url> ~/dotfiles
   cd ~/dotfiles
   ```

2. Run the bootstrap script:
   ```bash
   ./install.sh
   ```

3. Activate the configuration:
   ```bash
   source ~/.zshrc
   ```

   Or simply start a new shell session.

## What the Install Script Does

The `install.sh` script is **idempotent** (safe to run multiple times) and will:

1. **Install system packages** - Uses apt or pacman to install git, zsh, ripgrep, curl, etc.
2. **Download latest Neovim (apt systems)** - Fetches the newest GitHub release to `~/.local/neovim` and symlinks it in `~/.local/bin`
3. **Check prerequisites** - Verifies required tooling is now available
4. **Backup existing files** - Creates timestamped backups before overwriting dotfiles
5. **Create symlinks** - Links configuration files to their proper locations:
   - `zshrc` → `~/.zshrc`
   - `p10k.zsh` → `~/.p10k.zsh`
   - `tmux.conf` → `~/.tmux.conf` (if present)
6. **Install Kickstart for Neovim** - Clones the Kickstart repo into `~/.config/nvim` (backup existing config) and links this repo's `init.lua`
7. **Install tooling** - Installs/updates Zinit and fzf
8. **Set default shell** - Runs `chsh -s "$(which zsh)"` to make zsh the default login shell

## Improvements

The bootstrap script includes several reliability improvements:

- ✅ **Error handling** - Exits on errors with clear messages
- ✅ **Package installation** - Installs dependencies on Debian/Ubuntu or Arch automatically
- ✅ **Latest Neovim** - Downloads the newest official release on apt-based systems
- ✅ **Prerequisite checks** - Verifies required tools are installed
- ✅ **Backup mechanism** - Backs up existing files before overwriting
- ✅ **Idempotency** - Can be run multiple times safely
- ✅ **Dynamic path detection** - Works regardless of where the repo is cloned
- ✅ **Better logging** - Color-coded output for better visibility
- ✅ **Update support** - Updates existing installations when possible

## Files

- `zshrc` - Main zsh configuration file
- `p10k.zsh` - Powerlevel10k theme configuration
- `tmux.conf` - tmux terminal multiplexer configuration (optional)
- `init.lua` - Neovim editor configuration (optional)
- `install.sh` - Bootstrap script

## Customization

After installation, you can customize:

- **Prompt**: Run `p10k configure` to reconfigure Powerlevel10k
- **Zsh config**: Edit `~/dotfiles/zshrc` (changes take effect after reloading)
- **Theme config**: Edit `~/dotfiles/p10k.zsh`
- **tmux config**: Edit `~/dotfiles/tmux.conf` (reload with `tmux source-file ~/.tmux.conf`)
- **Neovim config**: Edit `~/dotfiles/init.lua` (changes take effect on next Neovim start)

## Troubleshooting

### Script fails with "Missing required dependencies"

Install the missing dependencies (git and/or zsh) using your system's package manager.

### Symlinks not working

If symlinks fail, check:
- You have write permissions in your home directory
- The dotfiles directory is accessible
- Run the script with appropriate permissions

### Zinit or fzf installation fails

- Check your internet connection
- Verify git is working: `git --version`
- Check if the directories already exist and remove them if corrupted

## License

Personal configuration - use as you wish.
