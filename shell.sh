#!/bin/sh
# ttyd passes the ?arg= URL param as $1; start a login shell in that directory
cd "${1:-$HOME}" 2>/dev/null || cd "$HOME"
exec "${SHELL:-/bin/sh}" -l
