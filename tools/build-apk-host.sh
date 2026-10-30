#!/usr/bin/env bash
#
# Build a sideloadable release APK of Toil & Troublez and host it over the
# local network.
#
#   ./tools/build-apk-host.sh              # build, then serve on 0.0.0.0:8000
#   ./tools/build-apk-host.sh --no-host    # build only, do not start the server
#   ./tools/build-apk-host.sh --port 9000  # build, then serve on port 9000
#   ./tools/build-apk-host.sh --debug      # build a debug APK instead of release
#   PORT=9000 ./tools/build-apk-host.sh    # same as --port, via env var
#
# Point a phone on the same Wi-Fi at the address this prints, tap Download, then
# open the file to install. Hosting uses Python's standard library, so the script
# needs nothing beyond Flutter, the Android SDK, and python3.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage:
  build-apk-host.sh [--no-host] [--port N] [--debug]

Builds a sideloadable APK of Toil & Troublez and serves it on
http://<your-LAN-IP>:8000 so phones on the same Wi-Fi can install it.

  --no-host     build only, do not start the server
  --port N      serve on port N (default 8000, or $PORT)
  --debug       build a debug APK instead of a release one
  -h, --help    show this help

Env: ANDROID_HOME, JAVA_HOME and PORT are respected.
EOF
}

# ---- arguments --------------------------------------------------------------
HOST=1
PORT="${PORT:-8000}"
MODE=release
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-host) HOST=0 ;;
    --port) shift; PORT="${1:-8000}" ;;
    --port=*) PORT="${1#*=}" ;;
    --debug) MODE=debug ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

# ---- 1. a JDK the Android build is happy with -------------------------------
# The Android Gradle plugin supports JDK 17 and 21. Newer JDKs (25, …) can work but
# are not officially supported, so prefer 17/21 when one is installed and fall back
# to the default `java` otherwise.
is_supported_jdk() {
  [ -x "$1/bin/java" ] || return 1
  local major
  major="$("$1/bin/java" -version 2>&1 | head -1 | grep -oE '[0-9]+' | head -1)"
  case "$major" in 17|21) return 0;; *) return 1;; esac
}

resolve_java_home() {
  if [ -n "${JAVA_HOME:-}" ] && is_supported_jdk "$JAVA_HOME"; then
    printf '%s\n' "$JAVA_HOME"; return 0
  fi
  if [ -x /usr/libexec/java_home ]; then
    local v jh
    for v in 21 17; do
      if jh="$(/usr/libexec/java_home -v "$v" 2>/dev/null)" && is_supported_jdk "$jh"; then
        printf '%s\n' "$jh"; return 0
      fi
    done
  fi
  local cand
  for cand in \
    /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home ; do
    if is_supported_jdk "$cand"; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}

if JH="$(resolve_java_home)"; then
  export JAVA_HOME="$JH"
  echo "JDK          $JAVA_HOME"
else
  echo "JDK          using the default on PATH (no JDK 17/21 found). If the build"
  echo "             complains, run:  brew install --cask temurin@21"
fi

# ---- 2. the Android SDK -----------------------------------------------------
resolve_android_home() {
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
    printf '%s\n' "$ANDROID_HOME"; return 0
  fi
  local cand
  for cand in \
    /opt/homebrew/share/android-commandlinetools \
    "$HOME/Library/Android/sdk" \
    /usr/local/share/android-commandlinetools \
    "$HOME/Android/Sdk" ; do
    if [ -d "$cand" ]; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}

if ! ANDROID_HOME="$(resolve_android_home)"; then
  echo
  echo "Android SDK not found. Install it, then re-run this script:"
  echo "    brew install --cask android-commandlinetools     # macOS"
  echo "and point ANDROID_HOME at it (e.g. /opt/homebrew/share/android-commandlinetools)."
  exit 1
fi
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
echo "Android SDK  $ANDROID_HOME"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH. Install it, e.g.:  brew install --cask flutter"
  exit 1
fi

# ---- 3. build the APK -------------------------------------------------------
echo "Building the $MODE APK…"
flutter build apk "--$MODE"

APK="$ROOT/build/app/outputs/flutter-apk/app-$MODE.apk"
if [ ! -f "$APK" ]; then
  echo "Expected the build to produce $APK, but it is not there." >&2
  exit 1
fi
echo
echo "  Built $APK"
echo "  $(du -h "$APK" | cut -f1)   sha256 $(shasum -a 256 "$APK" | cut -c1-16)…"
echo

# ---- 4. host it on port 8000 ------------------------------------------------
if [ "$HOST" != 1 ]; then
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to host the APK. Install it, or serve the file yourself:"
  echo "    $APK"
  exit 1
fi

VER="$(grep -m1 '^version:' pubspec.yaml 2>/dev/null | awk '{print $2}' | cut -d+ -f1 || true)"
APK_NAME="toil-troublez${VER:+-$VER}.apk"

# Show the app's own launcher icon on the page so it matches what gets installed.
# Prefer the 1024 master, fall back to the Android launcher icon; if neither is
# present the page simply hides the image.
ICON="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
[ -f "$ICON" ] || ICON="$ROOT/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

echo "Serving the APK on 0.0.0.0:$PORT — open the address it prints on a phone on the"
echo "same Wi-Fi. Press Ctrl+C to stop the server."
echo

exec python3 - "$PORT" "$APK" "$APK_NAME" "$ICON" <<'PY'
import hashlib
import html
import http.server
import os
import socket
import sys

PORT = int(sys.argv[1])
APK = os.path.abspath(sys.argv[2])
APK_NAME = sys.argv[3]
ICON = os.path.abspath(sys.argv[4]) if len(sys.argv) > 4 else ""
DOWNLOAD_PATH = "/toil-troublez.apk"
ICON_PATH = "/icon.png"


def apk_info():
    """(size, sha256) for the current APK, or None if it is not there yet."""
    try:
        stat = os.stat(APK)
    except OSError:
        return None
    digest = hashlib.sha256()
    with open(APK, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return stat.st_size, digest.hexdigest()


def lan_addresses():
    found = []
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = info[4][0]
            if address not in found and not address.startswith("127."):
                found.append(address)
    except OSError:
        pass
    if not found:
        # Fall back to the address the routing table would use to leave the machine.
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            probe.connect(("8.8.8.8", 80))
            found.append(probe.getsockname()[0])
        except OSError:
            pass
        finally:
            probe.close()
    return found


def page(host, size, sha256):
    megabytes = size / 1024 / 1024
    url = f"http://{host}{DOWNLOAD_PATH}"
    return f"""<!doctype html><html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#3F070C">
<title>Install Toil & Troublez</title>
<style>
  :root {{
    --ink: #2A1D17; --ink-soft: #5A4536;
    --parchment: #F2E2C0; --parchment-light: #FAF0D9; --parchment-deep: #E2CB9F;
    --oxblood: #7A1018; --oxblood-deep: #3F070C;
    --gold: #C8A04A; --gold-light: #F0D58A; --gold-deep: #8B6B26;
    --green: #1F3E2D;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; min-height: 100vh; padding: 2.4rem 1.25rem 4rem;
    font: 16px/1.6 "Nunito Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: var(--ink); display: flex; flex-direction: column; align-items: center;
    background:
      radial-gradient(120% 55% at 50% -10%, rgba(240,213,138,.30) 0%, rgba(240,213,138,0) 60%),
      radial-gradient(80% 50% at 50% 110%, rgba(0,0,0,.45) 0%, rgba(0,0,0,0) 65%),
      repeating-linear-gradient(115deg, rgba(255,255,255,.022) 0 2px, rgba(0,0,0,0) 2px 7px),
      linear-gradient(165deg, #5A0A11 0%, var(--oxblood) 38%, var(--oxblood-deep) 100%);
    background-attachment: fixed;
  }}
  main {{ width: 100%; max-width: 30rem; }}

  .crest {{
    display: block; width: 106px; height: 106px; margin: 0 auto .95rem;
    border-radius: 24%; object-fit: cover;
    border: 2px solid rgba(240,213,138,.85);
    box-shadow: 0 0 0 5px rgba(63,7,12,.55), 0 16px 34px rgba(0,0,0,.45),
                0 0 34px rgba(200,160,74,.28);
  }}
  .eyebrow {{
    margin: 0 0 .55rem; text-align: center; text-transform: uppercase;
    font-size: .66rem; font-weight: 800; letter-spacing: .34rem;
    color: var(--gold-light); opacity: .92;
  }}
  h1 {{
    margin: 0; text-align: center;
    font-family: Georgia, "Times New Roman", serif;
    font-size: clamp(2.35rem, 12vw, 3.35rem); font-weight: 900;
    line-height: .92; letter-spacing: .035em; text-transform: uppercase;
    color: var(--parchment-light);
    text-shadow: 2px 2px 0 var(--gold-deep), 4px 5px 0 rgba(0,0,0,.35),
                 0 0 30px rgba(200,160,74,.22);
  }}
  h1 span {{ display: block; color: var(--gold-light); font-size: .62em; letter-spacing: .17em; }}
  .tag {{
    margin: .85rem 0 1.9rem; text-align: center; font-size: .9rem;
    font-weight: 600; color: rgba(250,240,217,.78);
  }}

  a.dl {{
    display: flex; align-items: center; justify-content: center; gap: .6rem;
    padding: 1.08rem 1.1rem; border-radius: .8rem; text-decoration: none;
    font-weight: 900; font-size: 1.04rem; letter-spacing: .07em; text-transform: uppercase;
    color: var(--ink); border: 2px solid var(--parchment-light);
    background: linear-gradient(180deg, #F3DE9B 0%, var(--gold) 55%, #A87F2A 100%);
    box-shadow: 0 6px 0 #5A3B0A, 0 16px 30px rgba(0,0,0,.38),
                inset 0 1px 0 rgba(255,255,255,.65);
    transition: transform .08s ease, box-shadow .08s ease;
  }}
  a.dl:active {{
    transform: translateY(3px);
    box-shadow: 0 3px 0 #5A3B0A, 0 8px 18px rgba(0,0,0,.32);
  }}
  .meta {{
    margin-top: .9rem; text-align: center; color: rgba(250,240,217,.62);
    font-size: .74rem; word-break: break-all;
  }}

  .card {{
    margin-top: 1.35rem; padding: 1.2rem 1.35rem 1.15rem;
    background:
      linear-gradient(180deg, rgba(255,255,255,.20), rgba(255,255,255,0) 45%),
      linear-gradient(160deg, var(--parchment-light), var(--parchment) 60%, var(--parchment-deep));
    border: 1px solid rgba(139,107,38,.75); border-radius: .9rem;
    box-shadow: 0 1px 0 rgba(255,255,255,.5) inset, 0 12px 26px rgba(0,0,0,.24);
  }}
  .card h2 {{
    margin: 0 0 .65rem; font-family: Georgia, serif; font-size: .68rem;
    font-weight: 700; letter-spacing: .17rem; text-transform: uppercase;
    color: var(--oxblood); border-bottom: 1px solid rgba(139,107,38,.34);
    padding-bottom: .45rem;
  }}
  ol, ul {{ margin: 0; padding-left: 1.15rem; }}
  li {{ margin: .42rem 0; color: #3A2A20; font-size: .9rem; line-height: 1.5; }}
  li b {{ color: var(--ink); }}
  code {{
    background: rgba(63,7,12,.08); padding: .08rem .32rem;
    border-radius: .25rem; font-size: .86em; color: var(--oxblood);
  }}
  .chips {{ display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .1rem; }}
  .chip {{
    padding: .22rem .55rem; border-radius: 999px; font-size: .7rem; font-weight: 800;
    letter-spacing: .06em; text-transform: uppercase;
    color: var(--parchment-light); background: var(--green);
    border: 1px solid rgba(240,213,138,.42);
  }}
  .foot {{
    margin: 2rem 0 0; text-align: center; font-size: .68rem;
    letter-spacing: .15em; text-transform: uppercase; color: rgba(250,240,217,.38);
  }}
</style></head><body><main>
  <img class="crest" src="{ICON_PATH}" alt="Toil & Troublez" onerror="this.style.display='none'">
  <p class="eyebrow">Card Game · Android · Sideload</p>
  <h1>Toil <span>& Troublez</span></h1>
  <p class="tag">Hunt the Talismans in the Enchanted Forest. Push your luck — or stop while you're ahead.</p>

  <a class="dl" href="{html.escape(DOWNLOAD_PATH)}" download="{html.escape(APK_NAME)}">⇩  Download the APK</a>
  <p class="meta">{megabytes:.1f} MB · SHA-256 {html.escape(sha256[:16])}… · {html.escape(url)}</p>

  <div class="card">
    <h2>Installing it</h2>
    <ol>
      <li>Tap <b>Download the APK</b>. Chrome warns that this kind of file can be harmful — it says that about every APK it did not get from the Play Store.</li>
      <li>Open the downloaded file. Android asks to <b>allow installs from this source</b>; turn it on and come back.</li>
      <li>Tap <b>Install</b>, then <b>Open</b>.</li>
    </ol>
  </div>

  <div class="card">
    <h2>Before you play over Wi-Fi</h2>
    <ul>
      <li>Solo against bots and pass-and-play need no network at all.</li>
      <li>For a table game, open the app on one device and choose <b>Host a Game</b>; it shows the address everyone else joins.</li>
      <li>Everyone must be on the same Wi-Fi, and not on a guest network that isolates devices from each other.</li>
      <li>The host runs the authoritative game engine, so keep the hosting device charged.</li>
    </ul>
  </div>

  <div class="card">
    <h2>At the table</h2>
    <div class="chips">
      <span class="chip">Solo vs bots</span>
      <span class="chip">Pass & play</span>
      <span class="chip">Host / join</span>
      <span class="chip">2–6 players</span>
    </div>
    <ul>
      <li>Place Talismans in ascending rows: no two of the same, no adjacent colours.</li>
      <li>Bust the row and take a card from the forest; finish it to bank points — a Collection is worth 10.</li>
      <li>Master Magician spells: <b>Vanish</b>, <b>Summon</b>, <b>Poison</b> and <b>Cloak</b>.</li>
      <li><b>Amateur</b>, <b>Skilled</b> and <b>Master</b> bots play noticeably differently.</li>
    </ul>
  </div>

  <p class="foot">Fan-made · not affiliated with Grandpa Beck's Games</p>
</main></body></html>"""


def rebuilding():
    return (
        '<!doctype html><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="refresh" content="10">'
        '<title>Toil & Troublez is rebuilding</title>'
        '<style>body{font:16px/1.6 system-ui,sans-serif;margin:20vh auto;max-width:22rem;'
        'text-align:center;padding:0 1.4rem;background:linear-gradient(165deg,#5A0A11,#3F070C);'
        'color:#F2E2C0}h1{font-family:Georgia,serif;color:#F0D58A;letter-spacing:.06em;'
        'text-shadow:2px 2px 0 #8B6B26}b{color:#F0D58A}</style>'
        '<h1>Building</h1><p>A new Toil & Troublez build is being made right now. '
        'This page refreshes on its own — try again in a moment.</p>'
    )


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "ToilTroublezAPK/1.0"

    def log_message(self, fmt, *args):  # keep the console tidy
        pass

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        info = apk_info()

        if path == DOWNLOAD_PATH:
            if info is None:
                self.send_response(503)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Retry-After", "20")
                self.end_headers()
                self.wfile.write(b"The APK is being rebuilt. Try again in a moment.\n")
                return
            size, _ = info
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Length", str(size))
            self.send_header("Content-Disposition", f'attachment; filename="{APK_NAME}"')
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            with open(APK, "rb") as handle:
                for chunk in iter(lambda: handle.read(1 << 20), b""):
                    self.wfile.write(chunk)
            print(f"  -> served the APK to {self.client_address[0]}")
            return

        if path == "/sha256":
            body = f"{info[1]}  {APK_NAME}\n" if info else "rebuilding\n"
            self.send_response(200 if info else 503)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body.encode())
            return

        if path == ICON_PATH and ICON and os.path.exists(ICON):
            with open(ICON, "rb") as handle:
                data = handle.read()
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "public, max-age=3600")
            self.end_headers()
            self.wfile.write(data)
            return

        if path in ("/", "/index.html"):
            host = self.headers.get("Host", f"localhost:{PORT}")
            body = page(host, *info) if info else rebuilding()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body.encode())
            return

        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Not found. Go to / for the download page.\n")


def main():
    info = apk_info()
    try:
        server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    except OSError as error:
        print(f"  Could not listen on port {PORT}: {error}")
        print("  Something else is using that port. Stop it, or pick another one:")
        print(f"      ./tools/build-apk-host.sh --port {PORT + 1}")
        sys.exit(1)
    addresses = lan_addresses()
    print(f"  Toil & Troublez {('%.1f MB ' % (info[0] / 1024 / 1024)) if info else ''}APK is being served.")
    print()
    if not addresses:
        print("  No LAN address found — is this machine on Wi-Fi?")
    else:
        print("  Open this on your phone (same Wi-Fi):")
        for address in addresses:
            print(f"    http://{address}:{PORT}")
    if info:
        print()
        print(f"  file     {os.path.basename(APK)}")
        print(f"  SHA-256  {info[1]}")
    print()
    print("  Stop with Ctrl+C.")
    print()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
PY