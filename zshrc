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
clean_welcome

# -----------------------------
# Powerlevel10k Instant Prompt
# -----------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------
# History Settings
# -----------------------------
export HISTFILE=~/.hist_zsh
export HISTSIZE=5000000
export SAVEHIST=$HISTSIZE

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# -----------------------------
# Shell Options
# -----------------------------
setopt autocd extendedglob nomatch notify
unsetopt beep
bindkey -e

# -----------------------------
# Completion Setup
# -----------------------------
zstyle :compinstall filename '/home/godshall/.zshrc'
autoload -Uz compinit
compinit

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
# Aliases
# -----------------------------
alias history='fc -il 1'
alias docker-restart-hard="sudo docker system prune -f -a && sudo docker volume prune -f -a && sudo docker compose down && sudo docker system prune -f && sudo docker compose build && sudo docker compose up --watch"
alias docker-restart="sudo docker compose down && sudo docker system prune -f && sudo docker compose up --build --watch && sleep 5 && curl localhost:3000"
alias formatting="cd ~/MAPPy/dev/llm-engine/scripts/ && ~/MAPPy/dev/llm-engine/scripts/pass_lint.sh && cd -"
alias update="sudo apt-get update && sudo apt-get upgrade -y"
alias ls='ls --color=auto'
export LS_COLORS='di=1;34:ln=36:so=32:pi=33:ex=31:bd=34;46:cd=34;43'

# -----------------------------
# fnm Setup
# -----------------------------
FNM_PATH="/home/godshall/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="/home/godshall/.local/share/fnm:$PATH"
  eval "`fnm env`"
fi


# To customize prompt, run `p10k configure` or edit ~/dotfiles/p10k.zsh.
[[ ! -f ~/dotfiles/p10k.zsh ]] || source ~/dotfiles/p10k.zsh
