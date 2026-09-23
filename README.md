# Dotfiles

Personal dotfiles for zsh with Powerlevel10k, Zinit, fzf, tmux and Neovim.

## Features

- **Bootstrapper** for Debian/Ubuntu (apt), Arch (pacman) and macOS (Homebrew)
- **Zsh** with Powerlevel10k, set as the default login shell
- **Zinit** plugin manager + **fzf** fuzzy finder (Ctrl-R history, Ctrl-T files)
- **tmux** installed and configured
- **Neovim + Kickstart** with lazy.nvim; the latest Neovim release is downloaded
  automatically on Linux, and comes from Homebrew on macOS
- **Mononoki Nerd Font** installed into `~/.local/share/fonts` (Linux) or
  `~/Library/Fonts` (macOS)

## Quick Start

### Prerequisites

**Linux** — a Debian/Ubuntu or Arch-based distro, and the ability to run `sudo`.

**macOS** — Xcode Command Line Tools and Homebrew. The script checks for both
and tells you what to run if either is missing:

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Installation

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
exec zsh
```

The first zsh launch bootstraps Zinit and its plugins, so it takes a minute.

## What the Install Script Does

`install.sh` is idempotent — re-running it is a no-op when everything is in
place — and it never aborts the whole run over one optional step.

1. **Checks the macOS toolchain** (Command Line Tools, Homebrew) and stops early
   with instructions if either is missing
2. **Installs system packages** via apt, pacman or Homebrew — git, zsh, tmux,
   ripgrep, fzf, git-delta, a compiler and friends, plus flatpak on Linux. If
   a bulk install fails it retries package by package, so one unavailable
   package no longer kills the run
3. **Installs Neovim** — from GitHub releases on Linux (`~/.local/neovim`,
   symlinked into `~/.local/bin`), Homebrew on macOS. The Debian/Ubuntu
   `neovim` package is deliberately *not* installed: it is 0.10.x, too old for
   `init.lua`, and `/usr/bin/nvim` would then shadow the current build in any
   shell that doesn't put `~/.local/bin` first. The script warns if it finds
   another nvim already installed
4. **Verifies prerequisites** — git, zsh, nvim and a C compiler
5. **Backs up and symlinks** `zshrc` → `~/.zshrc`, `p10k.zsh` → `~/.p10k.zsh`,
   `tmux.conf` → `~/.tmux.conf`, and `lazygit.yml` → Lazygit's OS-specific
   config path (`~/.config/lazygit/config.yml` on Linux, `~/Library/Application Support/lazygit/config.yml` on macOS)
6. **Installs Kickstart's Lua modules** into `~/.config/nvim/lua/kickstart`, then
   links this repo's `init.lua` over the top
7. **Links custom Neovim Lua** from this repo (`lua/custom` → `~/.config/nvim/lua/custom`)
   when present; otherwise seeds `~/.config/nvim/lua/custom/plugins/init.lua`
8. **Installs the Nerd Font** into the right place for your OS
9. **Sets zsh as the login shell**, unless it already is one
10. **Reports next steps** — whether the login shell is zsh, and whether bash
    can see the tools installed into `~/.local/bin`

Zinit and fzf are deliberately *not* installed here: `zshrc` bootstraps Zinit on
first launch and pulls fzf in as a Zinit plugin.

### Pinned versions

Kickstart is pinned to `cd7adee`, the last commit before upstream migrated to
Neovim's built-in `vim.pack`. After that migration its modules call
`vim.pack.add` and return nothing, so `require` yields `true` and the lazy.nvim
spec in `init.lua` fails with *"attempt to get length of local 'spec'"*. The
script detects an already-installed `vim.pack`-era checkout and replaces it.

Override with `KICKSTART_REF=<sha>`, or force a re-fetch with
`KICKSTART_REFRESH=1 ./install.sh`.

`nvim-treesitter` is pinned to its `master` branch in `init.lua`, because the
default branch moved to `main` and dropped the `nvim-treesitter.configs` module
that this config drives through `main`/`opts`.

## Files

- `zshrc` — zsh configuration
- `p10k.zsh` — Powerlevel10k theme
- `tmux.conf` — tmux configuration (optional)
- `lazygit.yml` — Lazygit configuration
- `init.lua` — Neovim configuration (optional)
- `install.sh` — bootstrap script
- `apt-packages.txt` — optional extras (toolchain, clipboard, LSP runtimes, CLI)
- `install-packages.sh` — installs `apt-packages.txt`; pass a path to use another list

## Customization

- **Prompt**: `p10k configure`
- **Font**: `NERD_FONT_NAME=<FontName> ./install.sh` (defaults to Mononoki)
- **Kickstart revision**: `KICKSTART_REF=<sha> ./install.sh`
- **Your own Neovim plugins**: add them to `lua/custom/plugins/` in this repo

## Troubleshooting

### "Xcode Command Line Tools are not installed" / "Homebrew was not found"

Run the two commands under **Prerequisites**, then re-run `./install.sh`.

### Homebrew tools are missing from new shells

`zshrc` runs `brew shellenv` on macOS, which is what puts `/opt/homebrew/bin` on
`PATH` on Apple Silicon. If you use another shell, set that up there too.

### Neovim errors about a missing `kickstart.plugins.*` module

Run `KICKSTART_REFRESH=1 ./install.sh`. The script reads the required module
list straight out of `init.lua` and warns if any of them failed to land.

### Neovim errors about lspconfig / typescript-tools / `vim.lsp.enable`

Errors like *"Neovim 0.10.4 found, but >= 0.11 is required"* or
*"attempt to call field 'enable' (a nil value)"* mean you are running a second,
older nvim — almost always `/usr/bin/nvim` from the distro package. Check with:

```bash
command -v nvim && nvim --version | head -1
```

If that is not `~/.local/bin/nvim`, remove the distro package:

```bash
sudo apt-get remove neovim
```

Your zsh puts `~/.local/bin` first, so `nvim` is correct there — but bash,
scripts, and `sudo nvim` are not, which is why the errors seem to come and go.

### `nvim: command not found` in bash, but it works in zsh

`install.sh` puts Neovim in `~/.local/bin`, and `zshrc` is what adds that to
`PATH`. `~/.profile` also adds it, but **only login shells read `~/.profile`** —
an interactive non-login bash (most terminal panels) reads `~/.bashrc` alone.

Either use your login shell:

```bash
exec zsh
```

or teach bash about the directory:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

The installer warns about this at the end of its run when `~/.bashrc` does not
already cover it.

### "Could not change the default shell"

`chsh` needs your password, and refuses shells absent from `/etc/shells`:

```bash
echo "$(command -v zsh)" | sudo tee -a /etc/shells
chsh -s "$(command -v zsh)"
```

### Some packages failed to install

The script continues past them and lists each one. Install the stragglers by
hand; the names differ slightly across distros.

## License

Personal configuration — use as you wish.
