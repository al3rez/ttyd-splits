# ttyd-splits

Terminator-style terminal tabs and splits in the browser, running on your own
machine and reachable **only over your [Tailscale](https://tailscale.com) network**.
One dependency-free HTML file on top of [ttyd](https://github.com/tsl0922/ttyd).

Open `https://<machine>.<tailnet>.ts.net/splits` from a laptop, tablet, or
phone anywhere, and you get your dev box's real shells — with tabs, splittable
panes, and keyboard bindings you know from Terminator. Survives reboots
(launchd on macOS, systemd user units on Linux).

```
your browser ──▶ https://<machine>.<tailnet>.ts.net
                        │  tailscale serve (tailnet-only TLS, WireGuard underneath)
                        ├── /        ─▶ 127.0.0.1:7681  ttyd (terminal over WebSocket)
                        └── /splits  ─▶ 127.0.0.1:7690  python http.server (this UI)
```

The UI page iframes ttyd once per pane; both live on the same tailnet origin,
so no CORS, no auth plumbing, no build step, no JavaScript dependencies.

## Install

Prereqs: [Tailscale](https://tailscale.com/download) logged in on the machine
and on whatever device you'll browse from. `ttyd` is installed automatically
via Homebrew on macOS; on Linux install it first (`sudo apt install ttyd`).

```sh
git clone https://github.com/al3rez/ttyd-splits
cd ttyd-splits
./install.sh
```

The installer:

1. copies `index.html` + `shell.sh` to `~/.ttyd-splits/`
2. sets up two always-on services bound to **127.0.0.1 only**:
   - `ttyd` (port `7681`) — the terminal server
   - `python3 -m http.server` (port `7690`) — serves the UI
   (launchd agents on macOS, systemd user units on Linux)
3. runs `tailscale serve` to map `/` → ttyd and `/splits` → the UI over
   tailnet-only HTTPS

Then open **`https://<machine>.<tailnet>.ts.net/splits`** — the installer
prints the exact URL. Ports are configurable: `TTYD_PORT=8681 UI_PORT=8690 ./install.sh`.

On Linux, run `sudo loginctl enable-linger $USER` if you want the services up
without an active login session.

## Keybindings

| Keys | Action |
|---|---|
| `Ctrl+Shift+E` | split horizontally (side by side) |
| `Ctrl+Shift+O` | split vertically (stacked) |
| `Ctrl+Shift+W` | close focused pane (last pane closes the tab) |
| `Ctrl+Shift+T` | new tab |
| `Ctrl+Shift+←` / `→` | previous / next tab |
| `Ctrl+Shift+N` | new browser window |
| middle-click a tab | close it |

Tabs get random `adjective-animal` names. Click a pane to focus it (orange
ring); shortcuts work while a terminal has focus.

## Customize

Edit `~/.ttyd-splits/index.html` and reload the page (no service restart needed):

- **`DIRS`** (top of the script) — list of starting directories. The first tab
  opens one pane per entry, in rows of up to 3 — list 6 projects and you get a
  2×3 grid of shells, one per project. New splits/tabs open in the last entry.
  Empty list = single pane in `$HOME`.
- Terminal font/size live in the service definition (`-t fontFamily=...`,
  `-t fontSize=...` in `~/Library/LaunchAgents/local.ttyd.plist` or the
  systemd unit) — see `ttyd --help` for all client options.
- `~/.ttyd-splits/shell.sh` decides what runs in each pane (default: your
  login shell in the requested directory).

Re-running `./install.sh` is idempotent; it backs up a customized `index.html`
to `index.html.bak` before overwriting.

## Security model

This is **an unauthenticated, writable shell as your user**. It is safe only
because of how it's exposed:

- Both servers bind to `127.0.0.1` — nothing listens on your LAN.
- The only route in is `tailscale serve`, which is **tailnet-only**: devices
  must be authenticated to *your* Tailscale network. Anyone on your tailnet
  gets a shell, so this assumes a personal/trusted tailnet.
- **Never** expose it with `tailscale funnel` (public internet). Don't.
- For extra protection, restrict which tailnet devices can reach these ports
  with [Tailscale ACLs](https://tailscale.com/kb/1018/acls).

## Uninstall

```sh
./uninstall.sh          # removes services + tailscale serve paths
rm -rf ~/.ttyd-splits   # optional: remove UI files too
```

## License

MIT
