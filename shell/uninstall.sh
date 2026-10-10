#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) -eq 0 ]] || { echo 'Run with sudo' >&2; exit 1; }
remove_hook() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  grep -q '^# BEGIN VESLY-SHELL MANAGED$' "$f" || return 0
  sed -i '/^# BEGIN VESLY-SHELL MANAGED$/,/^# END VESLY-SHELL MANAGED$/d' "$f"
}
remove_hook /etc/zsh/zlogin
remove_hook /etc/bash.bashrc
if [[ -f /etc/profile.d/vesly-shell.sh ]] && grep -q '^# BEGIN VESLY-SHELL MANAGED$' /etc/profile.d/vesly-shell.sh; then
  rm /etc/profile.d/vesly-shell.sh
fi
if [[ -L /usr/local/bin/vesly-shell ]] && [[ $(readlink /usr/local/bin/vesly-shell) == /etc/vesly-shell/launch.sh ]]; then
  rm /usr/local/bin/vesly-shell
fi
rm -rf /etc/vesly-shell
printf '[vesly-shell] Removed managed hooks; Zsh packages kept.\n'
printf '[vesly-shell] Backups retained under /var/lib/vesly-shell/backups.\n'
