#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4174}"
ASSET_DIR="$ROOT_DIR/docs/demo/assets"
SERVER_LOG="$ROOT_DIR/build/logs/demo-assets-server.log"

mkdir -p "$ASSET_DIR" "$ROOT_DIR/build/logs"

if ! command -v node >/dev/null 2>&1; then
  printf 'Node.js is required to capture demo assets.\n' >&2
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

ROOT_DIR="$ROOT_DIR" PORT="$PORT" node <<'JS'
const { createRequire } = require("module");
const fs = require("fs");
const os = require("os");
const path = require("path");

const rootDir = process.env.ROOT_DIR;
const port = process.env.PORT;
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

const outputDir = path.join(rootDir, "docs/demo/assets");
fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const browser = await playwright.chromium.launch({ headless: true });
  const desktop = await browser.newPage({ viewport: { width: 1440, height: 1100 }, deviceScaleFactor: 1 });
  await desktop.goto(`http://127.0.0.1:${port}`, { waitUntil: "networkidle" });
  await desktop.locator(".hero").screenshot({
    path: path.join(outputDir, "landing-hero.png")
  });
  await desktop.screenshot({
    path: path.join(outputDir, "landing-desktop.png"),
    fullPage: true
  });

  const socialTargets = [
    { name: "social-square.png", width: 1080, height: 1080 },
    { name: "social-wide.png", width: 1200, height: 675 },
    { name: "social-vertical.png", width: 1080, height: 1920 },
    { name: "github-social-preview.png", width: 1280, height: 640 }
  ];

  for (const target of socialTargets) {
    const page = await browser.newPage({
      viewport: { width: target.width, height: target.height },
      deviceScaleFactor: 1
    });
    await page.goto(`http://127.0.0.1:${port}`, { waitUntil: "networkidle" });
    await page.locator(".hero").screenshot({
      path: path.join(outputDir, target.name)
    });
    const hasMockLabel = await page.locator(".panel-footer").evaluate((node) => node.textContent.includes("Mock demo"));
    await page.close();
    if (!hasMockLabel) {
      console.error(`${target.name} is missing the Mock demo label.`);
      process.exit(1);
    }
  }

  const mobile = await browser.newPage({
    viewport: { width: 390, height: 900 },
    isMobile: true,
    deviceScaleFactor: 2
  });
  await mobile.goto(`http://127.0.0.1:${port}`, { waitUntil: "networkidle" });
  await mobile.screenshot({
    path: path.join(outputDir, "landing-mobile.png"),
    fullPage: true
  });

  const checks = await mobile.evaluate(() => ({
    overflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    headline: document.querySelector("h1")?.textContent?.trim(),
    mockLabel: document.querySelector(".panel-footer")?.textContent?.includes("Mock demo")
  }));

  await browser.close();

  if (checks.overflowX) {
    console.error("Mobile landing page has horizontal overflow.");
    process.exit(1);
  }
  if (!checks.mockLabel) {
    console.error("Demo asset is missing the Mock demo label.");
    process.exit(1);
  }
  console.log(`Captured sanitized demo assets for: ${checks.headline}`);
})();
JS

printf 'Wrote demo assets:\n'
printf '  %s\n' "$ASSET_DIR/landing-hero.png"
printf '  %s\n' "$ASSET_DIR/landing-desktop.png"
printf '  %s\n' "$ASSET_DIR/landing-mobile.png"
printf '  %s\n' "$ASSET_DIR/social-square.png"
printf '  %s\n' "$ASSET_DIR/social-wide.png"
printf '  %s\n' "$ASSET_DIR/social-vertical.png"
printf '  %s\n' "$ASSET_DIR/github-social-preview.png"
