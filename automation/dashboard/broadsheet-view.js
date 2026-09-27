/* broadsheet-view - the WebGL broadsheet front page. Standalone v1 (09-27).
   Mounted by broadsheet.html. Three layers:

   1. PAPER - raw WebGL2 fullscreen fragment shader behind the DOM:
      procedural newsprint (fiber noise, flecks, vignette), a dappled
      leaf-shadow of two-three soft rotated noise layers multiply-blended
      at very low opacity, drifting on a ~50s breath (never flicker), and
      a scroll-linked color temperature (warm at the masthead, cool deep
      in the archive). No WebGL2 -> plain CSS paper, page continues.

   2. MAP - three.js (vendored r160) megastructure node graph: static
      seed nodes (operator host, kernel core, automation ring, cadence
      tiers, userspace home, remote origin) + LIVE fleet.json nodes with
      online/offline colors. Unknown fields print 'unresolved', never a
      guess. Drag orbits, wheel zooms (throttled), rotation is slow. Any
      failure falls back to a 2D SVG list.

   3. STREAM - CSS multicol newspaper flow over newspaper.json:
      score-ranked articles, kicker + queue chip, headline/deck/lede
      printed open, click to expand to column-span:all, operator choice
      cards POSTing the token-gated endpoints, infinite loop through
      stored editions with a FRESH EDITION divider at each wrap.

   Honesty rules (newspaper-view v2 pattern): the masthead date is the
   feed's own stamp, never a client-prayed Date; every rendered string
   passes esc(); an unreachable feed shows banner #papererr, never a
   fabricated article. Refresh ONLY via the poll chain or the refresh
   button - raw timer loops are test-banned (poll-hygiene contract). */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;',
               '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function showErr(msg) {
    var b = document.getElementById("papererr");
    if (!b) return;
    b.hidden = false;
    b.textContent = 'the press is stalled: ' + msg;
  }

  // ---------- bounded fetches (newspaper-view pattern) ----------
  function fetchText(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error(url + ' HTTP ' + r.status);
        return r.text();
      })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  function fetchJSON(url, ms) {
    return fetchText(url, ms).then(function (s) {
      return JSON.parse(s); // parse errors count as feed failure
    });
  }
  // ---------- token plumbing (app.js pattern) ----------
  function hnghToken() {
    var m = document.querySelector('meta[name="hngh-token"]');
    return m ? (m.getAttribute('content') || '') : '';
  }
  function postJson(url, body, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, {
      method: 'POST', cache: 'no-store', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json',
                 'X-Hngh-Token': hnghToken() },
      body: JSON.stringify(body || {})
    }).then(function (r) {
      clearTimeout(t);
      return r.json().catch(function () { return {}; })
        .then(function (j) {
          if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
          return j;
        });
    }).catch(function (e) { clearTimeout(t); throw e; });
  }
  // masthead date: the feed's own stamp, never Date()
  function todayFromStamp(feed) {
    var g = feed && feed.generated;
    return (typeof g === 'string' && g.length >= 10) ? g.slice(0, 10) : '';
  }

  // ================= 1. PAPER (raw WebGL2) =================
  var PAPER_FRAG = [
    'precision highp float;',
    'uniform vec2 u_res;',
    'uniform float u_time;',
    'uniform float u_scroll;',
    'float hash(vec2 p) {',
    '  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);',
    '}',
    'float vnoise(vec2 p) {',
    '  vec2 i = floor(p); vec2 f = fract(p);',
    '  vec2 u = f * f * (3.0 - 2.0 * f);',
    '  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),',
    '             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),',
    '             u.y);',
    '}',
    'float fbm(vec2 p) {',
    '  float v = 0.0; float a = 0.5;',
    '  for (int k = 0; k < 4; k++) {',
    '    v += a * vnoise(p); p = p * 2.03 + vec2(17.3, 9.1); a *= 0.5;',
    '  }',
    '  return v;',
    '}',
    'mat2 rot(float a) { float c = cos(a); float s = sin(a);',
    '  return mat2(c, -s, s, c); }',
    // one dapple layer: soft thresholded fbm, rotated, drifting slowly
    'float dapple(vec2 uv, float ang, float scale, float phase) {',
    '  vec2 p = rot(ang) * uv * scale + vec2(',
    '    u_time * 0.013 + phase, u_time * 0.007 * sin(phase) - phase);',
    '  float n = fbm(p);',
    '  return smoothstep(0.52, 0.86, n);',
    '}',
    'void main() {',
    '  vec2 uv = gl_FragCoord.xy / u_res;',
    // warm newsprint base (ink-friendly tint)
    '  vec3 col = vec3(0.957, 0.941, 0.902);',
    // fine anisotropic fiber noise: long horizontally, tight vertically
    '  float fiber = fbm(uv * vec2(110.0, 760.0));',
    '  col *= 1.0 + (fiber - 0.5) * 0.045;',
    // sparse darker flecks in the stock
    '  vec2 fc = uv * u_res * 0.14;',
    '  vec2 cell = floor(fc);',
    '  float fleck = step(0.9975, hash(cell + 4.7)) *',
    '    step(length(fract(fc) - 0.5), 0.22);',
    '  col *= 1.0 - fleck * 0.10;',
    // dappled leaf shadow: 3 rotated soft layers, each <= 0.055, drift ~50s
    '  float sh = dapple(uv, 0.5, 3.1, 0.0) * 0.055;',
    '  sh += dapple(uv, 2.1, 4.3, 13.7) * 0.045;',
    '  sh += dapple(uv, 4.2, 2.4, 27.1) * 0.035;',
    '  col *= 1.0 - clamp(sh, 0.0, 0.12);',
    // gentle emboss: slight top-left light gradient
    '  float emb = (uv.x + (1.0 - uv.y)) * 0.5;',
    '  col *= 1.0 + (emb - 0.5) * 0.02;',
    // vignette
    '  float vig = smoothstep(1.25, 0.35, length(uv - 0.5) * 1.6);',
    '  col *= 0.955 + 0.045 * vig;',
    // scroll-linked temperature: warm masthead -> neutral -> cool deep
    '  vec3 warm = vec3(1.030, 1.000, 0.940);',
    '  vec3 cool = vec3(0.965, 0.990, 1.045);',
    '  vec3 tint = mix(warm, vec3(1.0), smoothstep(0.0, 0.45, u_scroll));',
    '  tint = mix(tint, cool, smoothstep(0.5, 1.0, u_scroll));',
    '  col *= tint;',
    '  gl_FragColor = vec4(col, 1.0);',
    '}'
  ].join('\n');
  var PAPER_VERT =
    'attribute vec2 a_pos; void main() { gl_Position = vec4(a_pos, 0.0, 1.0); }';

  var paper = { gl: null, prog: null, uRes: null, uTime: null, uScroll: null,
                last: 0, raf: 0, dead: false, still: false };

  function paperInit() {
    var cv = $('paper-canvas');
    if (!cv) return;
    var rmq = matchMedia('(prefers-reduced-motion: reduce)');
    paper.still = rmq.matches;
    if (rmq.addEventListener) {
      rmq.addEventListener('change', function (ev) { paper.still = ev.matches; });
    }
    var gl = cv.getContext('webgl2', { antialias: false, alpha: false });
    if (!gl) { paperFallback('WebGL2 unavailable'); return; }
    function sh(type, src) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        throw new Error(gl.getShaderInfoLog(s) || 'shader compile failed');
      }
      return s;
    }
    try {
      var prog = gl.createProgram();
      gl.attachShader(prog, sh(gl.VERTEX_SHADER, PAPER_VERT));
      gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, PAPER_FRAG));
      gl.linkProgram(prog);
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
        throw new Error(gl.getProgramInfoLog(prog) || 'link failed');
      }
      paper.prog = prog; paper.gl = gl;
      paper.uRes = gl.getUniformLocation(prog, 'u_res');
      paper.uTime = gl.getUniformLocation(prog, 'u_time');
      paper.uScroll = gl.getUniformLocation(prog, 'u_scroll');
      var buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER,
        new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
      var loc = gl.getAttribLocation(prog, 'a_pos');
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      gl.useProgram(prog);
    } catch (e) { paperFallback('paper shader: ' + e.message); return; }
    // context loss: pause; restore: rebuild; unrecoverable: CSS paper
    cv.addEventListener('webglcontextlost', function (ev) {
      ev.preventDefault(); paper.dead = true;
    });
    cv.addEventListener('webglcontextrestored', function () {
      paper.dead = false; paperInit();
    });
    paperResize();
    if (!paper.raf) paper.raf = requestAnimationFrame(paperFrame);
  }
  function paperFallback(why) {
    document.body.classList.add('paper-fallback'); // fail-open readability
    var cv = $('paper-canvas');
    if (cv) cv.remove();
    if (window.console) console.warn('broadsheet paper fallback: ' + why);
  }
  function paperResize() {
    var gl = paper.gl; if (!gl) return;
    var dpr = Math.min(window.devicePixelRatio || 1, 1.6);
    var w = Math.floor(innerWidth * dpr), h = Math.floor(innerHeight * dpr);
    if (gl.canvas.width !== w || gl.canvas.height !== h) {
      gl.canvas.width = w; gl.canvas.height = h;
      gl.viewport(0, 0, w, h);
    }
  }
  function paperFrame(ts) {
    paper.raf = requestAnimationFrame(paperFrame); // ~30fps cap, pause hidden
    if (paper.dead || document.hidden) return;
    if (ts - paper.last < 33) return;
    paper.last = ts;
    var gl = paper.gl; if (!gl) return;
    paperResize();
    var max = document.documentElement.scrollHeight - innerHeight;
    var sc = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 0;
    gl.uniform2f(paper.uRes, gl.canvas.width, gl.canvas.height);
    gl.uniform1f(paper.uTime, paper.still ? 0 : (ts % 1e7) / 1000);
    gl.uniform1f(paper.uScroll, sc);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  // ================= 2. MAP (three.js megastructure) =================
  // Static seed topology of the hngh megastructure + live fleet nodes.
  // Positions are editorial, not measured; unknown names stay 'unresolved'.
  var MAP_SEEDS = [
    { id: 'operator-host', label: 'operator host', layer: 2, x: 0, z: 0 },
    { id: 'kernel-core', label: 'kernel core', layer: 1, x: 0, z: 0 },
    { id: 'automation', label: 'automation ring', layer: 0, x: 2.6, z: 0.4 },
    { id: 'cadence-hour', label: 'cadence: hour', layer: 0, x: -1.8, z: 2.2 },
    { id: 'cadence-subhour', label: 'cadence: subhour', layer: 0, x: -2.4, z: -1.6 },
    { id: 'cadence-calendar', label: 'cadence: calendar', layer: 0, x: 1.2, z: -2.8 },
    { id: 'userspace-home', label: 'userspace home', layer: -1, x: 0.6, z: 3.2 },
    { id: 'remote-origin', label: 'remote origin', layer: -1, x: -3.4, z: 0.8 }
  ];
  var MAP_EDGES = [
    ['operator-host', 'kernel-core'], ['kernel-core', 'automation'],
    ['kernel-core', 'cadence-hour'], ['kernel-core', 'cadence-subhour'],
    ['kernel-core', 'cadence-calendar'], ['kernel-core', 'userspace-home'],
    ['automation', 'remote-origin']
  ];
  var mapState = { scene: null, cam: null, rend: null, raf: 0,
                   dist: 9, theta: 0.6, phi: 1.15, drag: null, lastWheel: 0 };
  function mapLabel(THREE, text, color) {
    var c = document.createElement('canvas');
    c.width = 256; c.height = 64;
    var g = c.getContext('2d');
    g.fillStyle = 'rgba(244,240,230,0.75)';
    g.fillRect(0, 0, 256, 64);
    g.font = 'bold 26px sans-serif';
    g.fillStyle = color || '#26221c';
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(text.slice(0, 22), 128, 32);
    var tex = new THREE.CanvasTexture(c);
    tex.needsUpdate = true;
    var spr = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex }));
    spr.scale.set(1.7, 0.42, 1);
    return spr;
  }
  function mapNodeDot(THREE, color) {
    return new THREE.Mesh(new THREE.SphereGeometry(0.13, 12, 10),
      new THREE.MeshLambertMaterial({ color: color }));
  }
  function mapInit(fleetNodes) {
    var host = $('map3d');
    if (!host) return;
    if (mapState.built) return; // one build only (init + refresh race)
    mapState.built = true;
    import('./vendor/three.module.min.js').then(function (THREE) {
      try { mapBuild(THREE, host, fleetNodes); }
      catch (e) { mapFallback(fleetNodes, e.message); }
    }).catch(function (e) { mapFallback(fleetNodes, e.message); });
  }
  function mapBuild(THREE, host, fleetNodes) {
    var w = host.clientWidth, h = host.clientHeight;
    var rend = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    if (!rend.getContext()) throw new Error('map webgl unavailable');
    rend.setSize(w, h);
    rend.setPixelRatio(Math.min(devicePixelRatio || 1, 1.6));
    host.appendChild(rend.domElement);
    var scene = new THREE.Scene();
    var cam = new THREE.PerspectiveCamera(46, w / h, 0.1, 100);
    scene.add(new THREE.AmbientLight(0xffffff, 0.75));
    var sun = new THREE.DirectionalLight(0xfff4e0, 0.9);
    sun.position.set(4, 6, 3);
    scene.add(sun);
    var byId = {};
    MAP_SEEDS.forEach(function (s) {
      var y = 0.4 + s.layer * 1.15;
      var dot = mapNodeDot(THREE, s.id === 'kernel-core' ? 0x7a3a2e : 0x26221c);
      dot.position.set(s.x, y, s.z);
      var lab = mapLabel(THREE, s.label);
      lab.position.set(s.x, y + 0.34, s.z);
      scene.add(dot); scene.add(lab);
      byId[s.id] = [s.x, y, s.z];
    });
    MAP_EDGES.forEach(function (e) {
      var a = byId[e[0]], b = byId[e[1]];
      if (!a || !b) return;
      var g = new THREE.BufferGeometry().setFromPoints(
        [new THREE.Vector3(a[0], a[1], a[2]),
         new THREE.Vector3(b[0], b[1], b[2])]);
      scene.add(new THREE.Line(g,
        new THREE.LineBasicMaterial({ color: 0x8a8070 })));
    });
    // LIVE fleet nodes on a lower ground ring; green = online.
    (fleetNodes || []).forEach(function (n, i) {
      var ang = (i / Math.max(1, fleetNodes.length)) * Math.PI * 2;
      var x = Math.cos(ang) * 4.4, z = Math.sin(ang) * 4.4;
      var named = n.name && n.name !== '?';
      var dot = mapNodeDot(THREE, n.online ? 0x4a6b3a : 0x8a4a3a);
      dot.position.set(x, -0.6, z);
      var lab = mapLabel(THREE, named ? n.name : 'unresolved',
        n.online ? '#35502a' : '#7a4030');
      lab.position.set(x, -0.25, z);
      scene.add(dot); scene.add(lab);
      var g = new THREE.BufferGeometry().setFromPoints(
        [new THREE.Vector3(0, 0.4, 0), new THREE.Vector3(x, -0.6, z)]);
      scene.add(new THREE.Line(g,
        new THREE.LineBasicMaterial({ color: 0xb9b09c })));
    });
    mapState.scene = scene; mapState.cam = cam; mapState.rend = rend;
    mapBindInput(host);
    mapResize();
    if (!mapState.raf) mapState.raf = requestAnimationFrame(mapFrame);
  }
  function mapBindInput(host) {
    host.addEventListener('pointerdown', function (ev) {
      mapState.drag = { x: ev.clientX, y: ev.clientY };
    });
    addEventListener('pointerup', function () { mapState.drag = null; });
    addEventListener('pointermove', function (ev) {
      if (!mapState.drag) return;
      mapState.theta -= (ev.clientX - mapState.drag.x) * 0.005;
      mapState.phi = Math.min(2.6, Math.max(0.5,
        mapState.phi - (ev.clientY - mapState.drag.y) * 0.005));
      mapState.drag = { x: ev.clientX, y: ev.clientY };
    });
    host.addEventListener('wheel', function (ev) {
      ev.preventDefault();
      var now = Date.now();
      if (now - mapState.lastWheel < 120) return; // throttle zoom
      mapState.lastWheel = now;
      mapState.dist = Math.min(22, Math.max(4,
        mapState.dist + (ev.deltaY > 0 ? 0.7 : -0.7)));
    }, { passive: false });
    addEventListener('resize', mapResize);
  }
  function mapResize() {
    var s = mapState; if (!s.rend || !s.cam) return;
    var host = $('map3d'); if (!host) return;
    s.rend.setSize(host.clientWidth, host.clientHeight);
    s.cam.aspect = host.clientWidth / Math.max(1, host.clientHeight);
    s.cam.updateProjectionMatrix();
  }
  function mapFrame() {
    mapState.raf = requestAnimationFrame(mapFrame);
    var s = mapState;
    if (!s.scene || document.hidden) return;
    s.scene.rotation.y += 0.0012; // slow auto-rotation
    s.cam.position.set(
      s.dist * Math.sin(s.phi) * Math.cos(s.theta),
      s.dist * Math.cos(s.phi),
      s.dist * Math.sin(s.phi) * Math.sin(s.theta));
    s.cam.lookAt(0, 0, 0);
    s.rend.render(s.scene, s.cam);
  }
  // honest 2D fallback: an SVG-free list with status dots, real names only
  function mapFallback(fleetNodes, why) {
    var host = $('map3d');
    if (host) host.hidden = true;
    var fb = $('map-fallback');
    if (!fb) return;
    fb.hidden = false;
    var ul = document.createElement('ul');
    MAP_SEEDS.forEach(function (s) {
      var li = document.createElement('li');
      li.innerHTML = '<span class="map-dot on"></span>' + esc(s.label);
      ul.appendChild(li);
    });
    (fleetNodes || []).forEach(function (n) {
      var li = document.createElement('li');
      var named = n.name && n.name !== '?';
      li.innerHTML = '<span class="map-dot ' +
        (n.online ? 'on' : 'off') + '"></span>' +
        esc(named ? n.name : 'mesh node (unresolved)') +
        ' - ' + (n.online ? 'online' : 'offline') +
        (n.os ? ' - ' + esc(n.os) : '');
      ul.appendChild(li);
    });
    fb.appendChild(ul);
    if (window.console) console.warn('broadsheet map fallback: ' + why);
  }

  // ================= 3. STREAM (CSS multicol feed) =================
  // Endpoint whitelist: choice actions may only POST these two literals;
  // anything else in the feed is refused (fail closed).
  var ALLOWED_ENDPOINTS = ["/operator-item/handle", "/operator-item/dismiss"];
  var feed = { data: null, seq: [], n: 0, fixture: false };
  // dismissed ids persist across reloads (localStorage, cols pattern):
  // the composer snapshot can still list rows this browser sent away
  // until its next run; server ledger stays the real state and the
  // next composer edition reconciles this set down to nothing.
  var DISMISSED_KEY = 'broadsheet-dismissed';
  feed.dismissed = (function () {
    try { return JSON.parse(localStorage.getItem(DISMISSED_KEY) || '{}'); }
    catch (e) { return {}; } // malformed storage: fail open to fresh
  })();
  function dismissPersist(id) {
    feed.dismissed[id] = true;
    try { localStorage.setItem(DISMISSED_KEY,
      JSON.stringify(feed.dismissed)); } catch (e) { /* private mode */ }
  }

  function catColor(cat) { return 'var(--c-' + esc(cat) + ', var(--rule))'; }

  function articleEl(a) {
    var art = document.createElement('article');
    art.className = 'art' +
      (a.span === 3 ? ' span3' : a.span === 2 ? ' span2' : '');
    art.style.setProperty('--cat', catColor(a.category));
    var kick = '<div class="kicker">' +
      esc(a.kicker || a.category || 'bulletin');
    if (feed.data && feed.data.queues &&
        typeof feed.data.queues[a.category] === 'number') {
      kick += '<span class="qchip">queue ' +
        feed.data.queues[a.category] + '</span>';
    }
    kick += '</div>';
    var h = document.createElement('h2');
    h.innerHTML = kick + esc(a.headline || 'untitled');
    h.title = 'click to expand or collapse';
    art.appendChild(h);
    if (a.deck) {
      var d = document.createElement('p');
      d.className = 'deck'; d.textContent = a.deck;
      art.appendChild(d);
    }
    var body = Array.isArray(a.body) ? a.body : [];
    if (body.length) {
      var p0 = document.createElement('p');
      p0.textContent = body[0]; art.appendChild(p0);
    }
    body.slice(1).forEach(function (par) {
      var p = document.createElement('p');
      p.className = 'rest'; p.textContent = par;
      art.appendChild(p);
    });
    h.addEventListener('click', function () {
      art.classList.toggle('expanded');
    });
    if (a.span === 3) art.classList.add('expanded');
    art.insertAdjacentHTML('beforeend', ghostHTML(a.ghost));
    if (Array.isArray(a.sources) && a.sources.length) {
      var src = a.sources.map(function (s) { return s && s.label; })
        .filter(Boolean).join(' · ');
      if (src) {
        var sl = document.createElement('div');
        sl.className = 'srcline'; sl.textContent = 'source: ' + src;
        art.appendChild(sl);
      }
    }
    if (a.floodIds) art.appendChild(floodChoicesEl(a));
    else if (Array.isArray(a.choices) && a.choices.length)
      art.appendChild(choicesEl(a));
    return art;
  }

  // Ghost counsel: the composer may attach a signed summary paragraph;
  // it prints as a distinct ghost-desk block inside expanded articles.
  function ghostHTML(g) {
    if (!g || !g.voice || !g.text) return '';
    return '<div class="ghostdesk"><p>' + esc(g.text) + '</p>' +
      '<div class="ghost-sig">— ' + esc(g.voice) + ', ghost desk</div></div>';
  }

  // The empty-idea flood family: every "[feedback:idea] from email"
  // row is the same test artifact (unseamed ds.FEEDBACK in
  // test-dashboard-p1.py, one capture per make-test run since 09-11,
  // fixed 2026-09-27). Forty rows are not forty decisions - they are
  // one decision, printed once. Text arrives alert_row-formatted
  // ("job | kind | payload"), so match the needle anywhere.
  var FLOOD_NEEDLE = '[feedback:idea] from email';
  var FLOOD_MAX_DISMISS = 80;
  function isFlood(a) {
    return String(a && a.headline || '').indexOf(FLOOD_NEEDLE) !== -1 ||
      String(a && a.deck || '').indexOf(FLOOD_NEEDLE) !== -1;
  }
  function floodArticle(group) {
    var n = group.length;
    return {
      id: 'flood-family',
      category: 'operator',
      kicker: 'operator decision',
      headline: 'The empty-idea flood (' + n + ' items)',
      deck: 'one story, ' + n + ' copies · filed by the test suite',
      body: [
        'All ' + n + ' rows carry the same payload: the literal test ' +
          'string "[feedback:idea] from email", written by ' +
          'test-dashboard-p1.py through an unseamed FEEDBACK dir, one ' +
          'capture per make-test run since 09-11. The leak is fixed ' +
          '(2026-09-27); these rows are its residue. Verified: zero ' +
          'operator content in any of them.'
      ],
      span: 2,
      score: group[0].score || 0,
      sources: [{ label: 'operator items' }],
      floodIds: group.map(function (a) { return a.id; })
    };
  }
  function floodChoicesEl(a) {
    var bar = document.createElement('div');
    bar.className = 'choices';
    var progress = document.createElement('div');
    progress.className = 'choice-progress';
    var pending = a.floodIds.slice(0, FLOOD_MAX_DISMISS);
    var mk = function (label, outcome, run) {
      var row = document.createElement('div');
      row.className = 'choice-row';
      var b = document.createElement('button');
      b.className = 'choice';
      b.textContent = label;
      var out = document.createElement('span');
      out.className = 'outcome';
      out.textContent = outcome;
      b.addEventListener('click', function () {
        b.disabled = true;
        Promise.resolve(run(b)).catch(function (e) {
          b.disabled = false;
          progress.textContent = 'failed: ' + e.message;
          showErr('decision failed: ' + e.message);
        });
      });
      row.appendChild(b);
      row.appendChild(out);
      bar.appendChild(row);
    };
    var nLabel = a.floodIds.length;
    mk('Dismiss all ' + nLabel,
      'Clears the sheet; nothing of value is lost — every row carries ' +
        'the same empty string.',
      function (btn) {
        var batch = pending; pending = [];
        var done = 0, failed = [];
        progress.textContent = 'dismissing 0 of ' + batch.length + '…';
        bar.appendChild(progress);
        return batch.reduce(function (chain, id) {
          return chain.then(function () {
            return postJson('/operator-item/dismiss', { id: id })
              .then(function () {
                done += 1;
                floodDismissOne(id, a, bar);
                progress.textContent =
                  'dismissed ' + done + ' of ' + batch.length + '…';
              })
              .catch(function (e) {
                failed.push(id); // keep going; never fail the batch
                progress.textContent = 'failed: ' + id + ' - ' +
                  e.message + ' - continuing…';
              });
          });
        }, Promise.resolve()).then(function () {
          floodSettled(a, bar, progress, btn, done, failed);
        });
      });
    mk('Keep them',
      'The rows stay on the feed; this card returns in the next edition.',
      function () {
        progress.textContent = 'kept — no changes made.';
        bar.appendChild(progress);
        return Promise.resolve();
      });
    return bar;
  }
  // client-side truth: a dismissed id leaves the stream NOW. The
  // composer snapshot can be 30 minutes old and still carry the row,
  // so this card's count, the local feed data, and every later
  // rebuild/refetch must honor the dismissal (loadFeed filters
  // feed.dismissed for the same reason).
  function floodDismissOne(id, a, bar) {
    dismissPersist(id);
    var arts = feed.data && feed.data.articles;
    if (arts) for (var i = arts.length - 1; i >= 0; i--)
      if (arts[i] && arts[i].id === id) arts.splice(i, 1);
    var at = a.floodIds.indexOf(id);
    if (at !== -1) a.floodIds.splice(at, 1);
    floodCardCount(bar.closest('article'), a.floodIds.length);
  }
  function floodCardCount(card, n) {
    if (!card || !n) return;
    var h2 = card.querySelector('h2');
    if (!h2) return;
    var kick = h2.querySelector('.kicker');
    h2.innerHTML = (kick ? kick.outerHTML : '') +
      'The empty-idea flood (' + n + ' items)';
  }
  function floodSettled(a, bar, progress, btn, done, failed) {
    if (!failed.length) {
      // all N (or the cap batch) gone: the card becomes a short line
      // and the multicol stream reflows around it
      var card = bar.closest('article');
      var note = document.createElement('div');
      note.className = 'flood-cleared';
      note.textContent = 'flood cleared - ' + done +
        ' empty-idea rows sent to the wastebin.';
      if (card && card.parentNode)
        card.parentNode.replaceChild(note, card);
      return;
    }
    // survivors stay listed inline; the button retries only them
    pending = failed;
    progress.textContent = 'dismissed ' + done + ' of ' +
      (done + failed.length) + ' - failed ids: ' + failed.join(', ');
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Dismiss all ' + failed.length;
    }
    floodCardCount(bar.closest('article'), a.floodIds.length);
  }

  // Operator decisions: moss buttons, the outcome prints BEFORE the
  // click, a progress line runs during multi-action, the feed reloads
  // after success (scroll position preserved).
  function choicesEl(a) {
    var bar = document.createElement('div');
    bar.className = 'choices';
    var progress = null;
    a.choices.forEach(function (ch) {
      var act = ch && ch.action;
      if (!act || ALLOWED_ENDPOINTS.indexOf(act.endpoint) === -1) return;
      var row = document.createElement('div');
      row.className = 'choice-row';
      var b = document.createElement('button');
      b.className = 'choice';
      b.textContent = ch.label || act.endpoint;
      var out = document.createElement('span');
      out.className = 'outcome';
      out.textContent = ch.outcome || '';
      b.addEventListener('click', function () {
        b.disabled = true;
        if (!progress) {
          progress = document.createElement('div');
          progress.className = 'choice-progress';
          bar.appendChild(progress);
        }
        progress.textContent = 'sending ' + (ch.label || 'decision') + '…';
        postJson(act.endpoint, act.payload || { id: a.id })
          .then(function () { rebuildStream(); })
          .catch(function (e) {
            b.disabled = false;
            progress.textContent = 'failed: ' + e.message;
            showErr('decision failed: ' + e.message);
          });
      });
      row.appendChild(b);
      row.appendChild(out);
      bar.appendChild(row);
    });
    return bar;
  }

  // The wrap divider: giant title repeat + real edition details.
  function slotName(slot) {
    return slot === 0 ? 'morning edition'
      : slot === 1 ? 'midday edition' : 'evening edition';
  }
  function editionLine(ed) {
    var sys = (ed && ed.system) || {};
    var w = ed && ed.weather;
    var online = (sys.fleet || []).filter(function (f) {
      return f && f.online; }).length;
    var bits = [
      (ed && ed.date) || todayFromStamp(ed || {}) || 'undated',
      'no. ' + ((ed && ed.number) != null ? ed.number : '?'),
      slotName(ed && ed.slot),
      (ed && ed.generated ? ed.generated.slice(11, 16) + ' UTC' : ''),
      w && typeof w.temp_c === 'number'
        ? 'weather: ' + w.temp_c.toFixed(1) + '°C / ' + cToF(w.temp_c) +
          '°F ' + (w.summary || '')
        : w ? 'weather: ' + (w.summary || 'report incomplete')
        : 'no weather report',
      'queue ' + (sys.queue_depth != null ? sys.queue_depth : '?') +
        ' - sessions ' + (sys.sessions_active != null
          ? sys.sessions_active : '?') +
        ' - fleet ' + online + '/' + ((sys.fleet || []).length) + ' online'
    ].filter(Boolean);
    return bits.join(' · ');
  }
  function freshEditionDivider() {
    var div = document.createElement('section');
    div.className = 'fresh-edition';
    div.innerHTML = '<div class="orn">❦ ❦ ❦</div>' +
      '<h2>FRESH EDITION</h2>' +
      '<div class="dl">' + esc(editionLine(feed.data && feed.data.edition)) +
      '</div>';
    return div;
  }

  // Feed sequence: current edition articles, then stored editions
  // oldest-last, then the FRESH EDITION divider at the wrap; the
  // cursor repeats the sequence forever after that.
  function buildSeq() {
    var d = feed.data;
    var seq = [];
    var cur = (d.articles || []).slice().sort(function (x, y) {
      return (y.score || 0) - (x.score || 0);
    });
    var flood = cur.filter(isFlood);
    var rest = cur.filter(function (a) { return !isFlood(a); });
    if (flood.length) {
      // collapse the family into one card at the top flood score slot
      var top = flood[0].score || 0;
      var at = 0;
      while (at < rest.length && (rest[at].score || 0) >= top) at += 1;
      rest.splice(at, 0, floodArticle(flood));
    }
    rest.forEach(function (a) { seq.push({ k: 'a', a: a }); });
    (d.editions || []).slice().reverse().forEach(function (e) {
      (e.articles || []).slice().sort(function (x, y) {
        return (y.score || 0) - (x.score || 0);
      }).forEach(function (a) { seq.push({ k: 'a', a: a }); });
    });
    seq.push({ k: 'd' });
    return seq;
  }
  var CAP = 400; // DOM cap: recycle far-above articles past this
  function appendNext() {
    var stream = $('stream');
    if (!stream || !feed.seq.length) return 0;
    var it = feed.seq[feed.n % feed.seq.length];
    feed.n += 1;
    stream.appendChild(it.k === 'd' ? freshEditionDivider()
                                    : articleEl(it.a));
    trimAbove(stream);
    return 1;
  }
  function trimAbove(stream) {
    var arts = stream.querySelectorAll('.art, .fresh-edition, .trim-note');
    if (arts.length <= CAP) return;
    var excess = arts.length - CAP + 16;
    for (var i = 0; i < excess; i++) stream.removeChild(stream.firstChild);
    var note = document.createElement('div');
    note.className = 'trim-note';
    note.innerHTML = 'earlier columns trimmed to keep the page light - ' +
      '<a href="#top">return to the front page</a>';
    stream.insertBefore(note, stream.firstChild);
  }
  // Lazy render guard: append while the sentinel sits inside the
  // look-ahead window. The IntersectionObserver alone cannot drive
  // this - the sentinel can STAY intersecting across appends, and a
  // state that never transitions never re-fires the callback (observed
  // live 2026-09-27: the feed stalled at 6 articles). So every append
  // re-checks, bounded per call.
  function fillToSentinel() {
    var s = $('stream-sentinel');
    if (!s) return;
    var budget = 12;
    while (budget-- > 0) {
      if (s.getBoundingClientRect().top > innerHeight + 900) break;
      if (!appendNext()) break;
    }
  }

  // ---- Volumetric masthead splash: self-contained 5x7 bitmap font ----
  var GLYPHS = {
    'H': ['10001', '10001', '11111', '10001', '10001', '10001', '10001'],
    'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
    'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
    '.': ['00000', '00000', '00000', '00000', '00000', '00110', '00110']
  };
  var SPLASH_RAMP = ['█', '▓', '▒'];
  function h32(s) {
    var h = 2166136261;
    s = String(s || '');
    for (var i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }
  function splashText(text, seed) {
    var rows = ['', '', '', '', '', '', ''];
    var x = 0;
    for (var i = 0; i < text.length; i++) {
      var g = GLYPHS[text.charAt(i)];
      if (!g) { x += 2; continue; }
      for (var y = 0; y < 7; y++) {
        var line = '';
        for (var cx = 0; cx < 5; cx++) {
          if (g[y].charAt(cx) === '1') {
            var t = h32(seed + ':' + (x + cx) + ',' + y) % 100;
            line += t < 82 ? SPLASH_RAMP[0]
              : t < 94 ? SPLASH_RAMP[1] : SPLASH_RAMP[2];
          } else line += ' ';
        }
        rows[y] += line + ' ';
      }
      x += 6;
    }
    var w = Math.max(0, x - 1);
    var out = ['╔' + '═'.repeat(w) + '╗'];
    for (var r = 0; r < 7; r++) out.push('║' + rows[r].slice(0, w) + '║');
    out.push('╚' + '═'.repeat(w) + '╝');
    return out.join('\n');
  }
  // Rotating H.N.G.H. expansions; the pick is deterministic per edition
  // (hash of the feed stamp + edition number, never the wall clock).
  var HN_GH = [
    "Hierarchical News Gathering House",
    "Homunculus Newsprint & Gazette Hall",
    "Hackers' Newsprint Gathering Hub",
    "Honest News for Grumpy Humans",
    "Hyperlocal News, Gazette & Handbill",
    "Hungry Newsbots Gather Headlines",
    "Harmonic Newsprint & Graphite House",
    "House of Nocturnal Graphs & Heraldry",
    "Hand-Set News & General Herald",
    "Herald of the Nocturnal Grid & Hamlet",
    "Hydraulic Newsprint & Gasket House",
    "Hogshead & Needle Gazette House",
    "Hidden Fortress News Group Headquarters",
    "High-Frequency Newsprint & Graphite Hive",
    "Humble Newsprint for Gentle Homesteads",
    "Heavenstorm News & Gazette Herald",
    "Hexadecimal News for Grid Historians",
    "Hollow-Earth News Gathering House",
    "Herald of Nightly Git Habits",
    "Hearing No Good Headlines",
    "Honorable News, Gossip & Hearsay",
    "Haphazard Notes, Graphs & Hypotheses",
    "Humidity Notes & General Hearsay",
    "Heavyweight News & General Hubris",
    "Heuristic News, Grumbles & Hearsay",
    "Homemade Newsprint & Gutter Humor"
  ];
  function splashRender(ed, generated) {
    var stamp = generated || (ed && ed.generated) || '';
    var num = (ed && ed.number) != null ? ed.number : '';
    var pre = $('mast-splash');
    if (pre) pre.textContent = splashText('H.N.G.H.', stamp + '#' + num);
    var exp = $('mast-expansion');
    if (exp) exp.textContent = HN_GH[h32(stamp + '#' + num) % HN_GH.length];
    var sysline = $('mast-sysline');
    if (sysline) {
      var sys = (ed && ed.system) || {};
      // easter-egg honesty: only feed-carried system facts, never the clock
      sysline.textContent = [sys.hostname, sys.uptime]
        .filter(Boolean).join(' · ');
    }
  }
  function cToF(c) {
    return typeof c === 'number' && isFinite(c)
      ? (c * 9 / 5 + 32).toFixed(1) : '';
  }

  function mastheadRender(ed, generated) {
    var el = $('mast-line');
    if (el) el.textContent = editionLine(ed || { generated: generated });
    var badge = $('syn-badge');
    if (badge) badge.hidden = !feed.fixture;
    splashRender(ed || {}, generated);
  }
  function rebuildStream(keepScroll) {
    var stream = $('stream');
    if (!stream) return;
    var y = keepScroll ? scrollY : 0;
    stream.innerHTML = '';
    feed.seq = buildSeq();
    feed.n = 0;
    for (var i = 0; i < 6; i++) appendNext();
    fillToSentinel();
    scrollTo(0, Math.min(y, document.documentElement.scrollHeight));
  }
  // schema gate: fail closed on malformed feed
  function feedOk(d) {
    return !!(d && typeof d === 'object' &&
              Array.isArray(d.articles) && d.articles.length &&
              typeof d.generated === 'string');
  }
  function loadFeed() {
    var url = new URLSearchParams(location.search).get('feed')
      || 'newspaper.json';
    feed.fixture = url !== 'newspaper.json';
    return fetchJSON(url).then(function (d) {
      if (!feedOk(d)) throw new Error(
        url + ' is empty or malformed; refusing to print a blank page');
      feed.data = d;
      // dismissed stays dismissed: the snapshot can still list rows
      // this page already sent away (composer excludes them only on
      // its next run, up to 30 minutes later)
      d.articles = d.articles.filter(function (x) {
        return x && !feed.dismissed[x.id];
      });
      mastheadRender(d.edition, d.generated);
      if (!$('stream').childNodes.length) rebuildStream();
    });
  }
  function refresh() {
    return Promise.allSettled([
      loadFeed(),
      fetchJSON('fleet.json').then(function (f) {
        var nodes = f && Array.isArray(f.nodes) ? f.nodes : [];
        if (!mapState.scene) mapInit(nodes); // live map only binds once
      })
    ]).then(function (rs) {
      if (rs[0].status === 'rejected') showErr(rs[0].reason.message);
    });
  }

  // ---------- column config (localStorage, 1-5, default 3) ----------
  var COLS_KEY = 'broadsheet-cols';
  function colsGet() {
    var n = parseInt(localStorage.getItem(COLS_KEY) || '3', 10);
    return isNaN(n) ? 3 : Math.min(5, Math.max(1, n));
  }
  function colsSet(n) {
    n = Math.min(5, Math.max(1, n));
    localStorage.setItem(COLS_KEY, String(n));
    var st = $('stream');
    if (st) st.style.setProperty('--cols', String(n));
    var lab = $('col-label');
    if (lab) lab.textContent = 'columns: ' + n;
  }
  function colsShift(d) { colsSet(colsGet() + d); }

  // ---------- init + poll (setTimeout chain, no raw timer loops) ----------
  function init() {
    paperInit();
    colsSet(colsGet());
    $('col-minus').addEventListener('click', function () { colsShift(-1); });
    $('col-plus').addEventListener('click', function () { colsShift(1); });
    $('paper-refresh').addEventListener('click', function () { refresh(); });
    document.addEventListener('keydown', function (ev) {
      if (ev.key === '[') colsShift(-1);
      else if (ev.key === ']') colsShift(1);
    });
    // lazy feed: render ahead when the sentinel enters the viewport
    var sentinel = $('stream-sentinel');
    if (sentinel && 'IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        if (!entries.some(function (e) { return e.isIntersecting; })) return;
        fillToSentinel();
      }, { rootMargin: '900px' }).observe(sentinel);
    }
    // Sentinel dead-zones are real (exact-edge containment differs by
    // engine), so scroll also drives the fill loop - one bounding-rect
    // read per event, appends bounded inside fillToSentinel.
    addEventListener('scroll', function () { fillToSentinel(); }, { passive: true });
    fetchJSON('fleet.json').then(function (f) {
      mapInit(f && Array.isArray(f.nodes) ? f.nodes : []);
    }).catch(function (e) { mapFallback([], e.message); });
    refresh();
    var base = 30000, delay = base, t = null;
    function clear() { if (t) { clearTimeout(t); t = null; } }
    function tick() {
      if (document.hidden) return;
      Promise.resolve(refresh()).then(function () {
        delay = base; t = setTimeout(tick, delay);
      }, function () {
        delay = Math.min(delay * 2, 120000);
        t = setTimeout(tick, delay);
      });
    }
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) clear(); else tick();
    });
    tick();
  }
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', init);
  else init();
})();
