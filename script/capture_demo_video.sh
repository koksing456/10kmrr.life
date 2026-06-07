#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4175}"
ASSET_DIR="$ROOT_DIR/docs/demo/assets"
SERVER_LOG="$ROOT_DIR/build/logs/demo-video-server.log"
WORK_DIR="$ROOT_DIR/build/demo-video"
WEBM_PATH="$WORK_DIR/demo-loop.webm"
MP4_PATH="$ASSET_DIR/demo-loop.mp4"
POSTER_PATH="$ASSET_DIR/demo-poster.png"

mkdir -p "$ASSET_DIR" "$ROOT_DIR/build/logs" "$WORK_DIR"
rm -f "$WEBM_PATH" "$MP4_PATH" "$POSTER_PATH"

if ! command -v node >/dev/null 2>&1; then
  printf 'Node.js is required to capture the demo video.\n' >&2
  exit 69
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  printf 'ffmpeg is required to encode the demo video.\n' >&2
  exit 69
fi

python3 -m http.server "$PORT" --directory "$ROOT_DIR/site" >"$SERVER_LOG" 2>&1 &
server_pid="$!"
cleanup() {
  kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 40); do
  if /usr/bin/curl -fsS "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

ROOT_DIR="$ROOT_DIR" PORT="$PORT" WORK_DIR="$WORK_DIR" WEBM_PATH="$WEBM_PATH" POSTER_PATH="$POSTER_PATH" node <<'JS'
const { createRequire } = require("module");
const fs = require("fs");
const os = require("os");
const path = require("path");

const rootDir = process.env.ROOT_DIR;
const port = process.env.PORT;
const workDir = process.env.WORK_DIR;
const webmPath = process.env.WEBM_PATH;
const posterPath = process.env.POSTER_PATH;
const candidates = [
  path.join(rootDir, "node_modules"),
  process.env.PLAYWRIGHT_NODE_MODULES,
  path.join(os.homedir(), ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules")
].filter(Boolean);

let playwright;
for (const candidate of candidates) {
  try {
    playwright = createRequire(path.join(candidate, "require.js"))("playwright");
    break;
  } catch {
    // Try the next candidate.
  }
}

if (!playwright) {
  console.error("Playwright is required. Install it with npm, or set PLAYWRIGHT_NODE_MODULES to a node_modules directory containing playwright.");
  process.exit(69);
}

fs.mkdirSync(workDir, { recursive: true });

(async () => {
  const browser = await playwright.chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1200, height: 676 },
    deviceScaleFactor: 1,
    recordVideo: {
      dir: workDir,
      size: { width: 1200, height: 676 }
    }
  });
  const page = await context.newPage();
  await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "networkidle" });
  await page.addStyleTag({
    content: `
      @media (min-width: 941px) {
        .topbar { min-height: 64px; }
        .hero-copy { max-width: 540px; padding: 18px 0 52px; }
        h1 { max-width: 540px; font-size: 76px; line-height: 0.95; }
        .lede { max-width: 500px; font-size: 17px; line-height: 1.45; }
        .hero-actions { margin-top: 22px; }
        .lockscreen { top: 88px; width: 500px; min-width: 500px; height: 520px; }
        .lock-date { top: 10px; }
        .lock-time { top: 38px; font-size: 100px; }
        .mrr-panel { top: 245px; width: 360px; min-height: 142px; padding: 20px 22px; border-radius: 28px; }
        .mrr-value { font-size: 43px; }
        .user-chip { bottom: 16px; }
      }
    `
  });
  await page.screenshot({ path: posterPath });

  const checks = await page.evaluate(() => {
    const heroText = document.querySelector(".hero")?.innerText || "";
    return {
      mockLabel: document.querySelector(".panel-footer")?.textContent?.includes("Mock demo"),
      stripeKeyLikeText: /[rs]k_(live|test)_/i.test(heroText),
      rawDashboardText: /invoice id|payment method|secret key|customer email/i.test(heroText)
    };
  });

  if (!checks.mockLabel) {
    console.error("Demo video page is missing the Mock demo label.");
    process.exit(1);
  }
  if (checks.stripeKeyLikeText || checks.rawDashboardText) {
    console.error("Demo video page contains unsafe Stripe/dashboard-like text.");
    process.exit(1);
  }

  await page.waitForTimeout(7200);
  const video = page.video();
  await context.close();
  await browser.close();

  const recordedPath = await video.path();
  fs.copyFileSync(recordedPath, webmPath);
})();
JS

ffmpeg -y \
  -i "$WEBM_PATH" \
  -vf "fps=30,format=yuv420p" \
  -c:v libx264 \
  -profile:v high \
  -movflags +faststart \
  -an \
  "$MP4_PATH" >/dev/null 2>&1

printf 'Wrote sanitized mock demo video:\n'
printf '  %s\n' "$MP4_PATH"
printf '  %s\n' "$POSTER_PATH"
