# Loaded system-wide *after* user ~/.zshrc by /etc/zsh/zlogin.
[[ -o interactive ]] || return 0
[[ -t 0 && -t 1 ]] || return 0
[[ -n "${SSH_TTY:-}" || -n "${VESLY_SHELL_FORCE:-}" ]] || return 0
[[ "${TERM:-}" != dumb ]] || return 0
[[ -z "${VESLY_SHELL_ACTIVATED:-}" ]] || return 0
export VESLY_SHELL_ACTIVATED=1

autoload -Uz compinit
if ! typeset -f compdef >/dev/null 2>&1; then
  compinit -C 2>/dev/null || :
fi
setopt HIST_IGNORE_SPACE HIST_IGNORE_DUPS 2>/dev/null

_vesly_theme_size() {
  if (( COLUMNS < 90 )); then
    export STARSHIP_CONFIG=/etc/vesly-shell/mobile.toml
  else
    export STARSHIP_CONFIG=/etc/vesly-shell/desktop.toml
  fi
}
_vesly_theme_size
if [[ -x /etc/vesly-shell/starship ]]; then
  eval "$(/etc/vesly-shell/starship init zsh)"
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _vesly_theme_size
fi
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#9b79c6'
fi
# Syntax highlighting must be loaded *last* after widget definitions.
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  ZSH_HIGHLIGHT_STYLES[command]='fg=#D19CFF'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=#D19CFF'
  ZSH_HIGHLIGHT_STYLES[path]='fg=#bdb2d3,underline'
fi
