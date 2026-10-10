# Declarative Zsh and Starship companion to vesly-motd.nix
{ pkgs, lib, ... }:
let
  handoff = ''
    case $- in
      *i*)
        if [ -n "''${SSH_TTY:-}" ] && [ -t 0 ] && [ -t 1 ] && [ -z "''${SSH_ORIGINAL_COMMAND:-}" ] && [ -z "''${VESLY_SHELL_SWITCHED:-}" ]; then
          export VESLY_SHELL_SWITCHED=1
          exec ${pkgs.zsh}/bin/zsh -l
        fi
        ;;
    esac
  '';
  zshHook = ''
    if [[ -o interactive && -t 0 && -t 1 && -n "''${SSH_TTY:-}" && "''${TERM:-}" != dumb && -z "''${VESLY_SHELL_ACTIVATED:-}" ]]; then
      export VESLY_SHELL_ACTIVATED=1
      function _vesly_theme_size {
        if (( COLUMNS < 55 )); then
          export STARSHIP_CONFIG=/etc/vesly-shell/mobile-compact.toml
        elif (( COLUMNS < 90 )); then
          export STARSHIP_CONFIG=/etc/vesly-shell/mobile.toml
        else
          export STARSHIP_CONFIG=/etc/vesly-shell/desktop.toml
        fi
      }
      _vesly_theme_size
      eval "$(${pkgs.starship}/bin/starship init zsh)"
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _vesly_theme_size
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#9b79c6'
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    fi
  '';
in {
  programs.zsh.enable = true;
  environment.systemPackages = [ pkgs.zsh pkgs.starship pkgs.zsh-autosuggestions pkgs.zsh-syntax-highlighting ];
  environment.etc."vesly-shell/desktop.toml".source = ../shell/desktop.toml;
  environment.etc."vesly-shell/mobile.toml".source = ../shell/mobile.toml;
  environment.etc."vesly-shell/mobile-compact.toml".source = ../shell/mobile-compact.toml;
  programs.bash.interactiveShellInit = lib.mkAfter handoff;
  programs.zsh.interactiveShellInit = lib.mkAfter zshHook;
}
