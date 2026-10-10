#!/bin/sh
set -eu
say() { printf '%s\n' "[vesly-motd] $*"; }
[ "$(id -u)" -eq 0 ] || { say 'Run as root.'; exit 1; }
BASE=/var/lib/vesly-motd
B=$BASE/backups
# NixOS changes are managed declaratively; do not modify generated /etc files.
if [ -r /etc/os-release ]; then . /etc/os-release; else ID=unknown; fi
if [ "$ID" = nixos ]; then
    say 'Remove the vesly-motd.nix import from configuration.nix and run nixos-rebuild switch.'
    exit 0
fi
# Remove managed shell integration when installed through the same updater.
if [ -f "$BASE/.shell-installed" ]; then
    if [ -f /etc/vesly-shell/uninstall.sh ] && command -v bash >/dev/null 2>&1; then
        bash /etc/vesly-shell/uninstall.sh
    else
        say 'Shell uninstall unavailable; configuration retained.'
    fi
    rm -f "$BASE/.shell-installed"
fi
rm -f "$BASE/.shell-opt-out"

# Stop scheduling new updates before removing managed files.
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl disable --now vesly-motd-update.timer 2>/dev/null || :
    for unit in vesly-motd-update.service vesly-motd-update.timer; do
        file="/etc/systemd/system/$unit"
        if [ -f "$file" ] && grep -q 'Vesly Cloud Labs MOTD' "$file"; then
            rm -f "$file"
        fi
    done
    systemctl daemon-reload
fi
if [ -L /usr/local/bin/vesly-update ] && [ "$(readlink /usr/local/bin/vesly-update)" = "$BASE/update.sh" ]; then
    rm -f /usr/local/bin/vesly-update
fi
remove_block() {
    file=$1
    [ -f "$file" ] || return 0
    if grep -q '### BEGIN VESLY-MOTD MANAGED ###' "$file"; then
        sed -i '/^### BEGIN VESLY-MOTD MANAGED ###$/,/^### END VESLY-MOTD MANAGED ###$/d' "$file"
    fi
}
for f in /etc/bash.bashrc /etc/bashrc /etc/zsh/zshrc /etc/zshrc; do remove_block "$f"; done
rm -f /etc/profile.d/vesly-motd.sh
if [ -f /etc/fish/conf.d/vesly-motd.fish ] && grep -q '# VESLY-MOTD MANAGED' /etc/fish/conf.d/vesly-motd.fish; then
    rm /etc/fish/conf.d/vesly-motd.fish
fi
if [ -f /etc/pam.d/sshd ]; then
    sed -i 's/^# VESLY-MOTD DISABLED: //' /etc/pam.d/sshd
fi
if [ -f "$B/etc-motd" ]; then
    if [ ! -s /etc/motd ]; then cp -p "$B/etc-motd" /etc/motd; else say '/etc/motd changed since install; keeping current content.'; fi
elif [ -e "$B/etc-motd-absent" ] && [ ! -s /etc/motd ]; then
    rm -f /etc/motd
fi
if [ -L /usr/local/bin/vesly ] && [ "$(readlink /usr/local/bin/vesly)" = "$BASE/vesly" ]; then
    rm /usr/local/bin/vesly
    if [ -f "$B/previous-vesly" ]; then cp -p "$B/previous-vesly" /usr/local/bin/vesly; fi
fi
say 'Uninstalled. Original MOTD restored if unchanged; preserved backups at /var/lib/vesly-motd/backups.'
