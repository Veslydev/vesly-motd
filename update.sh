#!/bin/sh
# Vesly Cloud Labs MOTD: renderer-only updater from public GitHub.
set -eu
say() { printf '%s\n' "[vesly-update] $*"; }
fail() { say "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fail 'Run as root.'
command -v git >/dev/null 2>&1 || fail 'git is required.'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required.'
STATE=/var/lib/vesly-motd
SOURCE=https://github.com/Veslydev/vesly-motd.git
mkdir -p "$STATE"
chmod 0755 "$STATE"
LOCK="$STATE/.updating"
mkdir "$LOCK" 2>/dev/null || fail 'Another updater is running.'
TMP=
cleanup() {
    [ -z "$TMP" ] || rm -rf "$TMP"
    rmdir "$LOCK" 2>/dev/null || :
}
trap cleanup EXIT HUP INT TERM
TMP=$(mktemp -d "$STATE/.staging.XXXXXXXX")
# HTTPS enforces origin validation; never disable certificate verification.
git -c advice.detachedHead=false clone -q --depth 1 --single-branch --branch main "$SOURCE" "$TMP/repo" || fail 'GitHub fetch failed; current version preserved.'
[ -f "$TMP/repo/vesly" ] && [ -f "$TMP/repo/update.sh" ] || fail 'Unexpected repository structure.'
python3 -m py_compile "$TMP/repo/vesly" || fail 'Downloaded renderer failed syntax check.'
COMMIT=$(git -C "$TMP/repo" rev-parse HEAD)
OLD=none
if [ -f "$STATE/vesly" ]; then OLD=$(sha256sum "$STATE/vesly" | cut -d ' ' -f 1); fi
NEW=$(sha256sum "$TMP/repo/vesly" | cut -d ' ' -f 1)
if [ "$OLD" = "$NEW" ]; then
    say "Renderer unchanged ($COMMIT)."
else
    if [ -f "$STATE/vesly" ]; then cp -p "$STATE/vesly" "$STATE/vesly.previous"; fi
    install -m 0755 "$TMP/repo/vesly" "$STATE/.vesly.next.$$"
    mv -f "$STATE/.vesly.next.$$" "$STATE/vesly"
    say "Updated renderer to $COMMIT."
fi
# Updating this utility does not rerun the installer or change SSH/PAM settings.
sh -n "$TMP/repo/update.sh" || fail 'Downloaded updater shell validation failed.'
install -m 0755 "$TMP/repo/update.sh" "$STATE/.update.next.$$"
mv -f "$STATE/.update.next.$$" "$STATE/update.sh"
printf '%s\n' "$COMMIT" > "$STATE/.version.next.$$"
mv -f "$STATE/.version.next.$$" "$STATE/version"
