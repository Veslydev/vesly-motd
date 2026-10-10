#!/usr/bin/env bash
# Install or reconcile the integrated shell. Invoked by the MOTD installer and updater.
set -Eeuo pipefail
[[ $(id -u) -eq 0 ]] || { echo '[vesly-shell] Run as root' >&2; exit 1; }
SOURCE_DIR="${1:?Pass shell/ source path}"
STATE=/etc/vesly-shell
TRACKED=/var/lib/vesly-motd
for filename in install.sh uninstall.sh activate.zsh bash-switch.sh desktop.toml mobile.toml; do
    [[ -f "$SOURCE_DIR/$filename" ]] || { echo "[vesly-shell] Missing $filename" >&2; exit 1; }
done
[[ -f /etc/os-release ]] && . /etc/os-release
if [[ "${ID:-}" == nixos ]]; then
    echo '[vesly-shell] NixOS uses the declarative NixOS module; skipping mutable hooks.'
    exit 0
fi
[[ -x /usr/bin/zsh && -x "$STATE/starship" && -f "$STATE/install.sh" ]] &&
[[ -f /etc/zsh/zlogin ]] && grep -q '^# BEGIN VESLY-SHELL MANAGED$' /etc/zsh/zlogin &&
cmp -s "$SOURCE_DIR/install.sh" "$STATE/install.sh" ||
    bash "$SOURCE_DIR/install.sh"

# Parse test all shell assets before updating any live source.
bash -n "$SOURCE_DIR/install.sh"
bash -n "$SOURCE_DIR/uninstall.sh"
sh -n "$SOURCE_DIR/bash-switch.sh"
zsh -n "$SOURCE_DIR/activate.zsh"
for filename in desktop.toml mobile.toml; do
    STARSHIP_CONFIG="$SOURCE_DIR/$filename" "$STATE/starship" prompt --status=0 --path=/ >/dev/null 2>&1 ||
        { echo "[vesly-shell] Invalid Starship config: $filename" >&2; exit 1; }
done
for filename in install.sh uninstall.sh activate.zsh bash-switch.sh desktop.toml mobile.toml; do
    if [[ ! -f "$STATE/$filename" ]] || ! cmp -s "$SOURCE_DIR/$filename" "$STATE/$filename"; then
        [[ ! -f "$STATE/$filename" ]] || cp -p "$STATE/$filename" "$STATE/$filename.previous"
        new="$STATE/.$filename.$$"
        install -m 0644 "$SOURCE_DIR/$filename" "$new"
        if [[ "$filename" == install.sh || "$filename" == uninstall.sh ]]; then chmod 0755 "$new"; fi
        mv -f "$new" "$STATE/$filename"
        echo "[vesly-shell] Updated $filename"
    fi
done
mkdir -p "$TRACKED"
touch "$TRACKED/.shell-installed"
echo '[vesly-shell] Shell module synchronized.'
