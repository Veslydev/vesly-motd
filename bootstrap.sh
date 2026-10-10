#!/bin/sh
# Clone and install from the official public repository.
set -eu
[ "$(id -u)" -eq 0 ] || { echo 'Run: sudo sh bootstrap.sh' >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo 'Git is required (Debian/Ubuntu: apt install git)' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required (Debian/Ubuntu: apt install python3)' >&2; exit 1; }
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT HUP INT TERM
git clone -q --depth 1 --branch main https://github.com/Veslydev/vesly-motd.git "$DIR/repo"
sh "$DIR/repo/install.sh"
