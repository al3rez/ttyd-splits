#!/bin/sh
# ttyd passes the ?arg= URL param as $1; start a login shell in that directory.
# $SHELL is not guaranteed under launchd/systemd, so fall back sensibly.
cd "${1:-$HOME}" 2>/dev/null || cd "$HOME"
exec "${SHELL:-$(command -v zsh || command -v bash || echo /bin/sh)}" -l
