#!/usr/bin/env bash
# Vesly Cloud Labs — Zsh/Starship for interactive SSH only.
set -Eeuo pipefail
[[ $(id -u) -eq 0 ]] || { echo 'Run with sudo bash install.sh' >&2; exit 1; }
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
STATE=/etc/vesly-shell
BACKUP=/var/lib/vesly-shell/backups
for f in activate.zsh bash-switch.sh desktop.toml mobile.toml uninstall.sh; do
  [[ -f "$ROOT/$f" ]] || { echo "Missing $f" >&2; exit 1; }
done
[[ -r /etc/os-release ]] && . /etc/os-release
if [[ "${ID:-}" == nixos ]]; then
  echo 'NixOS is declarative. Do not use this mutable installer.' >&2; exit 2
fi
if ! command -v apt-get >/dev/null; then
  echo 'Supported installer: Debian / Ubuntu / Proxmox (apt).' >&2; exit 2
fi
# Stop on collisions before making changes.
[[ ! -e /etc/profile.d/vesly-shell.sh ]] || grep -q '^# BEGIN VESLY-SHELL MANAGED$' /etc/profile.d/vesly-shell.sh || { echo 'Conflicting /etc/profile.d/vesly-shell.sh' >&2; exit 1; }
[[ ! -e /usr/local/bin/vesly-shell ]] || { [[ -L /usr/local/bin/vesly-shell && $(readlink /usr/local/bin/vesly-shell) == /etc/vesly-shell/launch.sh ]] || { echo 'Conflicting /usr/local/bin/vesly-shell' >&2; exit 1; }; }
export DEBIAN_FRONTEND=noninteractive
printf '[vesly-shell] Installing Zsh and plugins...\n'
apt-get update -qq
apt-get install -y --no-install-recommends zsh zsh-autosuggestions zsh-syntax-highlighting curl ca-certificates
for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -f "$f" ]] || { echo "Missing plugin: $f" >&2; exit 1; }
done
# Pin binary AND checksum, independently checked against official v1.26.0 release.
VER=1.26.0
case "$(uname -m)" in
  x86_64|amd64) TARGET=x86_64-unknown-linux-musl; SHA=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3 ;;
  aarch64|arm64) TARGET=aarch64-unknown-linux-musl; SHA=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b ;;
  *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 2 ;;
esac
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
URL="https://github.com/starship/starship/releases/download/v${VER}/starship-${TARGET}.tar.gz"
printf '[vesly-shell] Downloading pinned Starship v%s...\n' "$VER"
curl --proto '=https' --tlsv1.2 -fLsS --retry 2 --connect-timeout 10 "$URL" -o "$TMP/starship.tar.gz"
printf '%s  %s\n' "$SHA" "$TMP/starship.tar.gz" | sha256sum -c --status || { echo 'Starship SHA-256 mismatch' >&2; exit 1; }
[[ "$(tar -tzf "$TMP/starship.tar.gz")" == starship ]] || { echo 'Unexpected archive contents' >&2; exit 1; }
tar -xzf "$TMP/starship.tar.gz" -C "$TMP" starship
"$TMP/starship" --version
mkdir -p "$STATE" "$BACKUP"
chmod 0755 "$STATE"
chmod 0700 "$BACKUP"
install -m0755 "$TMP/starship" "$STATE/starship"
for f in activate.zsh desktop.toml mobile.toml bash-switch.sh; do install -m0644 "$ROOT/$f" "$STATE/$f"; done
install -m0755 "$ROOT/uninstall.sh" "$STATE/uninstall.sh"
cat > "$STATE/launch.sh" <<'LAUNCH'
#!/bin/sh
export VESLY_SHELL_FORCE=1
exec /usr/bin/zsh -l
LAUNCH
chmod 0755 "$STATE/launch.sh"

append_hook() {
  local path="$1" value="$2" key
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]] && grep -q '^# BEGIN VESLY-SHELL MANAGED$' "$path"; then
    echo "[vesly-shell] Existing hook kept: $path"
    return
  fi
  if [[ -f "$path" ]]; then
    key="${path//\//_}"
    [[ -e "$BACKUP/$key" ]] || cp -p "$path" "$BACKUP/$key"
  fi
  printf '\n# BEGIN VESLY-SHELL MANAGED\n%s\n# END VESLY-SHELL MANAGED\n' "$value" >> "$path"
}
# zlogin runs *after* ~/.zshrc, so Oh My Zsh themes cannot overwrite Starship.
append_hook /etc/zsh/zlogin 'source /etc/vesly-shell/activate.zsh'
# Only interactive SSH Bash is redirected, never commands, rsync, SCP or SFTP.
append_hook /etc/bash.bashrc 'source /etc/vesly-shell/bash-switch.sh'
cat > /etc/profile.d/vesly-shell.sh <<'PROFILE'
# BEGIN VESLY-SHELL MANAGED
if [ -r /etc/vesly-shell/bash-switch.sh ]; then
  . /etc/vesly-shell/bash-switch.sh
fi
# END VESLY-SHELL MANAGED
PROFILE
chmod 0644 /etc/profile.d/vesly-shell.sh
ln -sfn "$STATE/launch.sh" /usr/local/bin/vesly-shell
printf '[vesly-shell] Ready. Reconnect with interactive SSH or run: vesly-shell\n'
printf '[vesly-shell] Default account login shells are unchanged; uninstall with sudo bash %s/uninstall.sh\n' "$STATE"
