# Shell-neutral guard for Bash startup. Never print a banner here.
case "$-" in *i*) ;; *) return 0 ;; esac
[ -n "${SSH_TTY:-}" ] || return 0
[ -t 0 ] && [ -t 1 ] || return 0
[ -z "${SSH_ORIGINAL_COMMAND:-}" ] || return 0
[ -z "${VESLY_SHELL_NO_AUTO:-}" ] || return 0
[ -z "${VESLY_SHELL_SWITCHED:-}" ] || return 0
[ -x /usr/bin/zsh ] || return 0
export VESLY_SHELL_SWITCHED=1
exec /usr/bin/zsh -l
