# -----------------------------
# Powerlevel10k Instant Prompt
# -----------------------------
# This must be at the very top. No output before this line.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------
# Homebrew (macOS)
# -----------------------------
# Nothing Homebrew installs is on PATH until `brew shellenv` runs, and on Apple
# Silicon brew lives in /opt/homebrew, which is not on the default PATH at all.
# Must run before compinit so brew's completions land in FPATH.
if [[ "$OSTYPE" == darwin* ]] && ! (( $+commands[brew] )); then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$_brew" ]]; then
      eval "$("$_brew" shellenv)"
      break
    fi
  done
  unset _brew
fi

# -----------------------------
# History Settings
# -----------------------------
HISTDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
mkdir -p "$HISTDIR"
export HISTFILE="$HISTDIR/history"
# Zsh loads the whole history into memory at startup and SHARE_HISTORY re-reads
# it on every command, so a huge value costs real startup time for no benefit.
export HISTSIZE=100000
export SAVEHIST=$HISTSIZE

# Migrate history if needed
if [[ -f ~/.hist_zsh ]] && [[ -s ~/.hist_zsh ]]; then
  if [[ ! -f "$HISTFILE" ]] || [[ $(wc -l < "$HISTFILE" 2>/dev/null || echo 0) -lt 10 ]]; then
    cp ~/.hist_zsh "$HISTFILE" 2>/dev/null
  fi
fi

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE     # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS    # tidy up whitespace before storing
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd)

# -----------------------------
# Shell Options
# -----------------------------
setopt autocd
setopt extendedglob
setopt nomatch
setopt notify
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CDABLE_VARS
unsetopt beep

# Vi mode
bindkey -v
export KEYTIMEOUT=1
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word

# Cursor shape handling
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]]; then
    echo -ne '\e[1 q' # Block
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]]; then
    echo -ne '\e[5 q' # Beam
  fi
  zle reset-prompt
}
zle -N zle-keymap-select

zle-line-init() {
  echo -ne '\e[5 q'
  zle reset-prompt
}
zle -N zle-line-init

# -----------------------------
# Colors
# -----------------------------
# Drives GNU ls and, via the list-colors zstyle below, zsh's completion menu.
# Harmless on macOS: BSD ls ignores it and uses -G instead.
export LS_COLORS='di=1;34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=34;43'

# -----------------------------
# Completion Setup
# -----------------------------
COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
zstyle :compinstall filename "$HOME/.zshrc"

autoload -Uz compinit
if [[ -n ${COMPDUMP}(#qN.mh+24) ]]; then
  compinit -d "$COMPDUMP"
else
  compinit -C -d "$COMPDUMP"
fi

# Completion behaviour. Without these, completion is stock zsh: case-sensitive,
# no menu, no colors.
#   1. lowercase matches uppercase (cd doc -> Documents)
#   2. match after . _ - separators  (f.b -> foo.bar)
#   3. substring match anywhere      (bar -> foobar)
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# fzf-tab needs the built-in menu off so it can capture the candidate list.
zstyle ':completion:*' menu no
# Group candidates by kind; fzf-tab renders the description as a group header.
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
# Keep option lists in documented order instead of sorting them alphabetically.
zstyle ':completion:complete:*:options' sort false
# Cache the slow completions (apt, docker, systemctl).
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
# fzf-tab: cycle between groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# -----------------------------
# Zinit Plugin Manager
# -----------------------------
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
  # Silence output during installation check
  command mkdir -p "$HOME/.local/share/zinit" && chmod g-rwX "$HOME/.local/share/zinit"
  command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" >/dev/null 2>&1
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

# Plugins
zinit ice depth=1; zinit light romkatv/powerlevel10k

# FZF: the binary comes from the system package or this plugin; the shell
# integration (Ctrl-R history, Ctrl-T files, Alt-C cd) comes from `fzf --zsh`,
# which replaces the old hunt through ~/.fzf and the plugin's shell/ directory.
zinit ice depth=1
zinit light junegunn/fzf
if [[ -o interactive ]] && (( $+commands[fzf] )); then
  source <(fzf --zsh) 2>/dev/null
fi

# fzf-tab routes *all* tab completion through fzf. Load order is fussy: it must
# come after compinit, after `fzf --zsh` (whose completion.zsh also binds Tab
# and would otherwise win), and before anything that wraps ZLE widgets such as
# zsh-autosuggestions or fast-syntax-highlighting.
zinit ice depth=1; zinit light Aloxaf/fzf-tab

zinit ice depth=1; zinit light zsh-users/zsh-autosuggestions
zinit ice wait'0' lucid; zinit load zdharma-continuum/fast-syntax-highlighting
zinit ice wait'0' lucid; zinit load rupa/z

# Ensure vi-fetch-history widget exists so fzf Ctrl-R works on distros missing it
if [[ -o interactive ]]; then
  zmodload zsh/zle 2>/dev/null || true
  if typeset -p widgets &>/dev/null && (( ! ${+widgets[vi-fetch-history]} )); then
    vi-fetch-history() {
      if (( NUMERIC <= 0 )); then
        return 1
      fi
      local _fzf_hist_line
      _fzf_hist_line=$(fc -ln "$NUMERIC" "$NUMERIC" 2>/dev/null) || return 1
      BUFFER="$_fzf_hist_line"
      CURSOR=${#BUFFER}
    }
    zle -N vi-fetch-history
  fi
fi

# -----------------------------
# Powerlevel10k Config
# -----------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# -----------------------------
# PATH & Environment Tools
# -----------------------------
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# fnm (Fast Node Manager) - Silenced stderr
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
    # FIXED: "init - zsh" often causes issues or "unknown option".
    # Using "init -" is standard. Added 2>/dev/null to silence errors.
    eval "$(pyenv init - 2>/dev/null)"
  fi
fi

# Ruby Gems
export GEM_HOME="$HOME/gems"
export PATH="$HOME/gems/bin:$PATH"

# -----------------------------
# Aliases
# -----------------------------
alias history='fc -il 1'
if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'            # BSD ls has no --color
else
  alias ls='ls --color=auto'
fi
alias ll='ls -lh'
alias la='ls -lah'
alias l='ls -lh'
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias j='z'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias lg='lazygit'

if [[ "$OSTYPE" == darwin* ]]; then
  alias update='brew update && brew upgrade'
else
  alias update='sudo apt-get update && sudo apt-get upgrade -y'
fi
alias df='df -h'
alias du='du -h'

# -----------------------------
# Functions
# -----------------------------
unalias docker-restart-hard 2>/dev/null || true
docker-restart-hard() {
  sudo docker system prune -f -a && \
  sudo docker volume prune -f -a && \
  sudo docker compose down && \
  sudo docker system prune -f && \
  sudo docker compose build && \
  sudo docker compose up --watch
}

unalias docker-restart 2>/dev/null || true
docker-restart() {
  sudo docker compose down && \
  sudo docker system prune -f && \
  sudo docker compose up --build --watch && \
  sleep 5 && \
  curl localhost:3000
}

mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"      ;;
      *.tar.gz)    tar xzf "$1"      ;;
      *.bz2)       bunzip2 "$1"      ;;
      *.rar)       unrar x "$1"      ;;
      *.gz)        gunzip "$1"       ;;
      *.tar)       tar xf "$1"       ;;
      *.tbz2)      tar xjf "$1"      ;;
      *.tgz)       tar xzf "$1"      ;;
      *.zip)       unzip "$1"        ;;
      *.Z)         uncompress "$1"   ;;
      *.7z)        7z x "$1"         ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# -----------------------------
# Additional Tools
# -----------------------------
export EDITOR='nvim'
export VISUAL='nvim'

# FIXED: Removed duplicate sourcing and added silence.
# If this file contains "eval $(fzf --zsh)" or similar, it might be the cause
# of the error if your installed binaries are old.
if [[ -f "$HOME/.local/bin/env" ]]; then
  source "$HOME/.local/bin/env"
fi
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/ngodshall/.docker/completions $fpath)
autoload -Uz compinit
(( ${+_comps[docker]} )) || compinit
# End of Docker CLI completions

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
