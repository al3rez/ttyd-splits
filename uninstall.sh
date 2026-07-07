#!/usr/bin/env bash
# Remove ttyd-splits services and tailscale serve paths.
# Leaves ~/.ttyd-splits (your config) in place; delete it yourself if wanted.
set -uo pipefail

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  AGENTS="$HOME/Library/LaunchAgents"
  launchctl unload "$AGENTS/local.ttyd.plist" 2>/dev/null
  launchctl unload "$AGENTS/local.ttyd-splits.plist" 2>/dev/null
  rm -f "$AGENTS/local.ttyd.plist" "$AGENTS/local.ttyd-splits.plist"
  echo "launchd agents removed"
elif [ "$OS" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now ttyd-splits-term.service ttyd-splits-ui.service 2>/dev/null
  rm -f "$HOME/.config/systemd/user/ttyd-splits-term.service" \
        "$HOME/.config/systemd/user/ttyd-splits-ui.service"
  systemctl --user daemon-reload
  echo "systemd user units removed"
fi

TS=""
if command -v tailscale >/dev/null 2>&1; then
  TS="tailscale"
elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
  TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi
if [ -n "$TS" ]; then
  "$TS" serve --set-path=/ off 2>/dev/null
  "$TS" serve --set-path=/splits off 2>/dev/null
  echo "tailscale serve paths removed; current config:"
  "$TS" serve status
fi

echo "Done. ~/.ttyd-splits left in place (rm -rf it if you want a full wipe)."
