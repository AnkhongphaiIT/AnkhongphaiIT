// Điều khiển client web thật bằng Chromium (Playwright) theo kịch bản JSON; chụp ảnh + ghi console.
// node tests/web/drive.cjs <scenario.json> <out_dir>
// Bước: {goto:url} {wait:ms} {shot:name} {click:[x,y]} {dbl:[x,y]} {move:[x,y]} {down:[x,y]} {up:[x,y]}
//       {mdown:"left"} {mup:"left"} {type:"text"} {key:"Enter"} {keydown:"KeyW"} {keyup:"KeyW"}
//       {hold:"KeyW", ms} {waitlog:"regex", timeout} {reel:{until, timeout}, wait_for}
//       {hunt:{until, timeout, interval, pre_key, step_key, step_every, step_ms}}
//       {repeat:[bước...], until:"regex", max:n}  — chạy lại khối tới khi log khớp (ví dụ cá sổng thì câu lại)
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const logs = [];
const real = (l) => !l.startsWith('[step') && !l.startsWith('[repeat') && !l.startsWith('[driver');
const seen = (re, from) => logs.slice(from).some((l) => real(l) && re.test(l));

async function waitLog(page, re, from, timeout, what) {
  const until = Date.now() + timeout;
  while (!seen(re, from)) {
    if (Date.now() > until) throw new Error(`timeout waiting for ${what}`);
    await page.waitForTimeout(40);
  }
}

let prevStart = 0;
let curStart = 0;

async function runStep(page, s, outDir, mark) {
  // fresh:true tính log từ đầu bước TRƯỚC (hành động gây ra sự kiện) — tránh lỡ khi server trả lời nhanh
  prevStart = curStart;
  curStart = logs.length;
  mark(s);
  if (s.repeat) {
    const re = new RegExp(s.until);
    const from = logs.length;
    for (let i = 0; i < (s.max || 3); i++) {
      try {
        for (const sub of s.repeat) await runStep(page, sub, outDir, mark);
      } catch (e) {
        logs.push(`[repeat] lần ${i + 1} lỗi: ${e.message}`);
      }
      if (seen(re, from)) return;
      logs.push(`[repeat] lần ${i + 1} chưa đạt ${s.until}, thử lại`);
    }
    throw new Error(`repeat không đạt ${s.until} sau ${s.max || 3} lần`);
  }
  if (s.goto) await page.goto(s.goto, { waitUntil: 'load', timeout: 120000 });
  if (s.wait) await page.waitForTimeout(s.wait);
  if (s.click) await page.mouse.click(s.click[0], s.click[1]);
  if (s.dbl) await page.mouse.dblclick(s.dbl[0], s.dbl[1]);
  if (s.move) await page.mouse.move(s.move[0], s.move[1], { steps: s.steps || 1 });
  if (s.down) { await page.mouse.move(s.down[0], s.down[1]); await page.mouse.down(); }
  if (s.up) { await page.mouse.move(s.up[0], s.up[1]); await page.mouse.up(); }
  if (s.mdown) await page.mouse.down({ button: s.mdown });
  if (s.mup) await page.mouse.up({ button: s.mup });
  if (s.type !== undefined) await page.keyboard.type(s.type, { delay: 30 });
  if (s.key) await page.keyboard.press(s.key, { delay: s.delay || 120 });
  if (s.keydown) await page.keyboard.down(s.keydown);
  if (s.keyup) await page.keyboard.up(s.keyup);
  if (s.hold) { await page.keyboard.down(s.hold); await page.waitForTimeout(s.ms || 500); await page.keyboard.up(s.hold); }
  // waitlog: mặc định tìm trong toàn bộ log; fresh:true chỉ tính log sau khi bắt đầu bước (dùng trong khối lặp)
  if (s.waitlog) await waitLog(page, new RegExp(s.waitlog), s.fresh ? prevStart : 0, s.timeout || 60000, s.waitlog);
  if (s.reel) {
    // chờ cá cắn rồi bấm ngay (cửa sổ giật ngắn); giữ chuột kéo, thả khi cá quẫy
    if (s.wait_for) await waitLog(page, new RegExp(s.wait_for), prevStart, 60000, s.wait_for);
    const until = new RegExp(s.reel.until);
    const start = logs.length;
    const deadline = Date.now() + (s.reel.timeout || 60000);
    let held = true;
    await page.mouse.down();
    while (!seen(until, start)) {
      if (Date.now() > deadline) { await page.mouse.up(); throw new Error('reel timeout'); }
      const t = logs.slice(start).filter((l) => /thrash_(started|ended)/.test(l)).pop();
      const thrashing = t && /thrash_started/.test(t);
      if (thrashing && held) { await page.mouse.up(); held = false; }
      if (!thrashing && !held) { await page.mouse.down(); held = true; }
      await page.waitForTimeout(80);
    }
    if (held) await page.mouse.up();
    if (s.reel.fail && seen(new RegExp(s.reel.fail), start)) throw new Error('cá sổng: ' + s.reel.fail);
  }
  if (s.hunt) {
    // nhấp liên tục (đập cá), thỉnh thoảng bước tới, tới khi log khớp; dừng sớm nếu gặp s.hunt.fail
    const until = new RegExp(s.hunt.until);
    const fail = s.hunt.fail ? new RegExp(s.hunt.fail) : null;
    const start = logs.length;
    const deadline = Date.now() + (s.hunt.timeout || 30000);
    let n = 0;
    while (!seen(until, start)) {
      if (Date.now() > deadline) throw new Error('hunt timeout ' + s.hunt.until);
      if (fail && seen(fail, start)) throw new Error('hunt thất bại: ' + s.hunt.fail);
      if (s.hunt.pre_key) { await page.keyboard.down(s.hunt.pre_key); await page.waitForTimeout(80); await page.keyboard.up(s.hunt.pre_key); }
      await page.mouse.down(); await page.waitForTimeout(60); await page.mouse.up();
      await page.waitForTimeout(s.hunt.interval || 450);
      n++;
      if (s.hunt.step_key && n % (s.hunt.step_every || 3) === 0) {
        await page.keyboard.down(s.hunt.step_key); await page.waitForTimeout(s.hunt.step_ms || 200); await page.keyboard.up(s.hunt.step_key);
      }
    }
  }
  if (s.walk_until) {
    // giữ phím di chuyển tới khi log khớp (ví dụ CABAY_FOCUS npc …), rồi thả
    const re = new RegExp(s.walk_until);
    const start = logs.length;
    const deadline = Date.now() + (s.timeout || 15000);
    await page.keyboard.down(s.walk_key || 'KeyW');
    let lastFace = 0;
    try {
      while (!seen(re, start)) {
        if (Date.now() > deadline) throw new Error('walk_until timeout ' + s.walk_until);
        if (s.face_key && Date.now() - lastFace > 700) {
          lastFace = Date.now();
          await page.keyboard.down(s.face_key); await page.waitForTimeout(60); await page.keyboard.up(s.face_key);
        }
        await page.waitForTimeout(100);
      }
    } finally {
      await page.keyboard.up(s.walk_key || 'KeyW');
    }
  }
  if (s.shot) await page.screenshot({ path: path.join(outDir, `${s.shot}.png`) });
}

(async () => {
  const [scenarioPath, outDir] = process.argv.slice(2);
  const steps = JSON.parse(fs.readFileSync(scenarioPath, 'utf8'));
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || undefined,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  let failed = null;
  const t0 = Date.now();
  const mark = (s) => logs.push(`[step ${((Date.now() - t0) / 1000).toFixed(1)}s] ${JSON.stringify(s).slice(0, 160)}`);
  try {
    for (const s of steps) await runStep(page, s, outDir, mark);
  } catch (e) {
    failed = e.message;
    logs.push(`[driver-error] ${e.message}`);
    await page.screenshot({ path: path.join(outDir, 'error.png') }).catch(() => {});
  }
  fs.writeFileSync(path.join(outDir, 'console.log'), logs.join('\n') + '\n');
  await browser.close();
  console.log(failed ? `DRIVE_FAIL ${failed}` : 'DRIVE_OK');
  process.exit(failed ? 1 : 0);
})();
