// Điều khiển client web thật bằng Chromium (Playwright) theo kịch bản JSON; chụp ảnh + ghi console.
// node tests/web/drive.cjs <scenario.json> <out_dir>
// Mỗi bước có thể có "page": n (mặc định 0) để điều khiển nhiều cửa sổ trình duyệt (nhiều người chơi).
// Bước: {goto:url} {wait:ms} {shot:name} {click:[x,y]} {dbl:[x,y]} {move:[x,y]} {down:[x,y]} {up:[x,y]}
//       {mdown:"left"} {mup:"left"} {type:"text"} {key:"Enter"} {keydown:"KeyW"} {keyup:"KeyW"}
//       {hold:"KeyW", ms} {waitlog:"regex", timeout, fresh} {reel:{until, fail, timeout}, wait_for}
//       {hunt:{until, fail, timeout, interval, pre_key, step_key, step_every, step_ms, dodge:{on, keys, ms}, reacts:[{on, tap, keys, ms}]}}
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
  // {share_ctx: m}: trang mới mở trong CÙNG bối cảnh trình duyệt với trang m (hai tab một trình duyệt: chung bộ nhớ/IndexedDB)
  if (!ctx.pages[n]) ctx.pages[n] = await ctx.newPage(n, s.share_ctx);
  const page = ctx.pages[n];
  if (s.goto) await page.goto(subst(s.goto), { waitUntil: 'load', timeout: 120000 });
  if (s.wait) await page.waitForTimeout(s.wait);
  if (s.click) await page.mouse.click(s.click[0], s.click[1]);
  // {freeze_ms:N} — đóng băng trang như tab nền bị trình duyệt dừng (JS/vòng lặp game ngừng) rồi đánh thức
  if (s.freeze_ms) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Page.enable');
    await cdp.send('Page.setWebLifecycleState', { state: 'frozen' });
    await new Promise((r) => setTimeout(r, s.freeze_ms));
    await cdp.send('Page.setWebLifecycleState', { state: 'active' });
    await cdp.detach().catch(() => {});
  }
  // {pause_raf_ms:N} — như tab bị ẩn: trình duyệt ngừng requestAnimationFrame nên vòng lặp game (Emscripten) dừng hẳn;
  // WebSocket vẫn nhận gói ở tầng trình duyệt nhưng game không xử lý/gửi gì cho tới khi trả rAF lại
  if (s.pause_raf_ms) {
    await page.evaluate(() => {
      window.__origRAF = window.requestAnimationFrame;
      window.__heldRAF = [];
      window.requestAnimationFrame = (cb) => { window.__heldRAF.push(cb); return 0; };
    });
    await page.waitForTimeout(s.pause_raf_ms);
    await page.evaluate(() => {
      window.requestAnimationFrame = window.__origRAF;
      for (const cb of window.__heldRAF.splice(0)) window.__origRAF(cb);
    });
  }
  // {signal:"restart_room", down_ms, mode:"term"|"kill"} — nhờ runner Python tắt room server thật rồi bật lại (không chờ)
  if (s.signal) process.stdout.write(`DRIVE_SIGNAL ${s.signal} ${s.down_ms || 3000} ${s.mode || 'term'}\n`);
  // {assert_no_log:"regex"} — log của trang (từ đầu) KHÔNG được có dòng khớp
  if (s.assert_no_log) {
    const re = new RegExp(s.assert_no_log);
    const hit = logs.find((l) => onPage(l, n) && real(l) && re.test(body(l)));
    if (hit) throw new Error('assert_no_log gặp: ' + body(hit).slice(0, 120));
  }
  // {viewport:[w,h]} — đổi kích thước cửa sổ trình duyệt (WEB-01 resize)
  if (s.viewport) await page.setViewportSize({ width: s.viewport[0], height: s.viewport[1] });
  // {perf:"nhãn"} — ghi CABAY_PERF: bộ nhớ wasm, JS heap, tổng dung lượng tài nguyên đã tải, thời gian tải trang
  if (s.perf) {
    const m = await page.evaluate(() => ({
      wasm: (window.__wasmMems || []).reduce((a, x) => a + x.buffer.byteLength, 0),
      js: performance.memory ? performance.memory.usedJSHeapSize : -1,
      jsTotal: performance.memory ? performance.memory.totalJSHeapSize : -1,
      res: performance.getEntriesByType('resource').reduce((a, r) => a + (r.decodedBodySize || 0), 0)
        + ((performance.getEntriesByType('navigation')[0] || {}).decodedBodySize || 0),
      load: (performance.getEntriesByType('navigation')[0] || {}).loadEventEnd || -1,
    }));
    const mb = (x) => (x / 1048576).toFixed(1);
    logs.push(`[p${n}] [log] CABAY_PERF ${s.perf} wasm_mb=${mb(m.wasm)} js_used_mb=${mb(m.js)} js_total_mb=${mb(m.jsTotal)} downloaded_mb=${mb(m.res)} load_ms=${Math.round(m.load)}`);
  }
  // {fps:"nhãn", ms:5000, hold:"w"} — đếm khung hình thật (requestAnimationFrame, vòng lặp Godot web chạy theo nhịp này)
  // trong ms, tùy chọn giữ một phím suốt lúc đo; ghi CABAY_FPS kèm GPU mà WebGL dùng (SwiftShader = vẽ bằng CPU)
  if (s.fps) {
    const measure = page.evaluate((ms) => new Promise((res) => {
      const gaps = []; let last = performance.now(); const t0 = last;
      const tick = (t) => { gaps.push(t - last); last = t; if (t - t0 < ms) requestAnimationFrame(tick); else done(); };
      const done = () => {
        const gl = document.createElement('canvas').getContext('webgl2');
        const ext = gl && gl.getExtension('WEBGL_debug_renderer_info');
        const s = gaps.slice(1).sort((a, b) => a - b);
        res({ n: s.length, span: last - t0, p50: s[Math.floor(s.length * 0.5)] || 0, p95: s[Math.floor(s.length * 0.95)] || 0,
          max: s[s.length - 1] || 0, gpu: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : (gl ? gl.getParameter(gl.RENDERER) : 'no-webgl2') });
      };
      requestAnimationFrame(tick);
    }), s.ms || 5000);
    if (s.hold) await page.keyboard.down(s.hold);
    const f = await measure;
    if (s.hold) await page.keyboard.up(s.hold);
    logs.push(`[p${n}] [log] CABAY_FPS ${s.fps} fps=${(f.n * 1000 / f.span).toFixed(1)} frame_p50_ms=${f.p50.toFixed(1)} frame_p95_ms=${f.p95.toFixed(1)} frame_max_ms=${f.max.toFixed(1)} gpu="${f.gpu}"`);
  }
  // {assert_near:{a:"BIẾN1", b:"BIẾN2", max:m}} — hai vị trí "x, y, z" đã capture cách nhau (mặt phẳng xz) không quá m
  if (s.assert_near) {
    const pa = String(vars[s.assert_near.a] || '').split(',').map(Number);
    const pb = String(vars[s.assert_near.b] || '').split(',').map(Number);
    const d = Math.hypot(pa[0] - pb[0], pa[2] - pb[2]);
    logs.push(`[p${n}] [step] distance ${s.assert_near.a}-${s.assert_near.b}=${d.toFixed(2)} (max ${s.assert_near.max})`);
    if (!(d <= s.assert_near.max)) throw new Error(`assert_near: ${d.toFixed(2)} > ${s.assert_near.max}`);
  }
  // {wheel:[x, y, dy, lần]} — cuộn con lăn tại (x,y); dy>0 cuộn xuống
  if (s.wheel) { await page.mouse.move(s.wheel[0], s.wheel[1]); for (let i = 0; i < (s.wheel[3] || 1); i++) { await page.mouse.wheel(0, s.wheel[2]); await page.waitForTimeout(120); } }
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
  // {BIẾN} trong waitlog được thay bằng giá trị đã capture (thoát ký tự regex)
  if (s.waitlog) {
    const pat = s.waitlog.replace(/\{([A-Z_]+)\}/g, (m, k) => (k in vars ? vars[k].replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : m));
    await waitLog(page, n, new RegExp(pat), s.fresh ? prevStart : 0, s.timeout || 60000, pat);
  }
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
    // dodge / react: {on:"regex", tap?:"Key", keys:[["KeyS","KeyA"],["KeyS","KeyD"]], ms} — mỗi lần log khớp mới
    // (ví dụ boss.telegraph, CABAY_ARENA out) bấm nhanh `tap` (quay mặt) rồi giữ tổ hợp phím, đổi tổ hợp luân phiên
    const reacts = [s.hunt.dodge, ...(s.hunt.reacts || [])].filter(Boolean).map((r) => ({ ...r, re: new RegExp(r.on), from: logs.length, side: 0 }));
    while (!seen(until, start, n)) {
      if (Date.now() > deadline) throw new Error('hunt timeout ' + s.hunt.until);
      if (fail && seen(fail, start, n)) throw new Error('hunt thất bại: ' + s.hunt.fail);
      const r = reacts.find((x) => seen(x.re, x.from, n));
      if (r) {
        for (const x of reacts) x.from = logs.length;
        if (r.tap) { await page.keyboard.down(r.tap); await page.waitForTimeout(80); await page.keyboard.up(r.tap); await page.waitForTimeout(150); }
        const combo = r.keys[r.side++ % r.keys.length];
        for (const key of combo) await page.keyboard.down(key);
        await page.waitForTimeout(r.ms || 900);
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
  // CABAY_E2E_GPU=1: cửa sổ trình duyệt thật + GPU của máy (đo FPS máy thật, PERF-01); mặc định headless SwiftShader.
  const gpu = process.env.CABAY_E2E_GPU === '1';
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || undefined,
    headless: !gpu,
    args: gpu ? ['--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required']
      : ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
  });
  const ctx = {
    pages: {},
    contexts: {},
    async newPage(n, share) {
      if (share !== undefined && ctx.contexts[share]) {
        const c0 = ctx.contexts[share];
        ctx.contexts[n] = c0;
        const p0 = await c0.newPage();
        p0.on('console', (m) => logs.push(`[p${n}] [${m.type()}] ${m.text()}`));
        p0.on('pageerror', (e) => logs.push(`[p${n}] [pageerror] ${e.message}`));
        return p0;
      }
      // mỗi người chơi một context riêng (không chia sẻ bộ nhớ trình duyệt/cài đặt)
      const c = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      ctx.contexts[n] = c;
      // đo bộ nhớ WebAssembly: ghi lại Memory do module xuất/nhập (chỉ đọc kích thước, không đổi hành vi)
      await c.addInitScript(() => {
        window.__wasmMems = [];
        const keep = (inst) => { try { for (const v of Object.values(inst.exports)) if (v instanceof WebAssembly.Memory) window.__wasmMems.push(v); } catch (e) {} };
        const oi = WebAssembly.instantiate;
        WebAssembly.instantiate = async function (...a) { const r = await oi.apply(this, a); keep(r.instance || r); return r; };
        const os = WebAssembly.instantiateStreaming;
        if (os) WebAssembly.instantiateStreaming = async function (...a) { const r = await os.apply(this, a); keep(r.instance); return r; };
      });
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
