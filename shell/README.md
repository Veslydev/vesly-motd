# Integrated Vesly Shell

This folder is part of Veslydev/vesly-motd. It is installed and updated automatically by the parent installer/updater.

- Zsh + distro-packaged zsh-autosuggestions and zsh-syntax-highlighting
- Starship v1.26.0, pinned to SHA-256-verified official release binaries
- Purple desktop and compact mobile prompts; no Nerd Font
- System-wide interactive SSH only. Non-interactive SSH, SFTP, SCP and CI are left unchanged
- Rollback via sudo sh /var/lib/vesly-motd/uninstall.sh
- Manual preview command: vesly-shell

sudo vesly-update also installs the shell on nodes that previously had only the MOTD. Daily updates synchronize the renderer, shell theme and updater. Changes to installer requirements may install packages, but no account login shell or sshd configuration is changed.

Set VESLY_INSTALL_SHELL=0 to opt out when running the parent installer. VESLY_SHELL_NO_AUTO=1 disables Bash-to-Zsh handoff within a session.

## Wholespace-inspired design

The desktop prompt uses purple Powerline wedges, a system/heart capsule, real sampled CPU and RAM values, a right-aligned time and Git details, plus a separate path/command line. For correct desktop wedge glyphs, select a Powerline/Nerd Font in your SSH terminal. Termius mobile uses basic Unicode wedge characters to avoid unsupported Private Use characters. The statistics script samples Linux /proc/stat for approximately 70 ms; all other theme features run normally without it.
