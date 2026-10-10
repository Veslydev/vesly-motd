{ pkgs, lib, ... }:
let
  renderer = "/var/lib/vesly-motd/vesly";
  updater = "/var/lib/vesly-motd/update.sh";
  shellHook = ''
    case $- in
      *i*)
        if [ -n "''${SSH_TTY:-}" ] && [ -t 1 ] && [ -z "''${VESLY_MOTD_SHOWN:-}" ] && [ -z "''${SSH_ORIGINAL_COMMAND:-}" ]; then
          export VESLY_MOTD_SHOWN=1
          ${pkgs.python3}/bin/python3 ${renderer} || true
        fi
        ;;
    esac
  '';
in
{
  imports = [ ./vesly-shell.nix ];
  environment.systemPackages = [
    pkgs.git pkgs.python3
    (pkgs.writeShellScriptBin "vesly" ''
      exec ${pkgs.python3}/bin/python3 ${renderer} "$@"
    '')
    (pkgs.writeShellScriptBin "vesly-update" ''
      exec ${pkgs.bash}/bin/bash ${updater} "$@"
    '')
  ];
  services.openssh.settings.PrintMotd = false;
  environment.etc."motd".text = "";
  programs.bash.interactiveShellInit = lib.mkAfter shellHook;
  programs.zsh.interactiveShellInit = lib.mkAfter shellHook;
  programs.fish.interactiveShellInit = lib.mkAfter ''
    if status is-interactive; and test -n "$SSH_TTY"; and test -t 1; and not set -q VESLY_MOTD_SHOWN; and not set -q SSH_ORIGINAL_COMMAND
      set -gx VESLY_MOTD_SHOWN 1
      ${pkgs.python3}/bin/python3 ${renderer}
    end
  '';
  systemd.services.vesly-motd-update = {
    description = "Update Vesly Cloud Labs MOTD renderer from GitHub";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.git pkgs.python3 pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.openssh pkgs.cacert ];
    serviceConfig.Type = "oneshot";
    script = ''
      if [ -r ${updater} ]; then
        ${pkgs.bash}/bin/bash ${updater}
      fi
    '';
  };
  systemd.timers.vesly-motd-update = {
    description = "Daily GitHub update check for Vesly MOTD";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
