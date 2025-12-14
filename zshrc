# -----------------------------
# Powerlevel10k Instant Prompt
# -----------------------------
# This must be at the very top. No output before this line.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------
# History Settings
# -----------------------------
HISTDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
mkdir -p "$HISTDIR"
export HISTFILE="$HISTDIR/history"
export HISTSIZE=5000000
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
setopt HIST_IGNORE_SPACE
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
zinit ice depth=1; zinit light zsh-users/zsh-autosuggestions
zinit ice wait'0' lucid; zinit load zdharma-continuum/fast-syntax-highlighting
zinit ice wait'0' lucid; zinit load rupa/z

# FZF integration: ensure binary is in PATH and hotkeys/completions are sourced exactly once
zinit ice depth=1
zinit light junegunn/fzf

FZF_BASE="${FZF_BASE:-$HOME/.fzf}"
if [[ -d "$FZF_BASE/bin" ]] && [[ ":$PATH:" != *":$FZF_BASE/bin:"* ]]; then
  export PATH="$FZF_BASE/bin:$PATH"
fi

if [[ -o interactive ]]; then
  _fzf_shell_dirs=()
  if [[ -d "$FZF_BASE/shell" ]]; then
    _fzf_shell_dirs+=("$FZF_BASE/shell")
  fi
  if typeset -p ZINIT &>/dev/null; then
    _zinit_base="${ZINIT[HOME_DIR]}"
  elif [[ -n ${ZINIT_HOME:-} ]]; then
    _zinit_base="$ZINIT_HOME"
  else
    _zinit_base="$HOME/.local/share/zinit"
  fi
  if [[ -n "$_zinit_base" ]] && [[ -d "$_zinit_base/plugins/junegunn---fzf/shell" ]]; then
    _fzf_shell_dirs+=("$_zinit_base/plugins/junegunn---fzf/shell")
  fi

  _fzf_key_bindings_loaded=0
  _fzf_completion_loaded=0

  for _fzf_dir in "${_fzf_shell_dirs[@]}"; do
    if (( !_fzf_key_bindings_loaded )) && [[ -f "$_fzf_dir/key-bindings.zsh" ]]; then
      source "$_fzf_dir/key-bindings.zsh"
      _fzf_key_bindings_loaded=1
    fi
    if (( !_fzf_completion_loaded )) && [[ -f "$_fzf_dir/completion.zsh" ]]; then
      source "$_fzf_dir/completion.zsh"
      _fzf_completion_loaded=1
    fi
  done

  if (( !_fzf_key_bindings_loaded )); then
    if [[ -f "$HOME/.fzf.zsh" ]]; then
      source "$HOME/.fzf.zsh" 2>/dev/null
      _fzf_key_bindings_loaded=1
      _fzf_completion_loaded=1
    elif command -v fzf >/dev/null 2>&1; then
      source <(fzf --zsh) 2>/dev/null
      _fzf_key_bindings_loaded=1
      _fzf_completion_loaded=1
    fi
  fi

  unset _fzf_shell_dirs _fzf_dir _fzf_key_bindings_loaded _fzf_completion_loaded _zinit_base
fi

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

# Neovim
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

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

alias update="sudo apt-get update && sudo apt-get upgrade -y"
alias df='df -h'
alias du='du -h'

export LS_COLORS='di=1;34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=34;43'

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

unalias formatting 2>/dev/null || true
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
setopt CORRECT
setopt CORRECT_ALL
export EDITOR='nvim'
export VISUAL='nvim'

# FIXED: Removed duplicate sourcing and added silence.
# If this file contains "eval $(fzf --zsh)" or similar, it might be the cause
# of the error if your installed binaries are old.
if [[ -f "$HOME/.local/bin/env" ]]; then
  source "$HOME/.local/bin/env"
fi
