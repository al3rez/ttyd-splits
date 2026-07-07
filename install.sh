#!/usr/bin/env bash
# ttyd-splits installer: ttyd + splits UI as always-on services, exposed
# tailnet-only via `tailscale serve`.
#
#   TTYD_PORT (default 7681)  ttyd terminal server, bound to 127.0.0.1
#   UI_PORT   (default 7690)  static server for the splits UI, bound to 127.0.0.1
set -euo pipefail

TTYD_PORT="${TTYD_PORT:-7681}"
UI_PORT="${UI_PORT:-7690}"
DEST="$HOME/.ttyd-splits"
SRC="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

say() { printf '\033[1m%s\033[0m\n' "$*"; }

# ---- dependencies ----------------------------------------------------------
if ! command -v ttyd >/dev/null 2>&1; then
  if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    say "Installing ttyd via Homebrew..."
    brew install ttyd
  else
    echo "error: ttyd not found. Install it first:" >&2
    echo "  macOS:  brew install ttyd" >&2
    echo "  Debian: sudo apt install ttyd" >&2
    echo "  other:  https://github.com/tsl0922/ttyd" >&2
    exit 1
  fi
fi
TTYD_BIN="$(command -v ttyd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 not found (it serves the UI via 'python3 -m http.server')" >&2
  exit 1
fi
PY_BIN="$(command -v python3)"

# ---- files -----------------------------------------------------------------
mkdir -p "$DEST"
if [ -f "$DEST/index.html" ] && ! cmp -s "$SRC/index.html" "$DEST/index.html"; then
  cp "$DEST/index.html" "$DEST/index.html.bak"
  say "Existing $DEST/index.html backed up to index.html.bak"
fi
cp "$SRC/index.html" "$DEST/index.html"
cp "$SRC/shell.sh" "$DEST/shell.sh"
chmod +x "$DEST/shell.sh"
say "Installed UI files to $DEST"

# ---- services --------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
  AGENTS="$HOME/Library/LaunchAgents"
  mkdir -p "$AGENTS"

  cat > "$AGENTS/local.ttyd.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.ttyd</string>
  <key>ProgramArguments</key>
  <array>
    <string>$TTYD_BIN</string>
    <string>--writable</string>
    <string>-a</string>
    <string>-p</string><string>$TTYD_PORT</string>
    <string>-i</string><string>127.0.0.1</string>
    <string>-t</string><string>fontFamily=Menlo, Monaco, DejaVu Sans Mono, monospace</string>
    <string>-t</string><string>fontSize=14</string>
    <string>$DEST/shell.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/ttyd.log</string>
  <key>StandardErrorPath</key><string>/tmp/ttyd.log</string>
</dict>
</plist>
EOF

  cat > "$AGENTS/local.ttyd-splits.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.ttyd-splits</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY_BIN</string>
    <string>-m</string><string>http.server</string>
    <string>$UI_PORT</string>
    <string>--bind</string><string>127.0.0.1</string>
    <string>--directory</string><string>$DEST</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/ttyd-splits.log</string>
  <key>StandardErrorPath</key><string>/tmp/ttyd-splits.log</string>
</dict>
</plist>
EOF

  launchctl unload "$AGENTS/local.ttyd.plist" 2>/dev/null || true
  launchctl unload "$AGENTS/local.ttyd-splits.plist" 2>/dev/null || true
  launchctl load "$AGENTS/local.ttyd.plist"
  launchctl load "$AGENTS/local.ttyd-splits.plist"
  say "launchd agents loaded (local.ttyd, local.ttyd-splits)"

elif [ "$OS" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
  UNITS="$HOME/.config/systemd/user"
  mkdir -p "$UNITS"

  cat > "$UNITS/ttyd-splits-term.service" <<EOF
[Unit]
Description=ttyd terminal server (ttyd-splits)
After=network.target

[Service]
ExecStart=$TTYD_BIN --writable -a -p $TTYD_PORT -i 127.0.0.1 -t "fontFamily=Menlo, Monaco, DejaVu Sans Mono, monospace" -t fontSize=14 $DEST/shell.sh
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

  cat > "$UNITS/ttyd-splits-ui.service" <<EOF
[Unit]
Description=splits UI static server (ttyd-splits)
After=network.target

[Service]
ExecStart=$PY_BIN -m http.server $UI_PORT --bind 127.0.0.1 --directory $DEST
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now ttyd-splits-term.service ttyd-splits-ui.service
  say "systemd user units enabled (ttyd-splits-term, ttyd-splits-ui)"
  echo "To keep them running when you're logged out: sudo loginctl enable-linger $USER"

else
  echo "warning: unsupported OS for service setup — start these yourself:" >&2
  echo "  $TTYD_BIN --writable -a -p $TTYD_PORT -i 127.0.0.1 $DEST/shell.sh" >&2
  echo "  $PY_BIN -m http.server $UI_PORT --bind 127.0.0.1 --directory $DEST" >&2
fi

# ---- tailscale serve ---------------------------------------------------------
TS=""
if command -v tailscale >/dev/null 2>&1; then
  TS="tailscale"
elif [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
  TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

if [ -n "$TS" ]; then
  say "Configuring tailscale serve (tailnet-only)..."
  "$TS" serve --bg --set-path=/ "http://127.0.0.1:$TTYD_PORT"
  "$TS" serve --bg --set-path=/splits "http://127.0.0.1:$UI_PORT"
  echo
  "$TS" serve status || true
  HOST="$("$TS" status --json 2>/dev/null | "$PY_BIN" -c \
    'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' \
    2>/dev/null || true)"
  echo
  if [ -n "$HOST" ]; then
    say "Done. Open https://$HOST/splits from any device on your tailnet."
  else
    say "Done. Open https://<this-machine>.<your-tailnet>.ts.net/splits"
  fi
  echo "NEVER expose this via 'tailscale funnel' — it is an unauthenticated shell."
else
  echo "warning: tailscale CLI not found — services are running on localhost only." >&2
  echo "Install Tailscale (https://tailscale.com/download), then run:" >&2
  echo "  tailscale serve --bg --set-path=/ http://127.0.0.1:$TTYD_PORT" >&2
  echo "  tailscale serve --bg --set-path=/splits http://127.0.0.1:$UI_PORT" >&2
fi
