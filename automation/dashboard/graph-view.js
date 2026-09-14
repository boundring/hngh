/* graph-view — operations-graph tab, mounted into index.html#p-graph >
   #graph-root by app.js (window.GraphView = {init, refresh}).

   v2 (2026-09-14): the operator's daily-driver Chrome has WebGL dead
   (getContext('webgl') === null even on attached canvases), so the old
   three.js path could never run there — the view silently degraded to a
   flat SVG disc. This version renders the same 3D perspective scene with
   the plain 2D canvas API: depth-sorted painter's algorithm, orbit on
   drag, zoom on wheel and buttons, auto-rotate toggle. Works in any
   browser, no WebGL, no three.js (vendor/three.min.js deleted). The SVG
   fallback stays behind ?graph2d=1 (or no canvas 2d) with the same
   cards and filters.

   QoL: per-kind visibility chips, state legend that filters, text search
   with jump-to, click-to-select side info card, neighbor highlight with
   dimming, shareable selection (#tab-graph/n=<id>), staleness badge,
   refresh, Esc clears.

   v3 (2026-09-14): 'jcode-session' and 'swarm' node kinds join the
   size map and kind chips (state vocabulary unchanged — colors/legend
   stay state-keyed), and the graph tab auto-refreshes /graph.json
   every 60s through the shared HnghPoll helper (interval override,
   no raw timer); the fetch is skipped entirely while the graph panel
   is hidden, so a parked tab never polls.

   Nodes/edges come from /graph.json (jobs/graph-data.py). Display layer
   only — never governance input. All styles live in one owned <style>
   tag (gv- prefix); style.css is not touched. */
(function () {
  'use strict';

  var COLORS = {
    healthy: '#3fb950', stale: '#d29922',
    alerting: '#f85149', neutral: '#8b949e', kernel: '#f0f6fc'
  };
  var KIND_SIZE = {
    kernel: 11, leg: 6.5, service: 6.5, package: 5, seam: 5, 'spawn-path': 5,
    patrol: 4.5, surface: 4, cap: 4, guard: 4, 'research-line': 3.5,
    'jcode-session': 4, 'swarm': 6
  };
  var KINDS = ['kernel', 'leg', 'service', 'package', 'seam', 'spawn-path',
    'patrol', 'surface', 'cap', 'guard', 'research-line',
    'jcode-session', 'swarm'];
  var STATES = ['healthy', 'stale', 'alerting', 'neutral'];

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
  function fetchJson(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 10000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  // detail strings are "k=v k=v free text ..." — split leading pairs off
  function parseDetail(s) {
    var pairs = [], tail = [];
    var tok = String(s == null ? '' : s).split(' ');
    for (var i = 0; i < tok.length; i++) {
      var m = /^([a-z][a-z0-9-]*)=(\S+)$/.exec(tok[i]);
      if (m && pairs.length < 12) pairs.push([m[1], m[2]]);
      else tail.push(tok[i]);
    }
    return { pairs: pairs, tail: tail.join(' ') };
  }

  var STYLE = [
    '.gv-wrap{position:relative;width:100%;height:calc(100vh - 200px);',
    'min-height:480px;max-height:1100px;overflow:hidden;color:#c9d1d9;',
    'border:1px solid var(--line,#30363d);border-radius:6px;font-size:12px;',
    'background:radial-gradient(ellipse at 50% 40%,#10161d 0%,#0a0e13 100%)}',
    '.gv-canvas,.gv-svg{position:absolute;inset:0;width:100%;height:100%;',
    'display:block}',
    '.gv-toolbar{position:absolute;top:8px;left:8px;right:8px;display:flex;',
    'gap:6px;align-items:center;flex-wrap:wrap;z-index:6;pointer-events:none}',
    '.gv-toolbar>*{pointer-events:auto}',
    '.gv-btn{background:#161b22cc;border:1px solid #30363d;color:#c9d1d9;',
    'border-radius:4px;padding:3px 8px;font-size:11px;cursor:pointer}',
    '.gv-btn:hover{border-color:#58a6ff;color:#f0f6fc}',
    '.gv-search{background:#161b22cc;border:1px solid #30363d;color:#c9d1d9;',
    'border-radius:4px;padding:3px 8px;font-size:11px;width:170px}',
    '.gv-search:focus{outline:none;border-color:#58a6ff}',
    '.gv-search::placeholder{color:var(--dim,#6e7681)}',
    '.gv-chip{background:#161b22cc;border:1px solid #30363d;border-radius:10px;',
    'padding:2px 8px;font-size:10.5px;cursor:pointer;color:#8b949e;',
    'user-select:none;white-space:nowrap}',
    '.gv-chip:hover{border-color:#58a6ff}',
    '.gv-chip.off{opacity:.35;text-decoration:line-through}',
    '.gv-chip b{color:#c9d1d9;font-weight:600}',
    '.gv-dot{display:inline-block;width:8px;height:8px;border-radius:50%;',
    'margin-right:4px;vertical-align:middle}',
    '.gv-badge{margin-left:auto;background:#161b22cc;border:1px solid #30363d;',
    'border-radius:4px;padding:3px 8px;font-size:10.5px;color:#8b949e}',
    '.gv-badge.fresh{color:#3fb950}',
    '.gv-hint{position:absolute;left:10px;bottom:30px;font-size:10px;',
    'color:var(--dim,#6e7681);z-index:5;pointer-events:none}',
    '.gv-tip{position:absolute;pointer-events:none;display:none;max-width:360px;',
    'padding:8px 10px;background:#161b22ee;border:1px solid #30363d;',
    'border-radius:6px;font-size:12px;line-height:1.45;color:#c9d1d9;z-index:8}',
    '.gv-tip b,.gv-panel b{color:#f0f6fc}',
    '.gv-kind{opacity:.65;text-transform:uppercase;letter-spacing:.08em;',
    'font-size:10px}',
    '.gv-row{display:flex;gap:6px}.gv-row i{color:#8b949e;font-style:normal;',
    'min-width:88px;flex:none}',
    '.gv-tip a,.gv-panel a{color:#58a6ff;text-decoration:none}',
    '.gv-tip a:hover,.gv-panel a:hover{text-decoration:underline}',
    '.gv-panel{position:absolute;top:38px;right:8px;bottom:30px;width:300px;',
    'overflow:auto;background:#161b22f2;border:1px solid #30363d;border-radius:6px;',
    'padding:10px 12px 12px;z-index:7;display:none;font-size:12px;line-height:1.5}',
    '.gv-panel h3{margin:0 26px 2px 0;font-size:13px;color:#f0f6fc}',
    '.gv-panel .gv-x{position:absolute;top:6px;right:8px;background:none;',
    'border:0;color:#8b949e;font-size:14px;cursor:pointer;padding:2px 4px}',
    '.gv-panel .gv-x:hover{color:#f0f6fc}',
    '.gv-legend{position:absolute;left:8px;bottom:8px;display:flex;gap:8px;',
    'font-size:11px;color:#8b949e;z-index:6;flex-wrap:wrap}',
    '.gv-err{position:absolute;inset:0;display:none;align-items:center;',
    'justify-content:center;color:#f85149;font-size:13px;z-index:9;',
    'background:#0a0e13cc}',
    '.gv-svg line{stroke:#30363d}.gv-svg line.gv-hi{stroke:#58a6ff}',
    '.gv-svg circle{cursor:pointer}.gv-svg text{fill:#8b949e;font-size:10px;',
    'pointer-events:none}.gv-svg text.gv-hi{fill:#58a6ff}',
    '.gv-svg .gv-dim{opacity:.15}'
  ].join('');

  function rowHtml(kv) {
    var v = esc(kv[1]);
    if (/^https?:\/\//.test(kv[1]))
      v = '<a href="' + v + '" target="_blank" rel="noreferrer">' + v + '</a>';
    return '<div class="gv-row"><i>' + esc(kv[0]) + '</i><span>' + v + '</span></div>';
  }
  function cardHtml(nd) {
    var d = parseDetail(nd.detail);
    var h = '<b>' + esc(nd.label) + '</b> <span class="gv-kind">' +
      esc(nd.kind) + ' · ' + esc(nd.state) + '</span>';
    if (d.pairs.length)
      h += '<div style="margin-top:4px">' + d.pairs.map(rowHtml).join('') + '</div>';
    if (d.tail) h += '<div style="margin-top:4px;opacity:.8">' + esc(d.tail) + '</div>';
    if (nd.kind === 'research-line')
      h += '<div style="margin-top:4px"><a href="#tab-research">open research →</a></div>';
    return h;
  }

  // Deterministic fibonacci-sphere layout; kernel pinned to the origin.
  function layout(nodes) {
    var n = nodes.length, R = 190, phi = Math.PI * (3 - Math.sqrt(5));
    var pos = {};
    nodes.forEach(function (nd, i) {
      if (nd.kind === 'kernel') { pos[nd.id] = [0, 0, 0]; return; }
      var k = Math.max(0, i - 1), y = 1 - (2 * k + 1) / Math.max(1, n - 2);
      var r = Math.sqrt(Math.max(0, 1 - y * y)), th = phi * k;
      pos[nd.id] = [R * r * Math.cos(th), R * y, R * r * Math.sin(th)];
    });
    return pos;
  }

  var root, wrap, tip, panel, badge, canvasBox, svgBox, ctx;
  var data = null, pos = null, mode = '3d', inited = false;
  var selId = null, hoverId = null, matches = null, pendSel = null;
  var kindOff = {}, stateOff = {}, lastLoad = 0;
  var POLL_MS = 60000;      // auto-refresh cadence for the graph tab
  var pollTimer = null;
  var W = 0, H = 0;
  var cam = { th: 0.6, ph: 0.35, r: 640 };
  // projected screen state — preallocated, reused every frame
  var scr = { x: null, y: null, s: null, d: null, n: 0 };
  var order = [];           // node indices, sorted far -> near each draw
  var idxOf = {};           // node id -> index
  var eSrc = null, eDst = null; // edge endpoints as node indices (-1 unknown)
  var FOCAL = 1 / Math.tan(25 * Math.PI / 180); // 50° vertical fov

  function setData(g) {
    data = g;
    pos = layout(g.nodes);
    idxOf = {};
    g.nodes.forEach(function (nd, i) { idxOf[nd.id] = i; });
    var n = g.nodes.length;
    if (scr.n < n) {
      scr.x = new Float32Array(n); scr.y = new Float32Array(n);
      scr.s = new Float32Array(n); scr.d = new Float32Array(n);
      scr.n = n;
    }
    for (var i = 0; i < n; i++) order[i] = i;
    order.length = n;
    eSrc = new Int32Array(g.edges.length);
    eDst = new Int32Array(g.edges.length);
    g.edges.forEach(function (e, k) {
      eSrc[k] = idxOf.hasOwnProperty(e.src) ? idxOf[e.src] : -1;
      eDst[k] = idxOf.hasOwnProperty(e.dst) ? idxOf[e.dst] : -1;
    });
  }

  function mount(el) {
    root = el;
    var st = document.createElement('style');
    st.textContent = STYLE;
    document.head.appendChild(st);
    el.innerHTML =
      '<div class="gv-wrap">' +
      '<canvas class="gv-canvas"></canvas>' +
      '<svg class="gv-svg" style="display:none"></svg>' +
      '<div class="gv-toolbar">' +
      '<input class="gv-search" placeholder="filter nodes (enter = jump)" ' +
      'spellcheck="false">' +
      '<button class="gv-btn" data-act="zoomout" title="zoom out">−</button>' +
      '<button class="gv-btn" data-act="zoomin" title="zoom in">+</button>' +
      '<button class="gv-btn" data-act="reset" title="reset view">reset</button>' +
      '<button class="gv-btn" data-act="rotate" title="slow auto-rotate">' +
      'rotate: off</button>' +
      '<button class="gv-btn" data-act="refresh" title="reload graph.json">' +
      'refresh</button>' +
      '<span class="gv-kinds" style="display:flex;gap:6px;flex-wrap:wrap">' +
      '</span>' +
      '<span class="gv-badge">…</span>' +
      '</div>' +
      '<div class="gv-hint">drag rotate · wheel zoom · click node · esc clear</div>' +
      '<div class="gv-tip"></div>' +
      '<div class="gv-panel"><button class="gv-x" title="close">✕</button>' +
      '<div class="gv-panel-body"></div></div>' +
      '<div class="gv-legend"></div>' +
      '<div class="gv-err"></div>' +
      '</div>';
    wrap = el.querySelector('.gv-wrap');
    tip = el.querySelector('.gv-tip');
    panel = el.querySelector('.gv-panel');
    badge = el.querySelector('.gv-badge');
    canvasBox = el.querySelector('.gv-canvas');
    svgBox = el.querySelector('.gv-svg');
    ctx = canvasBox.getContext ? canvasBox.getContext('2d') : null;
    mode = (/[?&]graph2d=1/.test(location.search) || !ctx) ? '2d' : '3d';
    wire();
    if (mode === '3d') {
      bindPointer();
      if (typeof ResizeObserver === 'function')
        new ResizeObserver(function () { resize(); }).observe(wrap);
    } else {
      canvasBox.style.display = 'none';
      svgBox.style.display = 'block';
      bindSvg();
    }
    window.addEventListener('resize', resize);
    window.addEventListener('keydown', onKey);
    window.addEventListener('hashchange', onHash);
  }

  function wire() {
    root.querySelector('.gv-toolbar').addEventListener('click', function (e) {
      var b = e.target.closest('[data-act]');
      if (!b) return;
      var act = b.dataset.act;
      if (act === 'zoomin') zoom(0.82);
      else if (act === 'zoomout') zoom(1.22);
      else if (act === 'reset') {
        cam.th = 0.6; cam.ph = 0.35; cam.r = 640; redraw();
      } else if (act === 'rotate') setSpin(b.textContent.indexOf('off') >= 0);
      else if (act === 'refresh') load();
    });
    root.querySelector('.gv-kinds').addEventListener('click', function (e) {
      var c = e.target.closest('[data-kind]');
      if (!c) return;
      var k = c.dataset.kind;
      kindOff[k] = !kindOff[k];
      c.classList.toggle('off', !!kindOff[k]);
      redraw();
    });
    root.querySelector('.gv-legend').addEventListener('click', function (e) {
      var c = e.target.closest('[data-state]');
      if (!c) return;
      var s = c.dataset.state;
      stateOff[s] = !stateOff[s];
      c.classList.toggle('off', !!stateOff[s]);
      redraw();
    });
    var sb = root.querySelector('.gv-search');
    sb.addEventListener('input', function () {
      var q = sb.value.trim().toLowerCase();
      matches = null;
      if (q.length >= 2 && data) {
        matches = {};
        data.nodes.forEach(function (nd) {
          if ((nd.label + ' ' + nd.id + ' ' + (nd.detail || '') +
               ' ' + nd.kind).toLowerCase().indexOf(q) >= 0)
            matches[nd.id] = 1;
        });
      }
      redraw();
    });
    sb.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter' || !matches) return;
      for (var i = 0; i < data.nodes.length; i++) {
        if (matches[data.nodes[i].id]) {
          jumpTo(data.nodes[i].id); select(data.nodes[i].id); break;
        }
      }
    });
    panel.querySelector('.gv-x').addEventListener('click', clearSel);
    window.HnghPoll.start(tickBadge, { interval: 5000 });
    pollTimer = window.HnghPoll.start(autoLoad, { interval: POLL_MS });
  }

  function visible(nd) {
    return !kindOff[nd.kind] && !stateOff[nd.state];
  }
  function adjacent(id) {
    var s = {}; s[id] = 1;
    data.edges.forEach(function (e) {
      if (e.src === id) s[e.dst] = 1;
      if (e.dst === id) s[e.src] = 1;
    });
    return s;
  }
  function focusSet() {
    // neighbors of hover and selection, merged; null = no dimming
    if (!hoverId && !selId) return null;
    var f = {};
    if (hoverId) { var a = adjacent(hoverId); for (var k in a) f[k] = 1; }
    if (selId && selId !== hoverId) {
      var b = adjacent(selId); for (var k2 in b) f[k2] = 1;
    }
    return f;
  }
  function byId(id) {
    return idxOf.hasOwnProperty(id) ? data.nodes[idxOf[id]] : null;
  }

  // camera orbit (th around Y, ph around X) + perspective projection into
  // the preallocated scr arrays — no allocation in the draw path
  function project() {
    var ct = Math.cos(cam.th), st = Math.sin(cam.th);
    var cp = Math.cos(cam.ph), sp = Math.sin(cam.ph);
    var f = FOCAL * (H / 2), n = data.nodes.length;
    for (var i = 0; i < n; i++) {
      var p = pos[data.nodes[i].id];
      var x = p[0] * ct - p[2] * st;
      var z1 = p[0] * st + p[2] * ct;
      var y = p[1] * cp - z1 * sp;
      var z = cam.r - (p[1] * sp + z1 * cp);
      var s = f / Math.max(20, z);
      scr.x[i] = W / 2 + x * s;
      scr.y[i] = H / 2 + y * s;
      scr.s[i] = s;
      scr.d[i] = z;
    }
  }

  function resize() {
    if (!root || !wrap) return;
    var b = wrap.getBoundingClientRect();
    W = Math.max(60, b.width); H = Math.max(60, b.height);
    var dpr = window.devicePixelRatio || 1;
    canvasBox.width = Math.round(W * dpr);
    canvasBox.height = Math.round(H * dpr);
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (mode === '2d') { svgBox.setAttribute('viewBox', '0 0 ' + W + ' ' + H); }
    redraw();
  }
  function zoom(k) {
    cam.r = clamp(cam.r * k, 320, 2400);
    redraw();
  }
  function redraw() {
    if (!data) return;
    if (mode === '3d') draw3d(); else render2d();
  }

  function draw3d() {
    if (!ctx || !data) return;
    project();
    ctx.clearRect(0, 0, W, H);
    var f = focusSet(), m = matches;
    var nodes = data.nodes, R = 190, k, i, j;
    // edge pass — plain lines, depth-tinted; focus edges pop in blue
    ctx.lineWidth = 1;
    for (k = 0; k < data.edges.length; k++) {
      i = eSrc[k]; j = eDst[k];
      if (i < 0 || j < 0) continue;
      var na = nodes[i], nb = nodes[j];
      if (!visible(na) || !visible(nb)) continue;
      var hot = !!(f && f[na.id] && f[nb.id]);
      if (f && !hot) ctx.globalAlpha = 0.07;
      else {
        var zavg = (scr.d[i] + scr.d[j]) / 2;
        ctx.globalAlpha = f ? 0.85 : clamp(0.5 - 0.22 * zavg / (cam.r + R), 0.1, 0.5);
      }
      ctx.strokeStyle = hot ? '#58a6ff' : '#3a4a5a';
      ctx.beginPath();
      ctx.moveTo(scr.x[i], scr.y[i]);
      ctx.lineTo(scr.x[j], scr.y[j]);
      ctx.stroke();
    }
    // node pass — painter's algorithm, far -> near
    order.sort(function (a, b) { return scr.d[b] - scr.d[a]; });
    ctx.font = '10px ui-monospace,monospace';
    for (var q = 0; q < order.length; q++) {
      i = order[q];
      var nd = nodes[i];
      if (!visible(nd)) continue;
      var r = Math.max(1.2, KIND_SIZE[nd.kind] * scr.s[i] * 1.15);
      var a = clamp(1.15 - scr.d[i] / (cam.r + R), 0.3, 1);
      var hotN = !!(f && f[nd.id]);
      if (f && !hotN) a *= 0.16;
      var col = nd.kind === 'kernel' ? COLORS.kernel : (COLORS[nd.state] || COLORS.neutral);
      ctx.globalAlpha = a;
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.arc(scr.x[i], scr.y[i], r, 0, 6.2832);
      ctx.fill();
      if (r >= 2.4) { // cheap specular gloss
        ctx.globalAlpha = a * 0.22;
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.arc(scr.x[i] - r * 0.3, scr.y[i] - r * 0.35, r * 0.5, 0, 6.2832);
        ctx.fill();
      }
      if (selId === nd.id) {
        ctx.globalAlpha = a; ctx.strokeStyle = '#58a6ff'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(scr.x[i], scr.y[i], r + 5, 0, 6.2832); ctx.stroke();
      } else if (hoverId === nd.id) {
        ctx.globalAlpha = a * 0.8; ctx.strokeStyle = '#f0f6fc'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(scr.x[i], scr.y[i], r + 4, 0, 6.2832); ctx.stroke();
      }
      if (m && m[nd.id]) {
        ctx.globalAlpha = a; ctx.strokeStyle = '#d29922'; ctx.lineWidth = 1;
        ctx.setLineDash([3, 3]);
        ctx.beginPath(); ctx.arc(scr.x[i], scr.y[i], r + 6, 0, 6.2832); ctx.stroke();
        ctx.setLineDash([]);
      }
      if (r >= 3 || hotN || (m && m[nd.id])) {
        ctx.globalAlpha = a * 0.9;
        ctx.fillStyle = hotN ? '#e6edf3' : '#8b949e';
        ctx.fillText(nd.label, scr.x[i] + r + 4, scr.y[i] + 3);
      }
    }
    ctx.globalAlpha = 1;
  }

  var spinning = false, spinT = 0, down = null, dragged = false, over = false;

  function setSpin(on) {
    spinning = on;
    var b = root.querySelector('[data-act="rotate"]');
    if (b) b.textContent = 'rotate: ' + (on ? 'on' : 'off');
    spinT = 0;
    if (on) requestAnimationFrame(spinLoop);
  }
  function spinLoop(t) {
    if (!spinning) return;
    requestAnimationFrame(spinLoop);
    if (!spinT) { spinT = t || performance.now(); return; }
    var now = t || performance.now();
    var dt = Math.min(0.1, (now - spinT) / 1000);
    spinT = now;
    if (down || over || document.hidden) return; // hands off = pause
    cam.th += 0.12 * dt;
    draw3d();
  }

  function bindPointer() {
    canvasBox.addEventListener('pointerdown', function (e) {
      down = { x: e.clientX, y: e.clientY, th: cam.th, ph: cam.ph };
      dragged = false;
      try { canvasBox.setPointerCapture(e.pointerId); } catch (err) {}
    });
    canvasBox.addEventListener('pointermove', function (e) {
      if (down) {
        var dx = e.clientX - down.x, dy = e.clientY - down.y;
        if (dragged || Math.abs(dx) > 4 || Math.abs(dy) > 4) {
          dragged = true;
          hoverClear();
          cam.th = down.th + dx * 0.006;
          cam.ph = clamp(down.ph + dy * 0.006, -1.35, 1.35);
          draw3d();
          return;
        }
      }
      hoverAt(e);
    });
    canvasBox.addEventListener('pointerup', function (e) {
      var wasDrag = dragged;
      down = null; dragged = false;
      if (wasDrag) return;
      var id = pickAt(e);
      if (id) select(id); else clearSel();
    });
    canvasBox.addEventListener('pointerenter', function () { over = true; });
    canvasBox.addEventListener('pointerleave', function () {
      over = false;
      if (!down) hoverClear();
    });
    canvasBox.addEventListener('wheel', function (e) {
      e.preventDefault();
      zoom(e.deltaY > 0 ? 1.12 : 0.9);
    }, { passive: false });
  }

  // nearest visible node under the cursor; order is far->near so scan it
  // backwards = nearest first
  function pickAt(e) {
    if (!data) return null;
    var b = canvasBox.getBoundingClientRect();
    var mx = e.clientX - b.left, my = e.clientY - b.top;
    for (var q = order.length - 1; q >= 0; q--) {
      var i = order[q], nd = data.nodes[i];
      if (!visible(nd)) continue;
      var r = Math.max(4, KIND_SIZE[nd.kind] * scr.s[i] * 1.15 + 3);
      var dx = scr.x[i] - mx, dy = scr.y[i] - my;
      if (dx * dx + dy * dy <= r * r) return nd.id;
    }
    return null;
  }

  function hoverAt(e) {
    if (!data) return;
    var id = pickAt(e);
    if (id !== hoverId) {
      hoverId = id;
      if (id) showCard(e, byId(id));
      else tip.style.display = 'none';
      redraw();
    } else if (id) {
      moveCard(e);
    }
  }
  function hoverClear() {
    if (!hoverId) return;
    hoverId = null;
    tip.style.display = 'none';
    redraw();
  }
  function showCard(e, nd) {
    if (!nd) return;
    tip.innerHTML = cardHtml(nd);
    tip.style.display = 'block';
    moveCard(e);
  }
  function moveCard(e) {
    var b = wrap.getBoundingClientRect();
    var x = e.clientX - b.left + 14, y = e.clientY - b.top + 14;
    if (x + 360 > b.width) x = e.clientX - b.left - 360 - 10;
    if (y + 200 > b.height) y = Math.max(0, b.height - 210);
    tip.style.left = Math.max(4, x) + 'px';
    tip.style.top = Math.max(4, y) + 'px';
  }

  function select(id) {
    selId = id;
    var nd = byId(id);
    if (!nd) { clearSel(); return; }
    var d = parseDetail(nd.detail);
    var nbrs = Object.keys(adjacent(id)).length - 1;
    var h = '<h3>' + esc(nd.label) + '</h3>' +
      '<div class="gv-kind" style="margin-bottom:6px">' +
      esc(nd.kind) + ' · ' + esc(nd.state) + '</div>' +
      (d.pairs.length ? d.pairs.map(rowHtml).join('') : '') +
      (d.tail ? '<div style="margin-top:6px;opacity:.8">' + esc(d.tail) + '</div>' : '') +
      '<div style="margin-top:8px;color:#8b949e">' + nbrs + ' direct neighbor(s)</div>';
    if (nd.kind === 'research-line')
      h += '<div style="margin-top:6px"><a href="#tab-research">open research →</a></div>';
    root.querySelector('.gv-panel-body').innerHTML = h;
    panel.style.display = 'block';
    try {
      history.replaceState(null, '', '#tab-graph/n=' + encodeURIComponent(id));
    } catch (err) {}
    redraw();
  }

  function clearSel() {
    if (!selId) return;
    selId = null;
    panel.style.display = 'none';
    try { history.replaceState(null, '', '#tab-graph'); } catch (err) {}
    redraw();
  }
  function hashNode() {
    var m = /#tab-graph\/n=([^&]+)/.exec(location.hash);
    return m ? decodeURIComponent(m[1]) : null;
  }
  function onHash() {
    if (!data) return;
    var id = hashNode();
    if (id && byId(id)) { if (selId !== id) select(id); }
    else if (!id) clearSel();
  }
  function onKey(e) {
    if (e.key !== 'Escape') return;
    var pg = document.getElementById('p-graph');
    if (!pg || pg.hidden) return;
    hoverClear(); clearSel(); redraw();
  }
  function jumpTo(id) {
    var p = pos[id];
    if (!p) return;
    cam.th = Math.atan2(p[0], p[2]);
    cam.ph = Math.atan2(p[1], Math.hypot(p[0], p[2]));
    redraw();
  }
  function tickBadge() {
    if (!lastLoad) return;
    var a = Math.round((Date.now() - lastLoad) / 1000);
    badge.textContent = a < 5 ? 'live' :
      (a < 90 ? 'data ' + a + 's old' : 'data ' + Math.round(a / 60) + 'm old');
    badge.classList.toggle('fresh', a < 90);
  }

  function buildChips() {
    var counts = {};
    data.nodes.forEach(function (nd) {
      counts[nd.kind] = (counts[nd.kind] || 0) + 1;
    });
    root.querySelector('.gv-kinds').innerHTML = KINDS.filter(function (k) {
      return counts[k];
    }).map(function (k) {
      return '<span class="gv-chip" data-kind="' + k + '">' + esc(k) +
        ' <b>' + counts[k] + '</b></span>';
    }).join('');
    root.querySelector('.gv-legend').innerHTML = STATES.map(function (s) {
      return '<span class="gv-chip" data-state="' + s + '">' +
        '<i class="gv-dot" style="background:' + COLORS[s] + '"></i>' +
        (s === 'neutral' ? 'declared' : s) + '</span>';
    }).join('');
  }

  // auto-refresh: only the active graph tab fetches. A hidden #p-graph
  // panel means another dashboard tab is in front — skip silently (no
  // fetch) and let the poll re-check next tick; HnghPoll itself already
  // pauses the whole timer while the browser tab is hidden.
  function graphTabVisible() {
    var pg = document.getElementById('p-graph');
    return !!pg && !pg.hidden;
  }
  function autoLoad() {
    return graphTabVisible() ? load() : undefined;
  }

  function load() {
    badge.textContent = '…';
    fetchJson('/graph.json').then(function (g) {
      if (!g || !g.nodes || !g.nodes.length) throw new Error('empty graph');
      setData(g);
      buildChips();
      resize();
      lastLoad = Date.now();
      tickBadge();
      var sum = document.getElementById('graph-sum');
      if (sum) {
        var nAl = g.nodes.filter(function (n) { return n.state === 'alerting'; }).length;
        sum.textContent = g.nodes.length + ' nodes · ' + g.edges.length +
          ' edges · ' + nAl + ' alerting · mode ' + mode.toUpperCase();
      }
      root.querySelector('.gv-err').style.display = 'none';
      if (pendSel) { var p = pendSel; pendSel = null; if (byId(p)) select(p); }
    }).catch(function (err) {
      var eb = root.querySelector('.gv-err');
      eb.textContent = 'graph feed unavailable: ' + err.message +
        ' — retry with the refresh button';
      eb.style.display = 'flex';
      badge.textContent = 'feed error';
      badge.classList.remove('fresh');
    });
  }

  window.GraphView = {
    init: function (el) {
      if (inited) return;
      inited = true;
      mount(el);
      pendSel = hashNode();
      // first tick of the auto-refresh poll below performs the initial
      // load (it fires immediately), so init does not fetch separately
    },
    refresh: function () { if (inited) load(); }
  };

  // ---- SVG fallback (?graph2d=1 or no canvas 2d): flat layout, same
  // cards, filters, search, panel ------------------------------------
  function render2d() {
    if (!data || !svgBox) return;
    var f = focusSet(), m = matches;
    var cx = W / 2, cy = H / 2, sc = Math.min(W, H) / 480;
    var s = '';
    data.edges.forEach(function (e) {
      var a = pos[e.src], b = pos[e.dst];
      if (!a || !b) return;
      var na = byId(e.src), nb = byId(e.dst);
      if (!visible(na) || !visible(nb)) return;
      var hot = f && f[e.src] && f[e.dst];
      s += '<line class="' + (hot ? 'gv-hi' : '') + '" x1="' +
        (cx + a[0] * sc) + '" y1="' + (cy + a[1] * sc) + '" x2="' +
        (cx + b[0] * sc) + '" y2="' + (cy + b[1] * sc) + '">';
    });
    data.nodes.forEach(function (nd) {
      if (!visible(nd)) return;
      var p = pos[nd.id], x = cx + p[0] * sc, y = cy + p[1] * sc;
      var r = Math.max(2, KIND_SIZE[nd.kind] * sc * 2.2);
      var col = nd.kind === 'kernel' ? COLORS.kernel : (COLORS[nd.state] || COLORS.neutral);
      var dim = f && !f[nd.id] ? ' class="gv-dim"' : '';
      var big = nd.kind === 'kernel' || nd.kind === 'leg' || nd.kind === 'service' ||
        (f && f[nd.id]) || (m && m[nd.id]);
      s += '<circle' + dim + ' data-id="' + esc(nd.id) + '" cx="' + x +
        '" cy="' + y + '" r="' + r + '" fill="' + col + '">' +
        '<title>' + esc(nd.label) + '</title></circle>';
      if (big) s += '<text' + dim + (m && m[nd.id] ? ' class="gv-hi"' : '') +
        ' x="' + (x + r + 3) + '" y="' + (y + 3) + '">' + esc(nd.label) + '</text>';
    });
    svgBox.innerHTML = s;
  }

  function bindSvg() {
    svgBox.addEventListener('pointermove', function (e) {
      var c = e.target.closest ? e.target.closest('circle') : null;
      if (c && byId(c.dataset.id)) {
        hoverId = c.dataset.id;
        showCard(e, byId(hoverId));
        render2d();
      } else if (!c) {
        hoverClear();
      } else {
        moveCard(e);
      }
    });
    svgBox.addEventListener('pointerleave', hoverClear);
    svgBox.addEventListener('click', function (e) {
      var c = e.target.closest ? e.target.closest('circle') : null;
      if (c && byId(c.dataset.id)) select(c.dataset.id);
      else clearSel();
    });
  }

})();
