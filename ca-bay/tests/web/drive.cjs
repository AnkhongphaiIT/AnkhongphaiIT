// Điều khiển client web thật bằng Chromium (Playwright) theo kịch bản JSON; chụp ảnh + ghi console.
// node tests/web/drive.cjs <scenario.json> <out_dir>
// Mỗi bước có thể có "page": n (mặc định 0) để điều khiển nhiều cửa sổ trình duyệt (nhiều người chơi).
// Bước: {goto:url} {wait:ms} {shot:name} {click:[x,y]} {dbl:[x,y]} {move:[x,y]} {down:[x,y]} {up:[x,y]}
//       {mdown:"left"} {mup:"left"} {type:"text"} {key:"Enter"} {keydown:"KeyW"} {keyup:"KeyW"}
//       {hold:"KeyW", ms} {waitlog:"regex", timeout, fresh} {reel:{until, fail, timeout}, wait_for}
//       {hunt:{until, fail, timeout, interval, pre_key, step_key, step_every, step_ms, dodge:{on, keys, ms}}}
//       {walk_until:"regex", face_key, walk_key, timeout}
//       {capture:{regex:"...(nhóm)", var:"TÊN"}} — lấy giá trị từ log để dùng lại dạng {TÊN} trong type/goto
//       {repeat:[bước...], until:"regex", max:n} — chạy lại khối tới khi log khớp
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const logs = [];                 // mọi dòng, gắn tiền tố [pN]
const vars = {};
const body = (l) => l.slice(l.indexOf(' ') + 1);
const real = (l) => !/^\[(step|repeat|driver)/.test(body(l));
const onPage = (l, n) => l.startsWith(`[p${n}] `);
const seen = (re, from, n) => logs.slice(from).some((l) => onPage(l, n) && real(l) && re.test(body(l)));
const subst = (t) => (typeof t === 'string' ? t.replace(/\{([A-Z_]+)\}/g, (m, k) => (k in vars ? vars[k] : m)) : t);

async function waitLog(page, n, re, from, timeout, what) {
  const until = Date.now() + timeout;
  while (!seen(re, from, n)) {
    if (Date.now() > until) throw new Error(`[p${n}] timeout waiting for ${what}`);
    await page.waitForTimeout(40);
  }
}

let prevStart = 0;
let curStart = 0;

async function runStep(ctx, s, outDir, mark) {
  const n = s.page || 0;
  // fresh:true tính log từ đầu bước TRƯỚC (hành động gây ra sự kiện) — tránh lỡ khi server trả lời nhanh
  prevStart = curStart;
  curStart = logs.length;
  mark(s, n);
  if (s.repeat) {
    const re = new RegExp(s.until);
    const from = logs.length;
    for (let i = 0; i < (s.max || 3); i++) {
      try {
        for (const sub of s.repeat) await runStep(ctx, { page: n, ...sub }, outDir, mark);
      } catch (e) {
        logs.push(`[p${n}] [repeat] lần ${i + 1} lỗi: ${e.message}`);
      }
      if (seen(re, from, n)) return;
      logs.push(`[p${n}] [repeat] lần ${i + 1} chưa đạt ${s.until}, thử lại`);
    }
    throw new Error(`repeat không đạt ${s.until} sau ${s.max || 3} lần`);
  }
  if (!ctx.pages[n]) ctx.pages[n] = await ctx.newPage(n);
  const page = ctx.pages[n];
  if (s.goto) await page.goto(subst(s.goto), { waitUntil: 'load', timeout: 120000 });
  if (s.wait) await page.waitForTimeout(s.wait);
  if (s.click) await page.mouse.click(s.click[0], s.click[1]);
  if (s.dbl) await page.mouse.dblclick(s.dbl[0], s.dbl[1]);
  if (s.move) await page.mouse.move(s.move[0], s.move[1], { steps: s.steps || 1 });
  if (s.down) { await page.mouse.move(s.down[0], s.down[1]); await page.mouse.down(); }
  if (s.up) { await page.mouse.move(s.up[0], s.up[1]); await page.mouse.up(); }
  if (s.mdown) await page.mouse.down({ button: s.mdown });
  if (s.mup) await page.mouse.up({ button: s.mup });
  if (s.type !== undefined) {
    const txt = subst(s.type);
    await page.keyboard.type(txt, { delay: s.delay || 60 });
    // Godot web xử lý phím theo khung hình; ở FPS thấp phải chờ hết hàng đợi trước khi nhấp ô khác
    await page.waitForTimeout(600 + txt.length * 40);
  }
  if (s.key) await page.keyboard.press(s.key, { delay: s.delay || 120 });
  // gõ từng ký tự bằng phím (kiểu Unikey gửi ký tự có dấu qua sự kiện phím) hoặc insertText (kiểu IME commit)
  if (s.press_chars) { for (const ch of subst(s.press_chars)) { await page.keyboard.press(ch, { delay: 60 }); await page.waitForTimeout(120); } }
  if (s.insert_text) { await page.keyboard.insertText(subst(s.insert_text)); await page.waitForTimeout(600); }
  if (s.cdp_chars || s.ime_commit) {
    const cdp = await page.context().newCDPSession(page);
    if (s.cdp_chars) {
      // kiểu Unikey/EVKey trên Windows: sự kiện phím VK_PACKET mang sẵn ký tự Unicode
      for (const ch of subst(s.cdp_chars)) {
        await cdp.send('Input.dispatchKeyEvent', { type: 'keyDown', key: ch, text: ch, unmodifiedText: ch, windowsVirtualKeyCode: 231, nativeVirtualKeyCode: 231 });
        await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', key: ch, windowsVirtualKeyCode: 231, nativeVirtualKeyCode: 231 });
        await page.waitForTimeout(150);
      }
    }
    if (s.ime_commit) {
      // kiểu bộ gõ hệ điều hành (composition): soạn rồi xác nhận
      await cdp.send('Input.imeSetComposition', { text: subst(s.ime_commit), selectionStart: 1, selectionEnd: 1 });
      await page.waitForTimeout(200);
      await cdp.send('Input.insertText', { text: subst(s.ime_commit) });
      await page.waitForTimeout(600);
    }
    await cdp.detach();
  }
  if (s.keydown) await page.keyboard.down(s.keydown);
  if (s.keyup) await page.keyboard.up(s.keyup);
  if (s.hold) { await page.keyboard.down(s.hold); await page.waitForTimeout(s.ms || 500); await page.keyboard.up(s.hold); }
  // waitlog: mặc định tìm trong toàn bộ log của trang; fresh:true chỉ tính từ bước hành động trước
  if (s.waitlog) await waitLog(page, n, new RegExp(s.waitlog), s.fresh ? prevStart : 0, s.timeout || 60000, s.waitlog);
  if (s.capture) {
    const re = new RegExp(s.capture.regex);
    const until = Date.now() + (s.capture.timeout || 30000);
    for (;;) {
      const hit = logs.filter((l) => onPage(l, n) && real(l)).map((l) => body(l).match(re)).filter(Boolean).pop();
      if (hit) { vars[s.capture.var] = hit[1]; logs.push(`[p${n}] [step] captured ${s.capture.var}=${hit[1]}`); break; }
      if (Date.now() > until) throw new Error('capture timeout ' + s.capture.regex);
      await page.waitForTimeout(100);
    }
  }
  if (s.reel) {
    // chờ cá cắn rồi bấm ngay (cửa sổ giật ngắn); giữ chuột kéo, thả khi cá quẫy
    if (s.wait_for) await waitLog(page, n, new RegExp(s.wait_for), prevStart, 60000, s.wait_for);
    const until = new RegExp(s.reel.until);
    const start = logs.length;
    const deadline = Date.now() + (s.reel.timeout || 60000);
    let held = true;
    await page.mouse.down();
    while (!seen(until, start, n)) {
      if (Date.now() > deadline) { await page.mouse.up(); throw new Error('reel timeout'); }
      const t = logs.slice(start).filter((l) => onPage(l, n) && /thrash_(started|ended)/.test(l)).pop();
      const thrashing = t && /thrash_started/.test(t);
      if (thrashing && held) { await page.mouse.up(); held = false; }
      if (!thrashing && !held) { await page.mouse.down(); held = true; }
      await page.waitForTimeout(80);
    }
    if (held) await page.mouse.up();
    if (s.reel.fail && seen(new RegExp(s.reel.fail), start, n)) throw new Error('cá sổng: ' + s.reel.fail);
  }
  if (s.hunt) {
    // nhấp liên tục (đập cá), thỉnh thoảng bước tới, tới khi log khớp; dừng sớm nếu gặp s.hunt.fail
    const until = new RegExp(s.hunt.until);
    const fail = s.hunt.fail ? new RegExp(s.hunt.fail) : null;
    const start = logs.length;
    const deadline = Date.now() + (s.hunt.timeout || 30000);
    let k = 0;
    // dodge: {on:"regex", keys:[["KeyS","KeyA"],["KeyS","KeyD"]], ms} — mỗi lần log khớp mới (ví dụ boss.telegraph) giữ tổ hợp phím né, đổi bên luân phiên
    const dodge = s.hunt.dodge ? { re: new RegExp(s.hunt.dodge.on), from: logs.length, side: 0 } : null;
    while (!seen(until, start, n)) {
      if (Date.now() > deadline) throw new Error('hunt timeout ' + s.hunt.until);
      if (fail && seen(fail, start, n)) throw new Error('hunt thất bại: ' + s.hunt.fail);
      if (dodge && seen(dodge.re, dodge.from, n)) {
        dodge.from = logs.length;
        const combo = s.hunt.dodge.keys[dodge.side++ % s.hunt.dodge.keys.length];
        for (const key of combo) await page.keyboard.down(key);
        await page.waitForTimeout(s.hunt.dodge.ms || 900);
        for (const key of combo) await page.keyboard.up(key);
        continue;
      }
      if (s.hunt.pre_key) { await page.keyboard.down(s.hunt.pre_key); await page.waitForTimeout(80); await page.keyboard.up(s.hunt.pre_key); }
      await page.mouse.down(); await page.waitForTimeout(60); await page.mouse.up();
      await page.waitForTimeout(s.hunt.interval || 450);
      k++;
      if (s.hunt.step_key && k % (s.hunt.step_every || 3) === 0) {
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
      while (!seen(re, start, n)) {
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
  const ctx = {
    pages: {},
    async newPage(n) {
      // mỗi người chơi một context riêng (không chia sẻ bộ nhớ trình duyệt/cài đặt)
      const c = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      const p = await c.newPage();
      p.on('console', (m) => logs.push(`[p${n}] [${m.type()}] ${m.text()}`));
      p.on('pageerror', (e) => logs.push(`[p${n}] [pageerror] ${e.message}`));
      return p;
    },
  };
  let failed = null;
  const t0 = Date.now();
  const mark = (s, n) => logs.push(`[p${n}] [step ${((Date.now() - t0) / 1000).toFixed(1)}s] ${JSON.stringify(s).slice(0, 160)}`);
  try {
    for (const s of steps) await runStep(ctx, s, outDir, mark);
  } catch (e) {
    failed = e.message;
    logs.push(`[p0] [driver-error] ${e.message}`);
    for (const [n, p] of Object.entries(ctx.pages)) await p.screenshot({ path: path.join(outDir, `error_p${n}.png`) }).catch(() => {});
  }
  // console.log: trang 0 không tiền tố (giữ định dạng cũ cho run_web_e2e.py); trang khác giữ [pN]
  fs.writeFileSync(path.join(outDir, 'console.log'), logs.map((l) => l.replace(/^\[p0\] /, '')).join('\n') + '\n');
  await browser.close();
  console.log(failed ? `DRIVE_FAIL ${failed}` : 'DRIVE_OK');
  process.exit(failed ? 1 : 0);
})();
