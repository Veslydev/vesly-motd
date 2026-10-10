# Vesly MOTD

A purple gradient SSH welcome screen with an image-derived logo, stars and live node information. Python standard library only. Made by Vesly Cloud Labs.

## Features

- Adaptive logo layout, including a wide logo on 24-row terminals if width allows.
- Shows once per interactive SSH shell for all users. Skips SCP, SFTP, rsync and non-interactive commands.
- Global Bash, Zsh and Fish support on conventional Linux systems.
- Backups of existing MOTD, and rollback installer.
- Daily GitHub auto-updates via systemd timer. Only renderer and updater code is replaced, not SSH/PAM settings.
- Manual: vesly; detailed mode: vesly --full; update check: sudo vesly-update.

## One-line Debian / Ubuntu / Proxmox install

~~~sh
sudo apt-get update && sudo apt-get install -y git python3 && VESLY_DIR=$(mktemp -d) && git clone --depth 1 https://github.com/Veslydev/vesly-motd.git "$VESLY_DIR/vesly-motd" && sudo sh "$VESLY_DIR/vesly-motd/install.sh"
~~~

Reconnect with an interactive SSH TTY to see the MOTD and the Starship prompt. Existing MOTD nodes can run sudo vesly-update to add the shell automatically; no other installer is needed.

MOTD only opt-out: run the parent installer with VESLY_INSTALL_SHELL=0, or create /var/lib/vesly-motd/.shell-opt-out to prevent the scheduled updater from adding the shell.

### Update / remove

~~~sh
sudo vesly-update
systemctl status vesly-motd-update.timer
sudo sh /var/lib/vesly-motd/uninstall.sh
~~~

To opt out of automatic updates: sudo env VESLY_AUTO_UPDATE=0 sh ./install.sh

## NixOS

Do not modify generated PAM or /etc files manually. Import the module:

~~~sh
sudo git clone --depth 1 https://github.com/Veslydev/vesly-motd.git /etc/nixos/vesly-motd
sudo sh /etc/nixos/vesly-motd/install.sh
~~~

Add the following to /etc/nixos/configuration.nix:

~~~nix
imports = [ ./vesly-motd/nixos/vesly-motd.nix ];
~~~

Then run sudo nixos-rebuild switch. The NixOS module includes declarative Zsh/Starship hooks and a systemd timer. On NixOS the updater refreshes only the renderer; it does not rebuild system config. Any PAM-generated MOTD should be disabled using nixpkgs options for your version. NixOS rebuild has not yet been tested on a live machine.

## Requirements and OS support

Renderer: Python 3 standard library (3.10+ recommended), no pip modules. Optional tools: ip, hostnamectl, dpkg-query, tailscale, systemd-detect-virt. Installer and updater require Git and HTTPS. Debian, Ubuntu and Proxmox support conventional mutable system-wide Bash/Zsh configuration, with only optional session pam_motd lines commented. SSH credentials, authorized_keys and the SSH daemon are never changed/restarted. Other Linux distributions might need custom hooks.

## Paths

- Renderer: /var/lib/vesly-motd/vesly
- Updater: /var/lib/vesly-motd/update.sh
- Commands: /usr/local/bin/vesly and /usr/local/bin/vesly-update
- Backups: /var/lib/vesly-motd/backups
- Prior renderer: /var/lib/vesly-motd/vesly.previous
- Daily timer: vesly-motd-update.timer

## Security

Updates trust HTTPS-delivered code from github.com/Veslydev/vesly-motd. GitHub repo write access effectively allows root code execution on nodes with auto-updates enabled. Review and protect repository permissions, or pin and disable automatic updates on sensitive hosts. The updater validates syntax and atomically replaces code, but never runs install.sh automatically. Existing PAM settings are not rewritten by automatic updates.

MIT License.
