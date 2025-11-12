# Dotfiles

Personal dotfiles configuration for zsh with Powerlevel10k, Zinit, and fzf.

## Features

- **Zsh** configuration with Powerlevel10k theme
- **Zinit** plugin manager for fast zsh plugin loading
- **fzf** fuzzy finder integration
- **Powerlevel10k** prompt customization
- **tmux** terminal multiplexer configuration
- **Neovim** editor configuration (init.lua)

## Quick Start

### Prerequisites

- `git` - for cloning repositories
- `zsh` - the shell this configuration is for

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

1. **Check prerequisites** - Verifies that `git` and `zsh` are installed
2. **Backup existing files** - Creates timestamped backups of any existing dotfiles
3. **Create symlinks** - Links configuration files to their proper locations:
   - `zshrc` → `~/.zshrc`
   - `p10k.zsh` → `~/.p10k.zsh`
   - `tmux.conf` → `~/.tmux.conf` (if present)
   - `init.lua` → `~/.config/nvim/init.lua` (if present)
4. **Install Zinit** - Clones and sets up the Zinit plugin manager
5. **Install fzf** - Clones and installs fzf with key bindings and completion

## Improvements

The bootstrap script includes several reliability improvements:

- ✅ **Error handling** - Exits on errors with clear messages
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

