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
    // the served page carries two token metas (server-injected real one
    // first, then the empty file:// placeholder): take the first
    // NON-EMPTY content across all matches, else ''
    var metas = document.querySelectorAll('meta[name="hngh-token"]');
    for (var i = 0; i < metas.length; i++) {
      var v = metas[i].getAttribute('content') || '';
      if (v) return v;
    }
    return '';
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
          if (!r.ok) {
            var err = new Error(j.error || ('HTTP ' + r.status));
            err.body = j; // surfaced for fail-visible handlers (omp 503)
            throw err;
          }
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
  // Endpoint whitelist: choice actions may only POST these six literals;
  // anything else in the feed is refused (fail closed). park requires an
  // operator note, acknowledge takes an optional one.
  var ALLOWED_ENDPOINTS = ["/operator-item/handle", "/operator-item/dismiss",
    "/operator-item/park", "/operator-item/expire",
    "/operator-item/suppress", "/operator-item/acknowledge"];
  var NOTE_ENDPOINTS = {
    '/operator-item/park': 'required',
    '/operator-item/acknowledge': 'optional'
  };
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

  // decided cards persist the same way: handle/acknowledge leave the card
  // on the sheet but visibly marked (the APPROVED ledger drops it from the
  // feed on the next composer edition); dismissed-family verbs already
  // filter. Same reconciliation story as DISMISSED_KEY above.
  var HANDLED_KEY = 'broadsheet-handled';
  feed.handled = (function () {
    try { return JSON.parse(localStorage.getItem(HANDLED_KEY) || '{}'); }
    catch (e) { return {}; } // malformed storage: fail open to fresh
  })();
  function handledPersist(id) {
    feed.handled[id] = true;
    try { localStorage.setItem(HANDLED_KEY,
      JSON.stringify(feed.handled)); } catch (e) { /* private mode */ }
  }
  // which store a verb's success touches: APPROVED verbs mark the card in
  // place, DISMISSED verbs drop it on the next rebuild; other endpoints
  // (fire dispatches, omp session) touch neither store.
  function verbStore(endpoint) {
    if (/handle|acknowledge/.test(endpoint)) return handledPersist;
    if (/dismiss|expire|suppress|park/.test(endpoint)) return dismissPersist;
    return null;
  }

  function catColor(cat) { return 'var(--c-' + esc(cat) + ', var(--rule))'; }

  function articleEl(a) {
    var art = document.createElement('article');
    art.className = 'art' +
      (a.span === 3 ? ' span3' : a.span === 2 ? ' span2' : '');
    art.style.setProperty('--cat', catColor(a.category));
    // insert variety: newsprint scraps rise with a per-card stagger
    art.style.setProperty('--rise-d',
      ((h32(String(a.id || '')) % 5) * 70) + 'ms');
    if (feed.handled && feed.handled[a.id]) art.classList.add('ohandled');
    var kick = '<div class="kicker">' +
      esc(a.kicker || a.category || 'bulletin');
    if (feed.data && feed.data.queues &&
        typeof feed.data.queues[a.category] === 'number') {
      kick += '<span class="qchip">queue ' +
        feed.data.queues[a.category] + '</span>';
    }
    if (feed.handled && feed.handled[a.id])
      kick += '<span class="ohandled-chip">handled ✓ — leaves the next edition</span>';
    kick += '</div>';
    var h = document.createElement('h2');
    h.innerHTML = kick + esc(a.headline || 'untitled') +
      (a.occurrences > 1
        ? ' <span class="occ">×' + esc(a.occurrences) + '</span>'
        : '');
    h.title = 'click to expand or collapse';
    art.appendChild(h);
    // the composer serves deck = full text, so decks often repeat the
    // headline verbatim — strip that prefix, drop empty remainder
    // (display-layer only; the feed schema is untouched)
    if (a.deck) {
      var deckText = (a.headline && a.deck.indexOf(a.headline) === 0)
        ? a.deck.slice(a.headline.length).replace(/^[\s\u2014.-]+/, '')
        : a.deck;
      if (deckText) {
        var d = document.createElement('p');
        d.className = 'deck'; d.textContent = deckText;
        art.appendChild(d);
      }
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
      embedSync(art, a);
    });
    if (a.span === 3) art.classList.add('expanded');
    art.insertAdjacentHTML('beforeend', ghostHTML(a.ghost));
    var guide = guidanceHTML(a.guidance);
    var narr = narrativeHTML(a.narrative);
    art.insertAdjacentHTML('beforeend',
      narr && a.narrative.place === 'below' ? guide + narr : narr + guide);
    if (Array.isArray(a.sources) && a.sources.length) {
      var src = a.sources.map(function (s) { return s && s.label; })
        .filter(Boolean).join(' · ');
      if (src) {
        var sl = document.createElement('div');
        sl.className = 'srcline'; sl.textContent = 'source: ' + src;
        art.appendChild(sl);
      }
    }
    if (a.embed && a.embed.kind === 'btop' &&
        typeof a.embed.src === 'string') {
      var emb = document.createElement('pre');
      emb.className = 'btop-embed';
      emb.textContent = a.embed.alt || '…';
      art.appendChild(emb);
    }
    if (a.floodIds) art.appendChild(floodChoicesEl(a));
    else if ((Array.isArray(a.choices) && a.choices.length) || a.fire)
      art.appendChild(choicesEl(a));
    if (a.embed) embedSync(art, a); // span3 prints expanded: poll at once
    return art;
  }

  // Ghost counsel: the composer may attach a signed summary paragraph;
  // it prints as a distinct ghost-desk block inside expanded articles.
  function ghostHTML(g) {
    if (!g || !g.voice || !g.text) return '';
    return '<div class="ghostdesk"><p>' + esc(g.text) + '</p>' +
      '<div class="ghost-sig">— ' + esc(g.voice) + ', ghost desk</div></div>';
  }

  // Operator guidance: the composer may attach a cause-and-effect
  // card for a decision item (why this class of item sits on the
  // operator's desk, what each verb durably does, example notes,
  // doc paths). Honesty: every word comes from the feed payload; the
  // view adds structure only. Fail open: absent guidance renders
  // nothing. Note requirement mirrors NOTE_ENDPOINTS semantics
  // (park required, acknowledge optional, others no note).
  function guidanceHTML(g) {
    if (!g || !Array.isArray(g.verbs) || !g.verbs.length) return '';
    var rows = g.verbs.map(function (v) {
      var need = v && v.note === 'required' ? 'required' :
        v && v.note === 'optional' ? 'optional' : '-';
      var html = '<tr><td>' + esc((v && v.label) || (v && v.verb) || '?') +
        '</td><td class="og-need">' + need + '</td><td>' +
        esc((v && v.effect) || '') + '</td></tr>';
      ((v && v.examples) || []).forEach(function (e) {
        html += '<tr class="og-exrow"><td></td>' +
          '<td colspan="2">&quot;' + esc((e && e.note) || '') +
          '&quot; -> ' + esc((e && e.effect) || '') + '</td></tr>';
      });
      return html;
    }).join('');
    var docs = (Array.isArray(g.docs) ? g.docs : []).map(function (d) {
      var p = d && d.path;
      // jailed evidence link (routes-view refHtml parity): only a
      // repo-relative docs/ path earns an href through the served
      // /hngh-docs/docs/ route; anything else stays plain cited text.
      if (typeof p === 'string' && p.indexOf('docs/') === 0) {
        return '<li><a href="/hngh-docs/docs/' + encodeURIComponent(p) +
          '">' + esc((d && d.label) || p) + '</a></li>';
      }
      return '<li>' + esc(((d && d.label) ? d.label + ': ' : '') +
        (p || '')) + '</li>';
    }).join('');
    return '<div class="oguide">' +
      (g.why ? '<div class="og-why">' + esc(g.why) + '</div>' : '') +
      '<table class="og-table"><thead><tr><th>verb</th><th>note</th>' +
      '<th>durable effect</th></tr></thead><tbody>' + rows +
      '</tbody></table>' +
      (g.note_rules ? '<div class="og-rules">' + esc(g.note_rules) +
        '</div>' : '') +
      (docs ? '<ul class="og-docs">' + docs + '</ul>' : '') + '</div>';
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
    // perceptibility floor: a 40-step chain against a local server
    // finishes in ~0.5s, which reads as the old flash; hold each step
    // on screen long enough to see the count tick (review finding F1)
    var FLOOD_STEP_MS = 130;
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
            var t0 = Date.now();
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
              })
              .then(function () {
                var left = FLOOD_STEP_MS - (Date.now() - t0);
                return left > 0
                  ? new Promise(function (res) { setTimeout(res, left); })
                  : null;
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
      // let the final count be read before the tall card reflows
      progress.textContent = 'dismissed ' + done + ' of ' + done +
        ' - flood cleared.';
      // all N (or the cap batch) gone: the card becomes a short line
      // and the multicol stream reflows around it
      var card = bar.closest('article');
      var note = document.createElement('div');
      note.className = 'flood-cleared';
      note.textContent = 'flood cleared - ' + done +
        ' empty-idea rows sent to the wastebin.';
      if (card && card.parentNode)
        setTimeout(function () {
          if (note.parentNode || !card.parentNode) return;
          card.parentNode.replaceChild(note, card);
        }, 1500);
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
  // Settlement receipt: a decided card vanishes from the stream (the
  // dismissed filter drops it at once; the composer drops it from the
  // next edition), so the page must say where the decision and any
  // guidance note were recorded.
  function ledgerSide(endpoint) {
    return (endpoint === '/operator-item/acknowledge' ||
            endpoint === '/operator-item/handle')
      ? 'approved-side ledger' : 'dismissed-side ledger';
  }
  function receiptText(endpoint, id, note) {
    var verb = endpoint.split('/').pop();
    var state = { park: 'parked', expire: 'expired',
      suppress: 'suppressed', acknowledge: 'acknowledged',
      handle: 'handled', dismiss: 'dismissed' }[verb] || verb;
    var t = verb + ' settled — ' + id + ' · recorded in the ' +
      'report-queue ledger (operator-item:' + id + ':' + state +
      ') and the ' + ledgerSide(endpoint);
    if (note) t += ' · your note: "' + note + '"';
    return t + ' · the card leaves the next edition.';
  }
  var receiptTimer = null;
  function settleReceipt(endpoint, payload, override) {
    var el = document.getElementById('settle-receipt');
    if (!el) {
      el = document.createElement('div');
      el.id = 'settle-receipt';
      document.body.appendChild(el);
    }
    el.innerHTML = esc(override ||
      receiptText(endpoint, (payload && payload.id) || '?',
        payload && payload.note));
    el.className = 'on';
    clearTimeout(receiptTimer);
    receiptTimer = setTimeout(function () {
      el.className = ''; }, 15000);
  }
  function choicesEl(a) {
    var bar = document.createElement('div');
    bar.className = 'choices';
    var progress = null;
    var list = Array.isArray(a.choices) ? a.choices : [];
    list.forEach(function (ch) {
      var act = ch && ch.action;
      if (!act || ALLOWED_ENDPOINTS.indexOf(act.endpoint) === -1) return;
      var row = document.createElement('div');
      row.className = 'choice-row';
      var b = document.createElement('button');
      b.className = 'choice';
      b.textContent = ch.label || act.endpoint;
      if (ch.outcome) {
        b.title = ch.outcome;
        b.setAttribute('aria-label',
          (ch.label || act.endpoint) + ' — ' + ch.outcome);
      }
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
        var need = NOTE_ENDPOINTS[act.endpoint];
        var payload = act.payload || { id: a.id };
        if (need) {
          var note = (window.prompt(need === 'required'
            ? 'Guidance note (required to park):'
            : 'Note (optional):', '') || '').trim().slice(0, 200);
          if (need === 'required' && !note) {
            b.disabled = false;
            progress.textContent = 'park needs a guidance note - nothing sent.';
            return;
          }
          if (note) payload = Object.assign({}, payload, { note: note });
        }
        progress.textContent = 'sending ' + (ch.label || 'decision') + '…';
        postJson(act.endpoint, payload)
          .then(function () {
            var persist = verbStore(act.endpoint);
            if (persist) persist(a.id);
            if (persist === dismissPersist && feed.data &&
                feed.data.articles) {
              // dismissed = gone, client-side, now: the refetch filter
              // only runs on the next poll, but the receipt promises the
              // card leaves THIS rebuild
              feed.data.articles = feed.data.articles.filter(function (x) {
                return x.id !== a.id;
              });
            }
            megaTilt();
            ripBurst(bar.closest('article'));
            settleReceipt(act.endpoint, payload);
            if (act.endpoint === '/operator-item/park' &&
                parkFly(bar.closest('article'), payload)) {
              setTimeout(function () { rebuildStream(true); }, 520);
            } else rebuildStream();
          })
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
    // one-click Fire: composer-pinned verb, the note rides in the
    // payload, receipt names verb + effect via the settle chip
    var fire = a.fire;
    if (fire && typeof fire.endpoint === 'string' &&
        fire.endpoint.charAt(0) === '/') {
      var frow = document.createElement('div');
      frow.className = 'choice-row';
      var fb = document.createElement('button');
      fb.className = 'choice fire';
      fb.textContent = 'fire: ' + (fire.verb || fire.endpoint);
      fb.title = 'fire: dispatches this article verb now';
      fb.setAttribute('aria-label', fb.title);
      var fout = document.createElement('span');
      fout.className = 'outcome';
      fout.textContent = fire.effect || '';
      fb.addEventListener('click', function () {
        fb.disabled = true;
        if (!progress) {
          progress = document.createElement('div');
          progress.className = 'choice-progress';
          bar.appendChild(progress);
        }
        var payload = { id: a.id, note: fire.note };
        progress.textContent = 'firing ' + (fire.verb || '') + '…';
        postJson(fire.endpoint, payload)
          .then(function () {
            var persist = verbStore(fire.endpoint);
            if (persist) persist(a.id);
            if (persist === dismissPersist && feed.data &&
                feed.data.articles) {
              // dismissed = gone, client-side, now: the refetch filter
              // only runs on the next poll, but the receipt promises the
              // card leaves THIS rebuild
              feed.data.articles = feed.data.articles.filter(function (x) {
                return x.id !== a.id;
              });
            }
            megaTilt();
            ripBurst(bar.closest('article'));
            var receipt = 'fired ' + (fire.verb || '?') + ' — ' + (fire.effect || '');
            settleReceipt(fire.endpoint, payload, receipt);
            rebuildStream();
          })
          .catch(function (e) {
            fb.disabled = false;
            progress.textContent = 'failed: ' + e.message;
            showErr('fire failed: ' + e.message);
          });
      });
      frow.appendChild(fb);
      frow.appendChild(fout);
      bar.appendChild(frow);
    }
    bar.appendChild(ompBtnEl(a));
    return bar;
  }

  // ---- composer contract widgets (2026-09-29) ----
  // narrative: a one-line editorial aside pinned above/below the
  // guidance block inside the expanded card. Fail open: absent or
  // line-less payloads render nothing.
  function narrativeHTML(n) {
    if (!n || !n.line) return '';
    return '<p class="art-narrative ' +
      (n.place === 'below' ? 'narr-below' : 'narr-above') + '">' +
      esc(n.line) + '</p>';
  }

  // btop embed: a plain-text block fetched from the composer while the
  // card is expanded. The poll is card-scoped: the chained 2s re-arm
  // stops on collapse (the bare clearInterval clears the pending
  // chained timeout too - one timer pool) and dies with the node when
  // a rebuild or trim removes the card from the document.
  function embedSync(art, a) {
    var pre = art.querySelector('.btop-embed');
    if (!pre) return;
    if (!art.classList.contains('expanded')) {
      clearInterval(pre._embT);
      return;
    }
    var loop = function () {
      if (!pre.isConnected) return;
      fetchText(a.embed.src, 4000).then(function (t) {
        pre.textContent = t;
      }).catch(function (e) {
        pre.textContent = (a.embed.alt || 'btop') +
          ' — embed unavailable: ' + e.message;
      });
      pre._embT = setTimeout(loop, 2000);
    };
    // during the initial build the card is still detached (appendNext
    // attaches right after), so the first tick waits one arm instead
    // of dying on the isConnected guard
    if (pre.isConnected) loop();
    else pre._embT = setTimeout(loop, 2000);
  }

  // parked shelf: the fixed right-edge rail fed by composer rows
  // (art.parked = [{id, ts, why}]); ts + why truncate to fit.
  function shelfStrip(p) {
    var ts = String((p && p.ts) || '').slice(0, 16);
    var why = String((p && p.why) || '').slice(0, 48);
    return '<div class="parked-strip"><span class="ps-ts">' + esc(ts) +
      '</span> ' + esc(why) + '</div>';
  }
  function shelfRender() {
    var shelf = document.getElementById('parked-shelf');
    if (!shelf) return;
    var rows = [];
    ((feed.data && feed.data.articles) || []).forEach(function (a) {
      if (Array.isArray(a && a.parked))
        rows = rows.concat(a.parked.filter(Boolean).map(shelfStrip));
    });
    shelf.innerHTML = rows.join('');
    shelf.hidden = !rows.length;
  }

  // fly-over: on a successful park a strip clone travels to the shelf
  // before the rebuild drops the card. Skipped under reduced motion or
  // with no shelf in view - the rebuild lands immediately instead.
  function parkFly(card, payload) {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return false;
    var shelf = document.getElementById('parked-shelf');
    if (!shelf || shelf.hidden || !card) return false;
    var from = card.getBoundingClientRect();
    var to = shelf.getBoundingClientRect();
    var fly = document.createElement('div');
    fly.className = 'parked-strip park-fly';
    fly.textContent = 'parked · ' + String((payload && payload.note) || '');
    fly.style.left = Math.round(from.left) + 'px';
    fly.style.top = Math.round(from.top + from.height / 2) + 'px';
    document.body.appendChild(fly);
    var dx = Math.round(to.left - from.left);
    var dy = Math.round(to.top + 14 - (from.top + from.height / 2));
    requestAnimationFrame(function () {
      fly.style.transform =
        'translate(' + dx + 'px,' + dy + 'px) rotate(9deg)';
      fly.style.opacity = '0.2';
    });
    setTimeout(function () { fly.remove(); }, 540);
    return true;
  }

  // paper-rip burst: shards tear off the settled card and fade; each
  // removes itself when its animation ends.
  function ripBurst(card) {
    if (!card || matchMedia('(prefers-reduced-motion: reduce)').matches)
      return;
    var r = card.getBoundingClientRect();
    for (var i = 0; i < 3; i++) {
      var s = document.createElement('div');
      s.className = 'rip rip' + i;
      s.style.left = (r.left + r.width * (0.18 + 0.28 * i)) + 'px';
      s.style.top = (r.top + 8) + 'px';
      s.addEventListener('animationend', function () { this.remove(); });
      document.body.appendChild(s);
    }
  }

  // brief tilt of the folded-paper press hall when a settle lands
  // (the reduced-motion media query freezes the transition)
  function megaTilt() {
    var m = document.getElementById('megastructure');
    if (!m) return;
    m.classList.remove('tilt');
    void m.offsetWidth; // restart the tilt transition on repeat settles
    m.classList.add('tilt');
    setTimeout(function () { m.classList.remove('tilt'); }, 650);
  }

  // omp session launcher on cards that carry choices: the receipt
  // echoes the response package path + command; a 503 prints the
  // returned command string so the operator can run it (fail visible).
  function ompBtnEl(a) {
    var b = document.createElement('button');
    b.className = 'choice omp-btn';
    b.textContent = 'omp session';
    b.title = 'opens an omp session in a terminal bound to this article';
    b.setAttribute('aria-label', b.title);
    b.addEventListener('click', function () {
      b.disabled = true;
      postJson('/article/omp-session', { id: a.id })
        .then(function (j) {
          b.disabled = false;
          settleReceipt('/article/omp-session', { id: a.id },
            'omp session: ' + [j.path || j.package, j.command]
              .filter(Boolean).join(' · '));
        })
        .catch(function (e) {
          b.disabled = false;
          settleReceipt('/article/omp-session', { id: a.id },
            e.body && e.body.command
              ? 'launcher unavailable — run: ' + e.body.command
              : 'omp session failed: ' + e.message);
        });
    });
    return b;
  }

  // The wrap divider: giant title repeat + real edition details.
  function slotName(slot) {
    return slot === 0 ? 'morning edition'
      : slot === 1 ? 'midday edition' : 'evening edition';
  }
  // how old is the printed edition: the composer runs on the subhour
  // tier, so an old stamp means the operator is reading a stale paper
  // off a still-open tab; 90 minutes = three missed subhour runs.
  function editionAge(gen, now) {
    var t = Date.parse(gen);
    if (!isFinite(t)) return null;
    var m = Math.max(0, Math.round((now - t) / 60000));
    var text = m >= 60
      ? Math.floor(m / 60) + 'h ' + (m % 60) + 'm old'
      : m + 'm old';
    return { text: text, stale: m >= 90 };
  }
  function editionLine(ed) {
    var sys = (ed && ed.system) || {};
    var age = editionAge(feed.data && feed.data.generated, Date.now());
    var w = ed && ed.weather;
    var online = (sys.fleet || []).filter(function (f) {
      return f && f.online; }).length;
    var bits = [
      (ed && ed.date) || todayFromStamp(ed || {}) || 'undated',
      'no. ' + ((ed && ed.number) != null ? ed.number : '?'),
      slotName(ed && ed.slot),
      age ? (age.stale ? 'stale edition · ' + age.text
                       : 'edition ' + age.text) : '',
      (ed && ed.generated ? ed.generated.slice(11, 16) + ' UTC' : ''),
      w && typeof w.temp_c === 'number'
        ? 'weather: ' + w.temp_c.toFixed(1) + '°C / ' + cToF(w.temp_c) +
          '°F ' + (w.summary || '')
        : w ? 'weather: ' + (w.summary || 'report incomplete')
        : 'no weather report',
      'queue ' + (sys.queue_depth != null ? sys.queue_depth : '?') +
        ' - sessions ' + (sys.sessions_active != null
          ? sys.sessions_active : '?') +
        ' - fleet ' + online + '/' + ((sys.fleet || []).length) + ' online',
      feed.openCount != null ? feed.openCount + ' open' : ''
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
    var gq = $('mast-ghost');
    if (gq) gq.textContent =
      ed && typeof ed.ghost_quiet === 'string' && ed.ghost_quiet
        ? 'ghost desk quiet — ' + ed.ghost_quiet : '';
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
    feed.renderedGenerated = (feed.data || {}).generated;
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
  function loadFeed(rebuild) {
    var url = new URLSearchParams(location.search).get('feed')
      || 'newspaper.json';
    feed.fixture = url !== 'newspaper.json';
    // fetchJSON already sends cache:'no-store'; the param defeats any
    // intermediate proxy so the refresh button always re-fetches for real
    var url2 = url + (url.indexOf('?') === -1 ? '?' : '&') +
      't=' + Date.now();
    return fetchJSON(url2).then(function (d) {
      if (!feedOk(d)) throw new Error(
        url + ' is empty or malformed; refusing to print a blank page');
      feed.data = d;
      // dismissed stays dismissed: the snapshot can still list rows
      // this page already sent away (composer excludes them only on
      // its next run, up to 30 minutes later)
      d.articles = d.articles.filter(function (x) {
        return x && !feed.dismissed[x.id];
      });
      // edition-aware silent poll: a changed stamp means the composer
      // printed a new edition — rebuild once so the paper is actually
      // fresh; unchanged snapshots still never rebuild (the original
      // flash bug). renderedGenerated is stamped inside rebuildStream.
      var freshEdition = $('stream').childNodes.length > 0 &&
        feed.renderedGenerated && d.generated !== feed.renderedGenerated;
      shelfRender();
      mastheadRender(d.edition, d.generated);
      // initial load always builds; an explicit refresh rebuilds the
      // whole sheet so a new snapshot is actually visible. The silent
      // 30s poll deliberately does neither (rebuilding from a stale
      // snapshot was the original flash bug).
      if (rebuild || freshEdition || !$('stream').childNodes.length)
        rebuildStream(true);
    });
  }
  function refresh(rebuild) {
    return Promise.allSettled([
      loadFeed(rebuild),
      fetchJSON('fleet.json').then(function (f) {
        var nodes = f && Array.isArray(f.nodes) ? f.nodes : [];
        if (!mapState.scene) mapInit(nodes); // live map only binds once
      }),
      // open items for the dateline: ledger ids are already dropped by
      // the feed rebuild, so the array length IS the open count; null
      // on failure keeps the segment off the line entirely
      fetchJSON('operator-items.json').then(function (o) {
        feed.openCount = o && Array.isArray(o.items) ? o.items.length
                                                     : null;
      }).catch(function () { feed.openCount = null; })
    ]).then(function (rs) {
      // fail-stale: a rejected refetch leaves the current edition on
      // screen (no rebuild, feed.data untouched) and says so
      if (rs[0].status === 'rejected') showErr(rs[0].reason.message);
      if (feed.openCount != null)
        mastheadRender(feed.data && feed.data.edition,
                       feed.data && feed.data.generated);
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
    $('paper-refresh').addEventListener('click', function () {
      var btn = this;
      if (btn.disabled) return;
      btn.disabled = true;
      var old = btn.textContent;
      btn.textContent = 'refreshing…';
      Promise.resolve(refresh(true)).catch(function () {})
        .then(function () { btn.disabled = false; btn.textContent = old; });
    });
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
