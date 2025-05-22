#!/bin/bash

# Symlink dotfiles
ln -sf "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
ln -sf "$HOME/dotfiles/p10k.zsh" "$HOME/.p10k.zsh"

# Ensure Zinit is installed
if [ ! -d "$HOME/.local/share/zinit/zinit.git" ]; then
  echo "Installing Zinit..."
  mkdir -p "$HOME/.local/share/zinit"
  git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"
fi

# Ensure fzf is installed
if [ ! -d "$HOME/.fzf" ]; then
  echo "Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --key-bindings --completion --no-update-rc
fi


# Activate new zshrc
source ~/.zshrc