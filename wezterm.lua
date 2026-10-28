-- WezTerm configuration. Linked to ~/.config/wezterm/wezterm.lua by install.sh.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- install.sh installs this Nerd Font; p10k and nvim icons need it.
config.font = wezterm.font_with_fallback { 'Mononoki Nerd Font', 'monospace' }
config.font_size = 12.0

-- tmux (auto-started by zshrc) already provides tabs, so hide WezTerm's.
config.hide_tab_bar_if_only_one_tab = true

config.window_padding = { left = 4, right = 4, top = 4, bottom = 0 }

-- No title bar. 'RESIZE' would keep resizable borders, but on Wayland it can
-- leave a blank strip where the title bar was.
config.window_decorations = 'NONE'

config.window_background_opacity = 0.9
config.macos_window_background_blur = 20

return config
