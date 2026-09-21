#!/usr/bin/env node
/*
 * map_flash_render_probe.js — 지도 HTML 을 **실제로 렌더해서** 깜빡임을 잰다.
 *
 * WHY: `map_postprocess.py` 의 계약 검사는 «기록의 형태»만 본다 — 억제 코드가 문서에 있나.
 * 있는데도 실제로 깜빡일 수 있고, 그 판정은 지금까지 사람 눈에만 있었다. 이 프로브가 그
 * 한 칸을 메운다: 첫 페인트 구간을 프레임으로 뜨고(CDP 스크린캐스트), 헤더 점을 100ms 간격으로
 * 떠서 픽셀이 변하는지 본다. 🟥 그래도 **사람 눈을 대체하지 않는다** — 헤드리스 합성기는
 * 실제 화면이 아니고, 이 프로브는 아래 네 가지만 본다(폰트·GPU·주사율·색관리는 못 본다).
 *
 * 스스로 보정한다: 매 실행이 «사전 페인트 테마 해소를 제거한 쌍둥이»(known-positive)를
 * 만들어 같이 재고, 그쪽이 안 빨개지면 **계기 고장**으로 죽는다(rc=4). 안 갈리는 계기의
 * 초록은 측정이 아니다.
 *
 * 용법: node scripts/map_flash_render_probe.js <page.html> [--out DIR] [--cpu N] [--hold MS] [--no-pulse]
 *       --no-pulse 는 첫 페인트만 잰다. 점의 마크업은 세 장이 같으므로 레인은 한 장에서만
 *       점을 재고 나머지는 이 깃발로 돈다 — 같은 것을 세 번 재는 20 초는 값이 없다.
 * 출력: `KEY=VALUE` 줄 (레인이 읽는다) + 사람이 읽는 요약
 * 종료코드: 0 통과 · 1 계약 위반(실물에서 깜빡였다) · 3 대상/런타임 부재 · 4 계기 고장
 */
'use strict';

const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');

const MIME = { '.html': 'text/html; charset=utf-8', '.svg': 'image/svg+xml', '.json': 'application/json',
               '.png': 'image/png', '.css': 'text/css', '.js': 'text/javascript' };
// 사전 페인트 테마 해소 블록의 앵커. archify 가 이 주석을 바꾸면 계기가 «자를 것이 없다»고
// 죽는다(rc=4) — 조용한 통과보다 시끄러운 고장이 낫다.
const THEME_ANCHOR = 'Resolve the theme before first paint';
const DARK_MAX = 120;   // 이보다 어두우면 «어두운 프레임» — 실측 분리폭은 6 vs 244 라 여유가 크다
const LIGHT_MIN = 200;  // 라이트 모드에서 정착한 페이지는 이보다 밝다
const SPREAD_MIN = 1.0; // 점이 «뛴다»고 부를 최소 진폭 (실측 컨트롤 8.16)
const SPREAD_STILL = 0.5;

function loadPlaywright() {
  // 주입점: 설치본이 자기 playwright 를 가리킬 수 있게 하고, 동시에 «없을 때» 갈래를
  // 레인이 실제로 밟을 수 있게 한다. 못 밟는 갈래는 안 쟀다는 뜻이다.
  if (process.env.FH_PLAYWRIGHT_MODULE) {
    try { return require(process.env.FH_PLAYWRIGHT_MODULE); } catch (_) { return null; }
  }
  for (const id of ['playwright', 'playwright-core',
                    '/opt/node22/lib/node_modules/playwright',
                    path.join(os.homedir(), '.npm-global/lib/node_modules/playwright')]) {
    try { return require(id); } catch (_) { /* 다음 후보 */ }
  }
  return null;
}

function browserPath() {
  const explicit = process.env.CHROMIUM_PATH;
  if (explicit && fs.existsSync(explicit)) return explicit;
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH;
  if (root && fs.existsSync(path.join(root, 'chromium'))) return path.join(root, 'chromium');
  return null;   // playwright 가 자기 기본 경로를 쓰게 둔다
}

function serve(rootDir, mutate) {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '');
    const file = path.join(rootDir, rel);
    if (!file.startsWith(rootDir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404); return res.end('not found');
    }
    let body = fs.readFileSync(file);
    if (mutate && file.endsWith('.html')) body = Buffer.from(mutate(body.toString('utf8')), 'utf8');
    res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(body);
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok(server)));
}

function stripPrePaintTheme(html) {
  const at = html.indexOf(THEME_ANCHOR);
  if (at < 0) return null;
  const open = html.lastIndexOf('<script', at);
  const close = html.indexOf('</script>', at);
  if (open < 0 || close < 0) return null;
  return html.slice(0, open) + html.slice(close + '</script>'.length);
}

async function launch(pw, opts) {
  const exe = browserPath();
  const browser = await pw.chromium.launch(exe ? { executablePath: exe } : {});
  const ctx = await browser.newContext(Object.assign({
    colorScheme: 'light', viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1,
  }, opts));
  return { browser, ctx };
}

// 첫 페인트 구간의 프레임을 뜬다. 프레임은 320px 폭으로 줄여 받는다 — 휘도는 보존되고
// 순수 파이썬 디코딩이 16 배 빨라진다.
async function captureFirstPaint(pw, url, outDir, cpu, holdMs) {
  fs.mkdirSync(outDir, { recursive: true });
  const { browser, ctx } = await launch(pw, {});
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  const frames = [];
  cdp.on('Page.screencastFrame', async (f) => {
    frames.push(f.data);
    try { await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }); } catch (_) { /* 닫힌 뒤 */ }
  });
  await cdp.send('Page.enable');
  if (cpu > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1, maxWidth: 320, maxHeight: 200 });
  try { await page.goto(url, { waitUntil: 'commit', timeout: 30000 }); } catch (e) { /* 아래 프레임 수로 걸린다 */ }
  await page.waitForTimeout(holdMs);
  try { await cdp.send('Page.stopScreencast'); } catch (_) { /* 이미 닫힘 */ }
  frames.forEach((d, i) => fs.writeFileSync(path.join(outDir, `f${String(i).padStart(4, '0')}.png`),
                                            Buffer.from(d, 'base64')));
  await ctx.close(); await browser.close();
  return frames.length;
}

// 헤더 점을 100ms 간격으로 30 장 떠서 픽셀이 변하는지 본다.
// forceGate: 모션 거버너가 이 문서에서 capable 을 안 켜므로, 게이트를 손으로 켜야 «뛰는 점»을
// 만들 수 있다 — 그 팔이 이 계기의 known-positive 다.
async function capturePulse(pw, url, outDir, reduced, forceGate) {
  fs.mkdirSync(outDir, { recursive: true });
  const { browser, ctx } = await launch(pw, { reducedMotion: reduced ? 'reduce' : 'no-preference' });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'load', timeout: 30000 });
  await page.waitForTimeout(1500);
  const dot = page.locator('.pulse-dot').first();
  if (!(await dot.count())) { await ctx.close(); await browser.close(); return { frames: 0 }; }
  const state = await page.evaluate(() => {
    const d = document.querySelector('.pulse-dot');
    return { capable: document.documentElement.getAttribute('data-motion-capable'),
             animation: d ? getComputedStyle(d).animationName : null };
  });
  if (forceGate) await page.evaluate(() => document.documentElement.setAttribute('data-motion-capable', 'true'));
  const box = await dot.boundingBox();
  if (!box) { await ctx.close(); await browser.close(); return { frames: 0 }; }
  const pad = 6;
  const clip = { x: Math.max(0, box.x - pad), y: Math.max(0, box.y - pad),
                 width: box.width + pad * 2, height: box.height + pad * 2 };
  for (let i = 0; i < 30; i++) {
    await page.screenshot({ path: path.join(outDir, `p${String(i).padStart(3, '0')}.png`), clip });
    await page.waitForTimeout(100);
  }
  await ctx.close(); await browser.close();
  return { frames: 30, state };
}

function die(code, msg) { console.error(msg); process.exit(code); }

(async () => {
  const args = process.argv.slice(2);
  const target = args.find((a) => !a.startsWith('--'));
  const opt = (name, dflt) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 && args[i + 1] ? args[i + 1] : dflt;
  };
  if (!target) die(3, 'usage: map_flash_render_probe.js <page.html> [--out DIR] [--cpu N] [--hold MS]');
  if (!fs.existsSync(target)) die(3, `target absent when we looked: ${target}`);

  const pw = loadPlaywright();
  if (!pw) die(3, 'playwright absent — render probe cannot run here (NOT a pass)');

  const cpu = Number(opt('cpu', 6));
  const holdMs = Number(opt('hold', 4000));
  const outDir = opt('out', fs.mkdtempSync(path.join(os.tmpdir(), 'mapflash-')));
  const rootDir = path.resolve(path.dirname(target));
  const name = path.basename(target);

  if (stripPrePaintTheme(fs.readFileSync(target, 'utf8')) === null) {
    die(4, `INSTRUMENT ERROR: no pre-paint theme block to remove in ${name} ` +
           `(anchor "${THEME_ANCHOR}") — the known-positive arm cannot be built`);
  }

  const shipped = await serve(rootDir, null);
  const broken = await serve(rootDir, (h) => stripPrePaintTheme(h) || h);
  const url = (s) => `http://127.0.0.1:${s.address().port}/${name}`;
  const lumaMin = (dir) => {
    const { execFileSync } = require('child_process');
    return Number(execFileSync('python3', [path.join(__dirname, 'png_luma.py'), '--min', dir],
                               { encoding: 'utf8' }).trim());
  };
  const lumaSpread = (dir) => {
    const { execFileSync } = require('child_process');
    return Number(execFileSync('python3', [path.join(__dirname, 'png_luma.py'), '--spread', dir],
                               { encoding: 'utf8' }).trim());
  };

  const out = {};
  let verdict = 0;
  try {
    const nShipped = await captureFirstPaint(pw, url(shipped), path.join(outDir, 'shipped'), cpu, holdMs);
    const nBroken = await captureFirstPaint(pw, url(broken), path.join(outDir, 'broken'), cpu, holdMs);
    if (nShipped < 3 || nBroken < 3) {
      die(4, `INSTRUMENT ERROR: too few frames (shipped=${nShipped} broken=${nBroken}) — the page never painted`);
    }
    out.FRAMES_SHIPPED = nShipped;
    out.FRAMES_BROKEN = nBroken;
    out.MIN_LUMA_SHIPPED = lumaMin(path.join(outDir, 'shipped')).toFixed(2);
    out.MIN_LUMA_BROKEN = lumaMin(path.join(outDir, 'broken')).toFixed(2);

    if (Number(out.MIN_LUMA_BROKEN) > DARK_MAX) {
      die(4, `INSTRUMENT ERROR: the known-positive arm did not flash ` +
             `(min luma ${out.MIN_LUMA_BROKEN} > ${DARK_MAX}) — this run measures nothing`);
    }
    out.FLASH_SHIPPED = Number(out.MIN_LUMA_SHIPPED) <= DARK_MAX ? 'yes' : 'no';
    if (out.FLASH_SHIPPED === 'yes') verdict = 1;
    if (Number(out.MIN_LUMA_SHIPPED) < LIGHT_MIN && out.FLASH_SHIPPED === 'no') {
      die(4, `INSTRUMENT ERROR: the shipped arm never settled light (min luma ${out.MIN_LUMA_SHIPPED})`);
    }

    if (args.indexOf('--no-pulse') >= 0) {
    out.PULSE = 'not-measured (--no-pulse)';
  } else {
  const ctrl = await capturePulse(pw, url(shipped), path.join(outDir, 'pulse_control'), false, true);
    if (!ctrl.frames) die(4, 'INSTRUMENT ERROR: no .pulse-dot to measure — the pulse arms measure nothing');
    out.PULSE_GATE_LIVE = ctrl.state.capable === 'true' ? 'yes' : 'no';
    out.PULSE_ANIMATION_AS_SHIPPED = ctrl.state.animation || 'none';
    out.PULSE_SPREAD_CONTROL = lumaSpread(path.join(outDir, 'pulse_control')).toFixed(3);
    if (Number(out.PULSE_SPREAD_CONTROL) < SPREAD_MIN) {
      die(4, `INSTRUMENT ERROR: the forced-gate control did not move ` +
             `(spread ${out.PULSE_SPREAD_CONTROL} < ${SPREAD_MIN}) — a still dot proves nothing after this`);
    }
    await capturePulse(pw, url(shipped), path.join(outDir, 'pulse_reduce'), true, true);
    out.PULSE_SPREAD_REDUCE = lumaSpread(path.join(outDir, 'pulse_reduce')).toFixed(3);
    out.PULSE_STILL_UNDER_REDUCE = Number(out.PULSE_SPREAD_REDUCE) <= SPREAD_STILL ? 'yes' : 'no';
    if (out.PULSE_STILL_UNDER_REDUCE === 'no') verdict = 1;
  }
  } finally {
    shipped.close(); broken.close();
  }

  out.PAGE = name;
  out.OUT_DIR = outDir;
  Object.keys(out).sort().forEach((k) => console.log(`${k}=${out[k]}`));
  console.log(verdict === 0
    ? `✅ ${name}: no dark first frame in light mode; the dot holds still under reduced-motion`
    : `❌ ${name}: see FLASH_SHIPPED / PULSE_STILL_UNDER_REDUCE above`);
  process.exit(verdict);
})().catch((e) => die(4, `INSTRUMENT ERROR: ${e && e.stack ? e.stack : e}`));
