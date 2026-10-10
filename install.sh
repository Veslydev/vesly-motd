#!/bin/sh
# Vesly Cloud Labs MOTD installer for Debian, Ubuntu, Proxmox and other mutable Linux.
set -eu

say() { printf '%s\n' "[vesly-motd] $*"; }
fatal() { say "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fatal 'Run as root (sudo sh install.sh).'
BASE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
[ -f "$BASE/vesly" ] || fatal "Missing renderer at $BASE/vesly: clone the entire GitHub repo."
[ -f "$BASE/update.sh" ] || fatal "Missing updater: clone the entire GitHub repo."

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
else
    ID=unknown
fi
if [ "$ID" = nixos ]; then
    DEST=/var/lib/vesly-motd
    mkdir -p "$DEST"
    install -m 0755 "$BASE/vesly" "$DEST/vesly"
    install -m 0755 "$BASE/uninstall.sh" "$DEST/uninstall.sh"
    install -m 0755 "$BASE/update.sh" "$DEST/update.sh"
    say 'Renderer and updater installed. NixOS: import nixos/vesly-motd.nix, then nixos-rebuild switch.'
    say 'No changes to PAM, SSH, or shell configuration were made.'
    exit 0
fi
command -v python3 >/dev/null 2>&1 || fatal 'python3 is required; install it first.'
python3 -m py_compile "$BASE/vesly" || fatal 'Renderer failed Python syntax check.'
sh -n "$BASE/update.sh" || fatal 'Updater failed shell syntax check.'
command -v git >/dev/null 2>&1 || fatal 'git is required for GitHub auto-updates.'

STATE=/var/lib/vesly-motd
BACKUP=$STATE/backups
mkdir -p "$BACKUP"
chmod 0700 "$BACKUP"

# Install Python renderer without touching users' existing scripts.
install -m 0755 "$BASE/vesly" "$STATE/vesly"
install -m 0755 "$BASE/uninstall.sh" "$STATE/uninstall.sh"
install -m 0755 "$BASE/update.sh" "$STATE/update.sh"
if [ -e /usr/local/bin/vesly ] && [ ! -L /usr/local/bin/vesly ]; then
    if [ ! -f "$BACKUP/previous-vesly" ]; then cp -p /usr/local/bin/vesly "$BACKUP/previous-vesly"; fi
fi
if [ -L /usr/local/bin/vesly ]; then
    target=$(readlink /usr/local/bin/vesly)
    [ "$target" = "$STATE/vesly" ] || fatal "/usr/local/bin/vesly is a symlink to $target. Refusing to overwrite."
fi
ln -sf "$STATE/vesly" /usr/local/bin/vesly

# Optional manual updater command. Do not overwrite existing unrelated tools.
if [ -e /usr/local/bin/vesly-update ] && [ ! -L /usr/local/bin/vesly-update ]; then
    fatal '/usr/local/bin/vesly-update already exists and is not a symlink.'
fi
if [ -L /usr/local/bin/vesly-update ] && [ "$(readlink /usr/local/bin/vesly-update)" != "$STATE/update.sh" ]; then
    fatal 'Existing vesly-update symlink is not managed by us.'
fi
ln -sf "$STATE/update.sh" /usr/local/bin/vesly-update

# Single-render guard for login shells + nested shells. Never print for SCP, SFTP, rsync, SSH commands.
HOOK='### BEGIN VESLY-MOTD MANAGED ###
case $- in
    *i*)
        if [ -n "${SSH_TTY:-}" ] && [ -t 1 ] && [ -z "${VESLY_MOTD_SHOWN:-}" ] && [ -z "${SSH_ORIGINAL_COMMAND:-}" ]; then
            export VESLY_MOTD_SHOWN=1
            if command -v python3 >/dev/null 2>&1 && [ -r /var/lib/vesly-motd/vesly ]; then
                python3 /var/lib/vesly-motd/vesly || :
            fi
        fi
        ;;
esac
### END VESLY-MOTD MANAGED ###'

# Source on Bourne-compatible login shells, and also on non-login interactive Bash.
PROFILE=/etc/profile.d/vesly-motd.sh
if [ -e "$PROFILE" ] && ! grep -q '### BEGIN VESLY-MOTD MANAGED ###' "$PROFILE"; then
    fatal "$PROFILE already exists and isn't managed by us."
fi
printf '%s\n' "$HOOK" > "$PROFILE"
chmod 0644 "$PROFILE"

# Idempotent managed block injection, preserving unrelated system config.
add_hook() {
    file=$1
    [ -f "$file" ] || return 0
    if grep -q '### BEGIN VESLY-MOTD MANAGED ###' "$file"; then
        say "Hook already exists: $file"
        return 0
    fi
    [ -f "$BACKUP/$(printf '%s' "$file" | tr / _).original" ] || cp -p "$file" "$BACKUP/$(printf '%s' "$file" | tr / _).original"
    printf '\n%s\n' "$HOOK" >> "$file"
    say "Hook added: $file"
}
add_hook /etc/bash.bashrc
add_hook /etc/bashrc
add_hook /etc/zsh/zshrc
add_hook /etc/zshrc

# Fish uses its own syntax; check interactive state explicitly.
if [ -d /etc/fish/conf.d ]; then
    FISH=/etc/fish/conf.d/vesly-motd.fish
    if [ -e "$FISH" ] && ! grep -q '# VESLY-MOTD MANAGED' "$FISH"; then
        fatal "Refusing to overwrite unrelated $FISH"
    fi
    cat > "$FISH" <<'FISH_CODE'
# VESLY-MOTD MANAGED
if status is-interactive; and test -n "$SSH_TTY"; and test -t 1; and not set -q VESLY_MOTD_SHOWN; and not set -q SSH_ORIGINAL_COMMAND
    set -gx VESLY_MOTD_SHOWN 1
    if command -q python3; and test -r /var/lib/vesly-motd/vesly
        python3 /var/lib/vesly-motd/vesly
    end
end
FISH_CODE
    chmod 0644 "$FISH"
fi

# Old MOTD off. Backups are retained, PAM *optional session* lines only are commented.
if [ -e /etc/motd ]; then
    if [ ! -e "$BACKUP/etc-motd" ] && [ ! -e "$BACKUP/etc-motd-absent" ]; then cp -p /etc/motd "$BACKUP/etc-motd"; fi
else
    : > "$BACKUP/etc-motd-absent"
fi
: > /etc/motd
chmod 0644 /etc/motd

# Ubuntu/Debian/Proxmox PAM output includes dynamic MOTD independent of /etc/motd.
PAM=/etc/pam.d/sshd
if [ -f "$PAM" ]; then
    [ -f "$BACKUP/sshd-pam.original" ] || cp -p "$PAM" "$BACKUP/sshd-pam.original"
    sed -i -E '/^[[:space:]]*session[[:space:]]+optional[[:space:]]+pam_motd\.so/ s/^/# VESLY-MOTD DISABLED: /' "$PAM"
fi

# Daily background checks (systemd distributions). No package upgrade or SSH
# restart is performed by the timer; only renderer and updater are replaced.
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1 && [ "$(printenv VESLY_AUTO_UPDATE 2>/dev/null || printf 1)" != 0 ]; then
    for unit in vesly-motd-update.service vesly-motd-update.timer; do
        src="$BASE/systemd/$unit"
        dst="/etc/systemd/system/$unit"
        [ -f "$src" ] || fatal "Missing GitHub package asset: $src"
        if [ -e "$dst" ] && ! grep -q 'Vesly Cloud Labs MOTD' "$dst"; then
            fatal "$dst exists and is not a Vesly-managed unit."
        fi
        install -m 0644 "$src" "$dst"
    done
    systemctl daemon-reload
    systemctl enable --now vesly-motd-update.timer
    say 'Daily GitHub auto-updater enabled (systemd timer).'
else
    say 'Auto-update timer not enabled (systemd unavailable or VESLY_AUTO_UPDATE=0).'
fi

say 'Installed. Interactive SSH only, for all Bash/Zsh/Fish users.'
say 'Original MOTD and modified shell configs are backed up in /var/lib/vesly-motd/backups.'
say 'Existing SSH sessions remain untouched. Reconnect to verify.'
