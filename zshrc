# -----------------------------
# Welcome Message
# -----------------------------
clean_welcome() {
  if [[ -z "$ZSH_WELCOME_SHOWN" ]]; then
    local datetime=$(date '+%a, %b %d %Y — %I:%M %p')
    local hostname=$(hostname -s)
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    echo ""
    echo "User        :  $USER@$hostname"
    echo "Directory   :  $(pwd)"
    echo "Started     :  $datetime"
    [[ -n "$git_branch" ]] && echo "Git Branch  :  $git_branch"
    echo ""

    export ZSH_WELCOME_SHOWN=1
  fi
}

autoload -Uz add-zsh-hook
# clean_welcome

# -----------------------------
# Powerlevel10k Instant Prompt
# -----------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------
# History Settings
# -----------------------------
# Use XDG directory if available, fallback to home
HISTDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
mkdir -p "$HISTDIR"
export HISTFILE="$HISTDIR/history"
export HISTSIZE=5000000
export SAVEHIST=$HISTSIZE

setopt EXTENDED_HISTORY          # Save timestamp and duration
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first
setopt HIST_FIND_NO_DUPS          # Don't show duplicates in search
setopt HIST_IGNORE_SPACE          # Ignore commands starting with space
setopt HIST_SAVE_NO_DUPS          # Don't save duplicates
setopt SHARE_HISTORY              # Share history between sessions
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd)

# -----------------------------
# Shell Options
# -----------------------------
setopt autocd                    # cd to directory by typing its name
setopt extendedglob              # Extended globbing
setopt nomatch                   # Error if no match
setopt notify                    # Report job status immediately
setopt AUTO_PUSHD                # cd pushes to directory stack
setopt PUSHD_IGNORE_DUPS         # Don't push duplicates
setopt PUSHD_SILENT              # Don't print directory stack
setopt CDABLE_VARS               # cd to variables
unsetopt beep                    # Disable beep

# Choose your keybinding mode (emacs or vi)
# Uncomment the one you prefer:
bindkey -e                       # Emacs mode (default)
# bindkey -v                      # Vi mode

# -----------------------------
# Completion Setup
# -----------------------------
# Use XDG directory for completion cache
COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
zstyle :compinstall filename "$HOME/.zshrc"

# Only run compinit if cache is older than 24 hours or missing
autoload -Uz compinit
if [[ -n ${COMPDUMP}(#qN.mh+24) ]]; then
  compinit -d "$COMPDUMP"
else
  compinit -C -d "$COMPDUMP"
fi

# -----------------------------
# Zinit Plugin Manager
# -----------------------------
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
  print -P "%F{33} %F{220}Installing %F{33}Zinit%F{220} Plugin Manager…%f"
  command mkdir -p "$HOME/.local/share/zinit" && chmod g-rwX "$HOME/.local/share/zinit"
  command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
    print -P "%F{33} %F{34}Installation successful.%f%b" || \
    print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Zinit Annexes
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

# -----------------------------
# Plugins via Zinit
# -----------------------------
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit ice depth=1; zinit light zsh-users/zsh-autosuggestions
zinit ice wait'0' lucid; zinit load zdharma-continuum/fast-syntax-highlighting
zinit ice wait'0' lucid; zinit load rupa/z

# Load fzf and its bindings (single time only)
zinit ice depth=1 atload='[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh'
zinit light junegunn/fzf

# -----------------------------
# Powerlevel10k Config
# -----------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# -----------------------------
# PATH Management
# -----------------------------
# fnm (Fast Node Manager) - Node.js version manager
FNM_PATH="$HOME/.local/share/fnm"
if [[ -d "$FNM_PATH" ]]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd 2>/dev/null)" || eval "$(fnm env 2>/dev/null)"
fi

# pyenv - Python version manager
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - zsh)"
    # If you use pyenv-virtualenv
    # eval "$(pyenv virtualenv-init - zsh)"
  fi
fi

# Ruby Gems
export GEM_HOME="$HOME/gems"
export PATH="$HOME/gems/bin:$PATH"

# Neovim (if installed to /opt)
if [[ -d "/opt/nvim-linux-x86_64/bin" ]]; then
  export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
fi

# -----------------------------
# Aliases
# -----------------------------
alias history='fc -il 1'
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls -lh'
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts (if you use git)
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

# System
alias update="sudo apt-get update && sudo apt-get upgrade -y"
alias df='df -h'
alias du='du -h'

# Colors
export LS_COLORS='di=1;34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=34;43'

# -----------------------------
# Functions
# -----------------------------
# Docker functions (better than long aliases)
docker-restart-hard() {
  sudo docker system prune -f -a && \
  sudo docker volume prune -f -a && \
  sudo docker compose down && \
  sudo docker system prune -f && \
  sudo docker compose build && \
  sudo docker compose up --watch
}

docker-restart() {
  sudo docker compose down && \
  sudo docker system prune -f && \
  sudo docker compose up --build --watch && \
  sleep 5 && \
  curl localhost:3000
}

# Make directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar x "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Project-specific formatting (if the path exists)
formatting() {
  local script_path="$HOME/MAPPy/dev/llm-engine/scripts/pass_lint.sh"
  if [[ -f "$script_path" ]]; then
    local original_dir=$(pwd)
    cd "$(dirname "$script_path")" && "$script_path" && cd "$original_dir"
  else
    echo "Formatting script not found at $script_path"
  fi
}

# -----------------------------
# Additional Tools
# -----------------------------
# The Fuck - corrects previous command
if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias)"
fi

# Spell checking
setopt CORRECT
setopt CORRECT_ALL

